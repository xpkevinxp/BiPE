import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';

class SignalRService {
  static final SignalRService _instance = SignalRService._internal();
  
  factory SignalRService() {
    return _instance;
  }
  
  SignalRService._internal();
  static const String hubUrl = 'https://apialert.c-centralizador.com/dispositivohub';
  static const int reconnectDelay = 10;
  static const int heartbeatInterval = 15;

  StreamSubscription? _connectivitySubscription;
  HubConnection? hubConnection;
  Timer? _heartbeatTimer;
  Timer? _reconnectionTimer;
  bool isConnected = false;
  String? _idNegocio;
  String? _idUsuario;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 20;
  bool _isReconnecting = false;

  Function(bool isConnected, String message)? onConnectionStateChanged;

  Future<void> iniciarConexion(String idNegocio, String idUsuario) async {
    if (_isReconnecting) return;
    
    print('Iniciando conexión SignalR - idNegocio: $idNegocio, idUsuario: $idUsuario');
    
    _idNegocio = idNegocio;
    _idUsuario = idUsuario;
    _reconnectAttempts = 0;
    
    try {
      if (idNegocio.isEmpty || idUsuario.isEmpty) {
  throw ArgumentError('idNegocio y idUsuario no pueden estar vacíos');
}
_isReconnecting = true;
      await _limpiarConexionExistente();
      
      hubConnection = HubConnectionBuilder()
    .withUrl(hubUrl)
    .withAutomaticReconnect(retryDelays: [])  // Deshabilitar reconexión automática
    .build();

      hubConnection?.onreconnecting(({error}) {
        print('SignalR reconectando - error: $error');
        isConnected = false;
        onConnectionStateChanged?.call(false, 'Intentando reconectar...');
      });

      hubConnection?.onreconnected(({connectionId}) async {
        print('SignalR reconectado - connectionId: $connectionId');
        isConnected = true;
        _reconnectAttempts = 0;
        _reconnectionTimer?.cancel();
        onConnectionStateChanged?.call(true, 'Conectado');
        await _actualizarEstadoSeguro(true);
      });

      hubConnection?.onclose(({error}) {
        print('SignalR cerrado - error: $error');
        isConnected = false;
        onConnectionStateChanged?.call(false, 'Desconectado');
        _manejarErrorConexion();
      });
      print('Vamos a conectar');
      await hubConnection?.start();
      print('SignalR conectado exitosamente');
      isConnected = true;
      _reconnectionTimer?.cancel();
      onConnectionStateChanged?.call(true, 'Conectado');
      await _actualizarEstadoSeguro(true);
      _startHeartbeat();
      
    } catch (e) {
      print('Error iniciando conexión SignalR: $e');
      isConnected = false;
      onConnectionStateChanged?.call(false, 'Error de conexión');
      await _manejarErrorConexion();
    }
    finally {
        _isReconnecting = false;
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
    _connectivitySubscription?.cancel();
    _heartbeatTimer?.cancel();
  }

  Future<void> _manejarErrorConexion() async {
  isConnected = false;
  if (_reconnectAttempts < maxReconnectAttempts) {
    _reconnectionTimer?.cancel();
    
    _reconnectionTimer = Timer.periodic(const Duration(seconds: reconnectDelay), (timer) async {
      if (_reconnectAttempts >= maxReconnectAttempts) {
        timer.cancel();
        onConnectionStateChanged?.call(false, 'Conexión perdida. Toque para reintentar.');
        return;
      }
      
      _reconnectAttempts++;
      print('Intento de reconexión #$_reconnectAttempts');
      onConnectionStateChanged?.call(false, 
        'Intentando reconectar... $_reconnectAttempts/$maxReconnectAttempts');
        
      try {
        await iniciarConexion(_idNegocio!, _idUsuario!);
        if (isConnected) {
          timer.cancel();
        }
      } catch (e) {
        print('Error en intento de reconexión: $e');
      }
    });
  } else {
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

  Future<void> actualizarEstado(String idNegocio, String idUsuario, bool estaActivo) async {
    if (hubConnection?.state != HubConnectionState.Connected) {
      throw Exception('No hay conexión activa');
    }

    try {
      await hubConnection?.invoke('ActualizarEstadoDispositivo', 
        args: [idNegocio, idUsuario, estaActivo])
        .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      print('Timeout al actualizar estado');
      await _manejarErrorConexion();
      rethrow;
    } catch (e) {
      print('Error al actualizar estado: $e');
      await _manejarErrorConexion();
      rethrow;
    }
  }

int _failedHeartbeats = 0; // Propiedad de clase

void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _failedHeartbeats = 0;
    
    _heartbeatTimer = Timer.periodic(const Duration(seconds: heartbeatInterval), (timer) async {
        try {
            await _actualizarEstadoSeguro(true);
            _failedHeartbeats = 0;
        } catch (e) {
            _failedHeartbeats++;
            if (_failedHeartbeats >= 3) {
                timer.cancel();
                await _manejarErrorConexion();
            }
        }
    });
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

  Future<void> reintentarConexion() async {
    _reconnectAttempts = 0;
    _reconnectionTimer?.cancel();
    await iniciarConexion(_idNegocio!, _idUsuario!);
  }

  Future<void> dispose() async {
    try {
        _reconnectionTimer?.cancel();
        _heartbeatTimer?.cancel();
        _connectivitySubscription?.cancel();
        await detenerConexion();
        _idNegocio = null;
        _idUsuario = null;
        _reconnectAttempts = 0;
    } catch (e) {
        print('Error en dispose: $e');
    }
}
}