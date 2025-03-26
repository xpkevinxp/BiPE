import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:signalr_netcore/signalr_client.dart';

class SignalRService {
  static final SignalRService _instance = SignalRService._internal();
  
  factory SignalRService() {
    return _instance;
  }
  
  SignalRService._internal();
  static const String hubUrl = 'https://apialert.c-centralizador.com/dispositivohub';
  static const int reconnectDelay = 5;
  static const int heartbeatInterval = 30;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;
  ConnectivityResult _lastConnectivityResult = ConnectivityResult.none;
  bool _hasInitializedConnectivity = false;
  
  HubConnection? hubConnection;
  Timer? _heartbeatTimer;
  Timer? _reconnectionTimer;
  Timer? _reconnectResetTimer;
  bool isConnected = false;
  String? _idNegocio;
  String? _idUsuario;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 20;
  bool _isConnecting = false;
  bool _isInAutoReconnect = false; // Nueva variable para controlar reconexión automática

  Function(bool isConnected, String message)? onConnectionStateChanged;

  Future<void> iniciarConexion(String idNegocio, String idUsuario) async {
    if (_isConnecting) return;
    
    print('Iniciando conexión SignalR - idNegocio: $idNegocio, idUsuario: $idUsuario');
    
    try {
        if (idNegocio.isEmpty || idUsuario.isEmpty) {
            throw ArgumentError('idNegocio y idUsuario no pueden estar vacíos');
        }

        _isConnecting = true;
        
        // Solo reiniciar el contador si no es parte de un proceso de reconexión automática
        if (!_isInAutoReconnect) {
            _reconnectAttempts = 0;
            print('Reiniciando contador de intentos (conexión manual o inicial)');
        } else {
            print('Manteniendo contador de intentos en: $_reconnectAttempts (reconexión automática)');
        }
        
        _idNegocio = idNegocio;
        _idUsuario = idUsuario;
        
        await _limpiarConexionExistente();
        
        // Inicializar el monitoreo de conectividad si aún no se ha hecho
        if (!_hasInitializedConnectivity) {
            await _initializeConnectivityMonitoring();
        }
        
        await _configurarConexion();
        await _iniciarConexion();
        
        _startReconnectResetTimer();
        
    } catch (e) {
        print('Error iniciando conexión SignalR: $e');
        isConnected = false;
        onConnectionStateChanged?.call(false, 'Error de conexión');
        await _manejarErrorConexion();
    } finally {
        _isConnecting = false;
        // No reiniciamos _isInAutoReconnect aquí
    }
  }

  // Método para inicializar monitoreo de conectividad
  Future<void> _initializeConnectivityMonitoring() async {
    try {
      // Verificar el estado inicial de la conectividad
      _lastConnectivityResult = await _connectivity.checkConnectivity();
      print('Estado inicial de conectividad: $_lastConnectivityResult');
      
      // Configurar el listener para cambios de conectividad
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
      
      _hasInitializedConnectivity = true;
    } catch (e) {
      print('Error inicializando monitoreo de conectividad: $e');
    }
  }

  // Método para manejar cambios de conectividad
  Future<void> _handleConnectivityChange(ConnectivityResult result) async {
    print('Cambio de conectividad detectado: $result (anterior: $_lastConnectivityResult)');
    
    // Si pasamos de no tener conexión a tener algún tipo de conexión
    if (_lastConnectivityResult == ConnectivityResult.none && 
        result != ConnectivityResult.none) {
      print('Conexión recuperada, intentando reconectar...');
      
      // Si no estamos conectados, intentar reconectar
      if (!isConnected) {
        // Pequeña pausa para asegurar que la conexión está estable
        await Future.delayed(const Duration(seconds: 2));
        
        if (!_isConnecting) {
          // Intentar reconectar con un delay para evitar reconexiones inmediatas
          _reconnectAttempts = 0; // Reiniciar contador en cambios de red
          _reconnectionTimer?.cancel();
          _isInAutoReconnect = false;
          await iniciarConexion(_idNegocio!, _idUsuario!);
        }
      }
    } 
    // Si perdemos la conexión completamente
    else if (result == ConnectivityResult.none) {
      print('Conexión perdida');
      if (isConnected) {
        // Actualizar estado pero sin intentar reconectar inmediatamente
        // (evitamos intentos inútiles cuando sabemos que no hay red)
        isConnected = false;
        onConnectionStateChanged?.call(false, 'Sin conexión a internet');
      }
    }
    
    _lastConnectivityResult = result;
  }

  Future<void> _iniciarConexion() async {
    try {
        print('Iniciando conexión al hub...');
        await hubConnection?.start();
        
        if (hubConnection?.state == HubConnectionState.Connected) {
            print('SignalR conectado exitosamente');
            isConnected = true;
            _reconnectionTimer?.cancel();
            _reconnectAttempts = 0;
            _isInAutoReconnect = false; // Reiniciar estado de reconexión
            onConnectionStateChanged?.call(true, 'Conectado');
            await _actualizarEstadoSeguro(true);
            _startHeartbeat();
        } else {
            throw Exception('No se pudo establecer la conexión');
        }
    } catch (e) {
        print('Error en _iniciarConexion: $e');
        isConnected = false;
        onConnectionStateChanged?.call(false, 'Error de conexión');
        throw Exception('Error al iniciar conexión: $e');
    }
  }

  Future<void> _configurarConexion() async {
    hubConnection = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: HttpConnectionOptions(
            skipNegotiation: true,  // Evita la fase de negociación
            transport: HttpTransportType.WebSockets,  // Fuerza WebSockets
          ),
        )
        .withAutomaticReconnect(retryDelays: [
          0,      // Primer intento inmediato
          2000,   // 2 segundos
          5000,   // 5 segundos
          10000,  // 10 segundos
          30000,  // 30 segundos
        ])
        .build();
      
     // Configurar timeouts después de build
    hubConnection?.keepAliveIntervalInMilliseconds = 30000;
    hubConnection?.serverTimeoutInMilliseconds = 90000;

    hubConnection?.onreconnecting(({error}) {
      _manejarReconectando(error);
    });

    hubConnection?.onreconnected(({connectionId}) async {
      await _manejarReconectado(connectionId);
    });

    hubConnection?.onclose(({error}) {
      _manejarCierre(error);
    });
  }

  void _manejarReconectando(dynamic error) {
      print('SignalR reconectando - error: $error');
      isConnected = false;
      onConnectionStateChanged?.call(false, 'Intentando reconectar...');
  }

  Future<void> _manejarReconectado(String? connectionId) async {
      print('SignalR reconectado - connectionId: $connectionId');
      isConnected = true;
      _reconnectAttempts = 0;
      _isInAutoReconnect = false;
      _reconnectionTimer?.cancel();
      onConnectionStateChanged?.call(true, 'Conectado');
      await _actualizarEstadoSeguro(true);
  }

  void _manejarCierre(dynamic error) {
      print('SignalR cerrado - error: $error');
      isConnected = false;
      onConnectionStateChanged?.call(false, 'Desconectado');
      _manejarErrorConexion();
  }

  // Método para iniciar el timer de reinicio
  void _startReconnectResetTimer() {
    _reconnectResetTimer?.cancel();
    // Reinicia los intentos cada 5 minutos para permitir nuevos intentos
    _reconnectResetTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (!isConnected && _reconnectAttempts >= maxReconnectAttempts) {
        print('Reiniciando contador de intentos de reconexión');
        _reconnectAttempts = 0;
        _isInAutoReconnect = false;
        _manejarErrorConexion();
      }
    });
  }

  void _startHeartbeat() {
      _heartbeatTimer?.cancel();
      _failedHeartbeats = 0;
      
      _heartbeatTimer = Timer.periodic(
          const Duration(seconds: heartbeatInterval), 
          _handleHeartbeat
      );
  }

  Future<void> _handleHeartbeat(Timer timer) async {
      if (!isConnected) {
          timer.cancel();
          return;
      }

      try {
          await _actualizarEstadoSeguro(true);
          _failedHeartbeats = 0;
      } catch (e) {
          _failedHeartbeats++;
          print('Error en heartbeat #$_failedHeartbeats: $e');
          if (_failedHeartbeats >= 3) {
              timer.cancel();
              await _manejarErrorConexion();
          }
      }
  }

  Future<void> actualizarEstado(String idNegocio, String idUsuario, bool estaActivo) async {
      if (hubConnection?.state != HubConnectionState.Connected) {
          throw Exception('No hay conexión activa');
      }

      try {
          await hubConnection?.invoke(
              'ActualizarEstadoDispositivo', 
              args: [idNegocio, idUsuario, estaActivo]
          ).timeout(
              const Duration(seconds: 8),
              onTimeout: () {
                  throw TimeoutException('Timeout al actualizar estado');
              }
          );
      } catch (e) {
          if (e is TimeoutException) {
              print('Timeout al actualizar estado');
          } else {
              print('Error al actualizar estado: $e');
          }
          await _manejarErrorConexion();
          rethrow;
      }
  }

  Future<void> _limpiarConexionExistente() async {
    _reconnectionTimer?.cancel();
    if (hubConnection != null) {
      try {
        await hubConnection?.stop();
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        print('Error al detener hubConnection: $e');
      } finally {
        hubConnection = null;
      }
    }
    _heartbeatTimer?.cancel();
  }

  Future<void> _manejarErrorConexion() async {
    isConnected = false;
    
    // Cancelar timer actual si existe
    _reconnectionTimer?.cancel();
    
    if (_reconnectAttempts < maxReconnectAttempts) {
      // Marcar que estamos en un proceso de reconexión automática
      _isInAutoReconnect = true;
      
      _reconnectionTimer = Timer.periodic(const Duration(seconds: reconnectDelay), (timer) async {
        if (_reconnectAttempts >= maxReconnectAttempts) {
          timer.cancel();
          _isInAutoReconnect = false; // Terminamos el proceso automático
          onConnectionStateChanged?.call(false, 'Conexión perdida. Toque para reintentar.');
          return;
        }
        
        _reconnectAttempts++;
        print('Intento de reconexión #$_reconnectAttempts/$maxReconnectAttempts');
        onConnectionStateChanged?.call(false, 
          'Intentando reconectar... $_reconnectAttempts/$maxReconnectAttempts');
          
        try {
          await iniciarConexion(_idNegocio!, _idUsuario!);
          if (isConnected) {
            timer.cancel();
            _isInAutoReconnect = false; // Conexión exitosa, terminamos reconexión automática
          }
        } catch (e) {
          print('Error en intento de reconexión: $e');
        }
      });
    } else {
      _isInAutoReconnect = false;
      onConnectionStateChanged?.call(false, 'Conexión perdida. Toque para reintentar.');
    }
  }

  int _consecutiveErrors = 0;
  Future<void> _actualizarEstadoSeguro(bool estado) async {
      try {
          if (hubConnection?.state == HubConnectionState.Connected) {
              await actualizarEstado(_idNegocio!, _idUsuario!, estado);
              _consecutiveErrors = 0; // Reset en caso de éxito
          }
      } catch (e) {
          _consecutiveErrors++;
          print('Error al actualizar estado (intento $_consecutiveErrors): $e');
          if (_consecutiveErrors > 3) {
              await _manejarErrorConexion();
          }
      }
  }

  int _failedHeartbeats = 0; // Propiedad de clase

  // Método para reintentar conexión manualmente
  Future<void> reintentarConexion() async {
      _reconnectAttempts = 0;
      _reconnectionTimer?.cancel();
      _isInAutoReconnect = false; // Importante: reinicio manual, no automático
      await iniciarConexion(_idNegocio!, _idUsuario!);
  }

  Future<void> detenerConexion() async {
    try {
      _reconnectionTimer?.cancel();
      isConnected = false;
      await _actualizarEstadoSeguro(false);
      await _limpiarConexionExistente();
    } catch (e) {
      print('Error al detener conexión: $e');
    }
  }

  Future<void> dispose() async {
    try {
        _reconnectionTimer?.cancel();
        _reconnectResetTimer?.cancel();
        _heartbeatTimer?.cancel();
        
        // Cancelar la suscripción de conectividad
        await _connectivitySubscription?.cancel();
        _connectivitySubscription = null;
        _hasInitializedConnectivity = false;
        
        await detenerConexion();
        _idNegocio = null;
        _idUsuario = null;
        _reconnectAttempts = 0;
        _isInAutoReconnect = false;
    } catch (e) {
        print('Error en dispose: $e');
    }
  }
}