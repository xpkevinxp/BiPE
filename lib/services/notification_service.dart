import 'dart:async';

import 'package:bipealerta/models/BipeModel.dart';
import 'package:bipealerta/services/auth_service.dart';
import 'package:bipealerta/services/retryQueue_service.dart';
import 'package:http/http.dart' as http;
import 'package:notification_listener_service/notification_event.dart';
import 'dart:convert';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef NotificationCallback = void Function(String message);
typedef ErrorCallback = void Function(String error);
typedef ConnectionStatusCallback = void Function(bool isConnected);

class NotificationService {
  static const String baseUrl = 'https://apialert.c-centralizador.com/api';
  static const Duration requestTimeout = Duration(seconds: 30);
  
  // Configuración del Watchdog para Xiaomi - OPTIMIZADO
  static const Duration _watchdogInterval = Duration(minutes: 5); // Más frecuente
  static const Duration _reconnectCooldown = Duration(seconds: 30); // Cooldown más corto
  static const Duration _aggressiveReconnectInterval = Duration(seconds: 15); // Para reconexión agresiva
  
  final AuthService _authService = AuthService();
  NotificationCallback? onNotificationReceived;
  ErrorCallback? onError;
  ConnectionStatusCallback? onConnectionStatusChanged;
  RetryQueueManager? _retryQueueManager;

  StreamSubscription? _notificationSubscription;
  Timer? _watchdogTimer;
  Timer? _aggressiveReconnectTimer; // Timer para reconexión agresiva
  DateTime? _lastNotificationTime;
  DateTime? _lastReconnectAttempt;
  DateTime? _lastConnectedTime;
  DateTime? _lastDisconnectedTime;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10; // Más intentos antes de rendirse

  // Getter para el estado de conexión
  bool get isConnected => _isConnected;
  DateTime? get lastNotificationTime => _lastNotificationTime;

  Future<void> initialize() async {
    try {
      print("NotificationService - Iniciando servicio...");
      // Inicializar RetryQueueManager
      _retryQueueManager = await RetryQueueManager.initialize(
        onRetry: (data) => _sendToApiWithRetry(data),
        retryInterval: const Duration(minutes: 1),
        maxRetries: 5,
      );

      final isGranted = await NotificationListenerService.isPermissionGranted();
      print("NotificationService - Permiso concedido: $isGranted");

      if (!isGranted) {
        print("NotificationService - Permisos no concedidos. Deben solicitarse desde la UI principal.");
        // NO solicitar permisos aquí para evitar NullPointerException cuando se ejecuta desde background
        // Los permisos deben solicitarse desde la Activity principal
      }

      print("NotificationService - Configurando stream de notificaciones");
      _notificationSubscription =
          NotificationListenerService.notificationsStream.listen(
        (event) {
          // Manejar eventos de conexión/desconexión (nuevo para Xiaomi)
          if (event.isConnectionEvent) {
            _handleConnectionEvent(event);
            return;
          }
          
          print(
              "NotificationService - Evento recibido: ${event.packageName} - ${event.content}");
          
          // Actualizar timestamp de última notificación
          _lastNotificationTime = DateTime.now();
          _isConnected = true;
          _reconnectAttempts = 0; // Reset intentos al recibir notificación
          
          _handleNotification(event);
        },
        onError: (error) {
          print('NotificationService - Error en stream: $error');
          onError?.call('Error al procesar notificaciones');
        },
      );
      
      // Iniciar el Watchdog para Xiaomi
      _startWatchdog();
      
      // Verificar estado inicial de conexión
      await _checkInitialConnectionStatus();
      
      print("NotificationService - Inicialización completada");
    } catch (e) {
      print('NotificationService - Error en initialize: $e');
      onError?.call('Error al inicializar notificaciones');
    }
  }

  /// Maneja eventos de conexión/desconexión del NotificationListenerService
  void _handleConnectionEvent(ServiceNotificationEvent event) {
    final wasConnected = _isConnected;
    _isConnected = event.isConnected ?? false;
    
    if (_isConnected) {
      print('🟢 NotificationService - Listener CONECTADO');
      _reconnectAttempts = 0;
      _lastConnectedTime = DateTime.now();
      _stopAggressiveReconnect(); // Detener reconexión agresiva si está activa
    } else {
      print('🔴 NotificationService - Listener DESCONECTADO');
      _lastDisconnectedTime = DateTime.now();
      _startAggressiveReconnect(); // Iniciar reconexión agresiva automáticamente
    }
    
    // Notificar cambio de estado si cambió
    if (wasConnected != _isConnected) {
      onConnectionStatusChanged?.call(_isConnected);
    }
  }

  /// Inicia el modo de reconexión agresiva (intenta cada 15 segundos)
  void _startAggressiveReconnect() {
    _stopAggressiveReconnect(); // Asegurar que no haya timer previo
    
    print('⚡ Iniciando reconexión agresiva (cada ${_aggressiveReconnectInterval.inSeconds}s)...');
    
    // Intentar inmediatamente
    _attemptReconnection('Desconexión detectada - Reconexión inmediata');
    
    // Luego configurar timer para intentos periódicos
    _aggressiveReconnectTimer = Timer.periodic(_aggressiveReconnectInterval, (_) async {
      if (_isConnected) {
        _stopAggressiveReconnect();
        return;
      }
      
      if (_reconnectAttempts >= _maxReconnectAttempts) {
        print('⚡ Reconexión agresiva: Máximo de intentos alcanzado');
        _stopAggressiveReconnect();
        onError?.call('Servicio desconectado. Toca "Reiniciar servicio" para reconectar.');
        return;
      }
      
      await _attemptReconnection('Reconexión agresiva automática');
    });
  }

  /// Detiene el modo de reconexión agresiva
  void _stopAggressiveReconnect() {
    _aggressiveReconnectTimer?.cancel();
    _aggressiveReconnectTimer = null;
  }

  /// Verifica el estado inicial de conexión
  Future<void> _checkInitialConnectionStatus() async {
    try {
      _isConnected = await NotificationListenerService.isServiceConnected();
      print('NotificationService - Estado inicial de conexión: $_isConnected');
      onConnectionStatusChanged?.call(_isConnected);
    } catch (e) {
      print('NotificationService - Error verificando estado inicial: $e');
    }
  }

  /// Inicia el Watchdog que monitorea la salud del servicio
  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(_watchdogInterval, (_) async {
      await _watchdogCheck();
    });
    print('🐕 NotificationService - Watchdog iniciado (intervalo: ${_watchdogInterval.inMinutes} min)');
  }

  /// Ejecuta la verificación del Watchdog
  Future<void> _watchdogCheck() async {
    print('🐕 Watchdog - Ejecutando verificación de salud...');
    
    try {
      // 1. Verificar si tenemos permiso
      final hasPermission = await NotificationListenerService.isPermissionGranted();
      if (!hasPermission) {
        print('🐕 Watchdog - Sin permiso de notificaciones');
        return;
      }
      
      // 2. Verificar estado de conexión del servicio
      final isServiceConnected = await NotificationListenerService.isServiceConnected();
      
      // 3. Verificar si hemos recibido notificaciones recientemente
      final now = DateTime.now();
      final hasRecentActivity = _lastNotificationTime != null && 
          now.difference(_lastNotificationTime!).inMinutes < 30;
      
      print('🐕 Watchdog - Servicio conectado: $isServiceConnected, Actividad reciente: $hasRecentActivity');
      
      // 4. Si el servicio no está conectado, intentar reconectar
      if (!isServiceConnected) {
        await _attemptReconnection('Servicio desconectado detectado por Watchdog');
      }
      // 5. Si no hay actividad reciente y estamos en horario laboral, verificar
      else if (!hasRecentActivity && _isWorkingHours()) {
        print('🐕 Watchdog - Sin actividad reciente en horario laboral, verificando conexión...');
        final status = await NotificationListenerService.getConnectionStatus();
        print('🐕 Watchdog - Estado detallado: $status');
        
        // Si la última desconexión fue reciente, intentar reconectar
        if (status.lastDisconnectedTime != null &&
            now.difference(status.lastDisconnectedTime!).inMinutes < 30) {
          await _attemptReconnection('Desconexión reciente detectada');
        }
      }
      
      _isConnected = isServiceConnected;
      
    } catch (e) {
      print('🐕 Watchdog - Error en verificación: $e');
    }
  }

  /// Intenta reconectar el servicio
  Future<void> _attemptReconnection(String reason, {bool skipCooldown = false}) async {
    // Verificar cooldown para evitar reconexiones excesivas (solo si no es agresiva)
    if (!skipCooldown && _lastReconnectAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastReconnectAttempt!);
      if (timeSinceLastAttempt < _reconnectCooldown) {
        final secondsRemaining = _reconnectCooldown.inSeconds - timeSinceLastAttempt.inSeconds;
        print('🔄 Reconexión - En cooldown, esperando $secondsRemaining segundos más');
        return;
      }
    }
    
    // Verificar límite de intentos
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('🔄 Reconexión - Máximo de intentos alcanzado ($_maxReconnectAttempts)');
      onError?.call('Servicio desconectado. Toca "Reiniciar servicio" para reconectar.');
      return;
    }
    
    _reconnectAttempts++;
    _lastReconnectAttempt = DateTime.now();
    
    print('🔄 Reconexión - Intento $_reconnectAttempts/$_maxReconnectAttempts - Razón: $reason');
    
    // Notificar que estamos intentando reconectar
    onConnectionStatusChanged?.call(false);
    
    try {
      // Alternar entre métodos según el intento
      if (_reconnectAttempts % 3 == 1) {
        // Intento 1, 4, 7: requestRebind (método suave)
        print('🔄 Método: requestRebind (suave)');
        await NotificationListenerService.forceRequestRebind();
      } else if (_reconnectAttempts % 3 == 2) {
        // Intento 2, 5, 8: reconnectService (toggle componente)
        print('🔄 Método: reconnectService (toggle)');
        await NotificationListenerService.reconnectService();
      } else {
        // Intento 3, 6, 9: Combinación de ambos
        print('🔄 Método: Combinado (toggle + rebind)');
        await NotificationListenerService.reconnectService();
        await Future.delayed(const Duration(milliseconds: 500));
        await NotificationListenerService.forceRequestRebind();
      }
      
      // Esperar un poco y verificar
      await Future.delayed(const Duration(seconds: 2));
      
      final isNowConnected = await NotificationListenerService.isServiceConnected();
      if (isNowConnected) {
        print('✅ Reconexión exitosa después de $_reconnectAttempts intentos');
        _isConnected = true;
        _reconnectAttempts = 0;
        _lastConnectedTime = DateTime.now();
        _stopAggressiveReconnect();
        onConnectionStatusChanged?.call(true);
      } else {
        print('⚠️ Intento $_reconnectAttempts completado pero servicio aún desconectado');
      }
      
    } catch (e) {
      print('❌ Error en reconexión: $e');
    }
  }

  /// Verifica si estamos en horario laboral (8am - 10pm)
  bool _isWorkingHours() {
    final hour = DateTime.now().hour;
    return hour >= 8 && hour <= 22;
  }

  /// Método público para forzar reconexión manual
  Future<bool> forceReconnect() async {
    print('🔄 Reconexión manual solicitada por usuario');
    
    // Reset completo de contadores para reconexión manual
    _reconnectAttempts = 0;
    _lastReconnectAttempt = null;
    _stopAggressiveReconnect(); // Detener cualquier reconexión automática
    
    try {
      // Intentar múltiples métodos en secuencia
      print('🔄 Paso 1: Toggle del componente...');
      await NotificationListenerService.reconnectService();
      await Future.delayed(const Duration(seconds: 1));
      
      print('🔄 Paso 2: Request rebind...');
      await NotificationListenerService.forceRequestRebind();
      await Future.delayed(const Duration(seconds: 2));
      
      _isConnected = await NotificationListenerService.isServiceConnected();
      
      if (_isConnected) {
        print('✅ Reconexión manual exitosa');
        _lastConnectedTime = DateTime.now();
      } else {
        print('⚠️ Reconexión manual completada pero servicio no conectado');
        // Iniciar reconexión agresiva como fallback
        _startAggressiveReconnect();
      }
      
      onConnectionStatusChanged?.call(_isConnected);
      return _isConnected;
    } catch (e) {
      print('❌ Error en reconexión manual: $e');
      // Iniciar reconexión agresiva como fallback
      _startAggressiveReconnect();
      return false;
    }
  }

  /// Obtiene el estado detallado de conexión
  Future<Map<String, dynamic>> getDetailedStatus() async {
    try {
      final status = await NotificationListenerService.getConnectionStatus();
      return {
        'isConnected': _isConnected,
        'lastNotificationTime': _lastNotificationTime?.toIso8601String(),
        'lastConnectedTime': _lastConnectedTime?.toIso8601String() ?? status.lastConnectedTime?.toIso8601String(),
        'lastDisconnectedTime': _lastDisconnectedTime?.toIso8601String() ?? status.lastDisconnectedTime?.toIso8601String(),
        'reconnectAttempts': _reconnectAttempts,
        'maxReconnectAttempts': _maxReconnectAttempts,
        'watchdogActive': _watchdogTimer?.isActive ?? false,
        'aggressiveReconnectActive': _aggressiveReconnectTimer?.isActive ?? false,
        'watchdogInterval': '${_watchdogInterval.inMinutes} min',
        'aggressiveInterval': '${_aggressiveReconnectInterval.inSeconds} seg',
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<void> debugBipesStatus() async {
    try {
      final bipes = await _authService.getBipes();
      print('NotificationService - Número de bipes cargados: ${bipes.length}');
      for (var bipe in bipes) {
        print('Bipe: ${bipe.contain}, packageName: ${bipe.packageName}');
      }
    } catch (e) {
      print('Error al depurar bipes: $e');
    }
  }

  Future<void> _handleNotification(ServiceNotificationEvent event) async {
    try {
      final content = event.content;
      final idnotifacion = event.id;
      final packageName = event.packageName;

      // Verificamos si es un evento de eliminación
      if (event.hasRemoved == true) {
        print(
            '${DateTime.now().toIso8601String()} - Notificación eliminada: $content');
        return;
      }

      if (content == null || idnotifacion == null || packageName == null) {
        print(
            '${DateTime.now().toIso8601String()} - Notificación inválida: contenido o ID nulo');
        return;
      }
      // AÑADIR ESTA PROTECCIÓN - Limitar longitud del contenido
      if (content.length > 500) {
        // Limitar a 1000 caracteres
        print('${DateTime.now().toIso8601String()} - Truncando notificación demasiado grande: ${content.length} caracteres');
        return;
      }

      print('${DateTime.now().toIso8601String()} - Notificación recibida: $content de app: $packageName');

      // Obtener bipes y verificar que no esté vacío
      final bipes = await _authService.getBipes();

      if (bipes.isEmpty) {
        print(
            'ALERTA: Lista de bipes vacía al procesar notificación. Intentando actualizar...');
        try {
          // Intentar actualizar bipes si la lista está vacía
          await _authService.migrateAndUpdateBipes();
          // Obtener la lista actualizada
          final updatedBipes = await _authService.getBipes();

          if (updatedBipes.isEmpty) {
            print(
                'ERROR CRÍTICO: No se pudieron cargar bipes después de actualización');
            onError?.call('Error al cargar configuración de notificaciones');
            return;
          }

          // Continuar con la lista actualizada
          print(
              'Bipes actualizados correctamente. Continuando procesamiento...');

          // Procesar con los bipes actualizados
          for (var bipe in updatedBipes) {
            if (packageName == bipe.packageName || bipe.packageName == "-1") {
              print('Coincidencia de package: ${bipe.packageName}');
              if (content.contains(bipe.contain)) {
                print('Coincidencia de contenido: ${bipe.contain}');
                onNotificationReceived?.call(content);
                await processMessage(content, idnotifacion, bipe, packageName);
                return; // Salimos al encontrar coincidencia
              }
            }
          }

          print(
              'No se encontró coincidencia con bipes actualizados para: $packageName');
          return;
        } catch (e) {
          print(
              'Error actualizando bipes durante procesamiento de notificación: $e');
          onError?.call('Error en configuración de notificaciones');
          return;
        }
      }

      // Procesamiento normal con la lista de bipes
      print('Procesando notificación con ${bipes.length} bipes configurados');

      bool coincidenciaEncontrada = false;
      for (var bipe in bipes) {
        if (packageName == bipe.packageName || bipe.packageName == "-1") {
          print('Coincidencia de package: ${bipe.packageName}');
          if (content.contains(bipe.contain)) {
            print('Coincidencia de contenido: ${bipe.contain}');
            coincidenciaEncontrada = true;
            onNotificationReceived?.call(content);
            await processMessage(content, idnotifacion, bipe, packageName);
            break;
          }
        }
      }

      if (!coincidenciaEncontrada) {
        print('No se encontró coincidencia para notificación de: $packageName');
      }
    } catch (e) {
      print('Error procesando notificación: $e');
      onError?.call('Error al procesar notificación');
    }
  }

  Future<Map<String, dynamic>?> _getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idUsuario = prefs.getInt('idUsuario');
      final idNegocio = prefs.getInt('idNegocio');

      if (idUsuario == null || idNegocio == null) {
        print('Datos de usuario no encontrados');
        return null;
      }

      return {
        'idUsuario': idUsuario,
        'idNegocio': idNegocio,
      };
    } catch (e) {
      print('Error obteniendo datos de usuario: $e');
      return null;
    }
  }

  Future<void> processMessage(
      String message, int idnotifacion, Bipe bipe, String packageName) async {
    try {
      final userData = await _getUserData();
      if (userData == null) {
        return;
      }

      print('message');

      final RegExp regex = RegExp(bipe.regex);
      final match = regex.firstMatch(message);

      if (match == null) {
        print('Formato de mensaje inválido para ${bipe.contain}');
        return;
      }

      // Para Yape que tiene dos grupos (nombre y monto)
      final String nombreCliente =
          match.groupCount > 1 ? match.group(1)! : bipe.contain;

      // Manejo dinámico del monto
      double monto = 0.0;
      if (bipe.hasMonto) {
        final String montoStr =
            match.groupCount > 1 ? match.group(2)! : match.group(1)!;
        monto = double.parse(montoStr);
      }

      final data = {
        'IdUsuarioNegocio': userData['idUsuario'],
        'IdNegocio': userData['idNegocio'],
        'NombreCliente': nombreCliente,
        'Monto': monto,
        'Estado': "ACTIVO",
        'FechaHora': DateTime.now().toIso8601String(),
        'IdNotificationApp': idnotifacion,
        'IdBilletera': bipe.idBilletera,
        'PackageName': packageName
      };

      try {
        final success = await _sendToApiWithRetry(data);
        if (!success && _retryQueueManager != null) {
          await _retryQueueManager!.addToQueue(data);
        }
      } catch (e) {
        print('Error enviando al API: $e');
        if (_retryQueueManager != null) {
          // Agregar esta verificación
          await _retryQueueManager!.addToQueue(data);
        }
      }
    } catch (e) {
      print('Error procesando mensaje ${bipe.contain}: $e');
      onError?.call('Error al procesar pago ${bipe.contain}');
    }
  }

  Future<bool> _sendToApiWithRetry(Map<String, dynamic> data) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        print('Token no encontrado');
        return false;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/yape'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(data),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        print('Data sent successfully');
        return true;
      } else if (response.statusCode == 401) {
        print('Token inválido o expirado');
        onError?.call('Sesión expirada');
        return false;
      } else {
        print('Failed to send data. Status code: ${response.statusCode}');
        onError?.call('Error al enviar datos al servidor');
        return false;
      }
    } catch (e) {
      print('Error sending data: $e');
      onError?.call('Error de conexión');
      return false;
    }
  }

  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('jwt_token');
    } catch (e) {
      print('Error obteniendo token: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    print('NotificationService - Disposing...');
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _stopAggressiveReconnect(); // Cancelar reconexión agresiva
    await _notificationSubscription?.cancel();
    await _retryQueueManager?.dispose();
    print('NotificationService - Disposed');
  }
}
