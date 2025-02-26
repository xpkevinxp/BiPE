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

class NotificationService {
  static const String baseUrl = 'https://apialert.c-centralizador.com/api';
  static const Duration requestTimeout = Duration(seconds: 30);
  final AuthService _authService = AuthService();
  NotificationCallback? onNotificationReceived;
  ErrorCallback? onError;
  RetryQueueManager? _retryQueueManager;

  StreamSubscription? _notificationSubscription;


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
        print("NotificationService - Solicitando permiso...");
        await NotificationListenerService.requestPermission();
      }

      print("NotificationService - Configurando stream de notificaciones");
      _notificationSubscription =
          NotificationListenerService.notificationsStream.listen(
        (event) {
          print(
              "NotificationService - Evento recibido: ${event.packageName} - ${event.content}");
          _handleNotification(event);
        },
        onError: (error) {
          print('NotificationService - Error en stream: $error');
          onError?.call('Error al procesar notificaciones');
        },
      );
      print("NotificationService - Inicialización completada");
    } catch (e) {
      print('NotificationService - Error en initialize: $e');
      onError?.call('Error al inicializar notificaciones');
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
      print('${DateTime.now().toIso8601String()} - Notificación eliminada: $content');
      return;
    }
    
    if (content == null || idnotifacion == null || packageName == null) {
      print('${DateTime.now().toIso8601String()} - Notificación inválida: contenido o ID nulo');
      return;
    }

    print('${DateTime.now().toIso8601String()} - Notificación recibida: $content de app: $packageName');

    // Obtener bipes y verificar que no esté vacío
    final bipes = await _authService.getBipes();
    
    if (bipes.isEmpty) {
      print('ALERTA: Lista de bipes vacía al procesar notificación. Intentando actualizar...');
      try {
        // Intentar actualizar bipes si la lista está vacía
        await _authService.migrateAndUpdateBipes();
        // Obtener la lista actualizada
        final updatedBipes = await _authService.getBipes();
        
        if (updatedBipes.isEmpty) {
          print('ERROR CRÍTICO: No se pudieron cargar bipes después de actualización');
          onError?.call('Error al cargar configuración de notificaciones');
          return;
        }
        
        // Continuar con la lista actualizada
        print('Bipes actualizados correctamente. Continuando procesamiento...');
        
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
        
        print('No se encontró coincidencia con bipes actualizados para: $packageName');
        return;
      } catch (e) {
        print('Error actualizando bipes durante procesamiento de notificación: $e');
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
        if (_retryQueueManager != null) {  // Agregar esta verificación
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

      final response = await http.post(
        Uri.parse('$baseUrl/yape'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      ).timeout(requestTimeout);

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
    await _notificationSubscription?.cancel();
    await _retryQueueManager?.dispose();
  }
}
