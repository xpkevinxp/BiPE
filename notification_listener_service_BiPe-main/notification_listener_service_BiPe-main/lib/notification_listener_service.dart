import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:notification_listener_service/notification_event.dart';

const MethodChannel methodeChannel =
    MethodChannel('x-slayer/notifications_channel');
const EventChannel _eventChannel = EventChannel('x-slayer/notifications_event');
Stream<ServiceNotificationEvent>? _stream;

/// Estado de conexión del NotificationListenerService
class ConnectionStatus {
  final bool isConnected;
  final DateTime? lastConnectedTime;
  final DateTime? lastDisconnectedTime;

  ConnectionStatus({
    required this.isConnected,
    this.lastConnectedTime,
    this.lastDisconnectedTime,
  });

  factory ConnectionStatus.fromMap(Map<dynamic, dynamic> map) {
    return ConnectionStatus(
      isConnected: map['isConnected'] ?? false,
      lastConnectedTime: map['lastConnectedTime'] != null && map['lastConnectedTime'] > 0
          ? DateTime.fromMillisecondsSinceEpoch(map['lastConnectedTime'])
          : null,
      lastDisconnectedTime: map['lastDisconnectedTime'] != null && map['lastDisconnectedTime'] > 0
          ? DateTime.fromMillisecondsSinceEpoch(map['lastDisconnectedTime'])
          : null,
    );
  }

  @override
  String toString() {
    return 'ConnectionStatus(isConnected: $isConnected, lastConnected: $lastConnectedTime, lastDisconnected: $lastDisconnectedTime)';
  }
}

class NotificationListenerService {
  NotificationListenerService._();

  /// Stream the incoming notifications events
  static Stream<ServiceNotificationEvent> get notificationsStream {
    if (Platform.isAndroid) {
      _stream ??=
          _eventChannel.receiveBroadcastStream().map<ServiceNotificationEvent>(
                (event) => ServiceNotificationEvent.fromMap(event),
              );
      return _stream!;
    }
    throw Exception("Notifications API exclusively available on Android!");
  }

  /// Request notification permission
  /// It will open the notification settings page and return `true` once the permission granted.
  static Future<bool> requestPermission() async {
    try {
      return await methodeChannel.invokeMethod('requestPermission');
    } on PlatformException catch (error) {
      log("$error");
      return Future.value(false);
    }
  }

  /// Check if notification permission is enabled
  static Future<bool> isPermissionGranted() async {
    try {
      return await methodeChannel.invokeMethod('isPermissionGranted');
    } on PlatformException catch (error) {
      log("$error");
      return false;
    }
  }

  // ============================================================
  // NUEVOS MÉTODOS PARA XIAOMI Y DISPOSITIVOS CON RESTRICCIONES
  // ============================================================

  /// Verifica si el servicio está conectado y recibiendo notificaciones.
  /// Útil para detectar el "Zombie Service" en Xiaomi donde la app está viva
  /// pero el enlace con el sistema está roto.
  static Future<bool> isServiceConnected() async {
    if (!Platform.isAndroid) return false;
    try {
      return await methodeChannel.invokeMethod('isServiceConnected');
    } on PlatformException catch (error) {
      log("Error checking service connection: $error");
      return false;
    }
  }

  /// Obtiene el estado detallado de la conexión del servicio.
  /// Incluye timestamps de última conexión/desconexión para debugging.
  static Future<ConnectionStatus> getConnectionStatus() async {
    if (!Platform.isAndroid) {
      return ConnectionStatus(isConnected: false);
    }
    try {
      final result = await methodeChannel.invokeMethod('getConnectionStatus');
      return ConnectionStatus.fromMap(result);
    } on PlatformException catch (error) {
      log("Error getting connection status: $error");
      return ConnectionStatus(isConnected: false);
    }
  }

  /// Fuerza la reconexión del NotificationListenerService.
  /// 
  /// Implementa el "Toggle del Componente" recomendado para Xiaomi:
  /// Deshabilita y habilita el componente para forzar al sistema
  /// a reinicializar el enlace con el servicio.
  /// 
  /// Úsalo cuando detectes que [isServiceConnected] devuelve false
  /// pero los permisos están concedidos, o como parte de un Watchdog
  /// periódico (cada 15-20 minutos).
  /// 
  /// Ejemplo:
  /// ```dart
  /// final isConnected = await NotificationListenerService.isServiceConnected();
  /// if (!isConnected) {
  ///   await NotificationListenerService.reconnectService();
  /// }
  /// ```
  static Future<bool> reconnectService() async {
    if (!Platform.isAndroid) return false;
    try {
      log("🔄 Solicitando reconexión del servicio...");
      final result = await methodeChannel.invokeMethod('reconnectService');
      log("✅ Reconexión completada: $result");
      return result ?? false;
    } on PlatformException catch (error) {
      log("❌ Error en reconnectService: $error");
      return false;
    }
  }

  /// Solicita al sistema que vuelva a enlazar el NotificationListenerService.
  /// 
  /// Usa la API oficial de Android [requestRebind] (disponible desde API 24).
  /// Este método es más "suave" que [reconnectService] y es el que Android
  /// recomienda usar cuando se detecta una desconexión en [onListenerDisconnected].
  /// 
  /// El paquete ya llama esto automáticamente cuando detecta desconexión,
  /// pero puedes llamarlo manualmente si lo necesitas.
  static Future<bool> forceRequestRebind() async {
    if (!Platform.isAndroid) return false;
    try {
      log("🔄 Solicitando rebind...");
      final result = await methodeChannel.invokeMethod('forceRequestRebind');
      return result ?? false;
    } on PlatformException catch (error) {
      log("❌ Error en forceRequestRebind: $error");
      return false;
    }
  }

  /// Verifica la salud del servicio y reconecta si es necesario.
  /// 
  /// Este es un método de conveniencia que combina la verificación
  /// de estado con la reconexión automática. Ideal para usar en un
  /// Timer periódico o WorkManager.
  /// 
  /// Ejemplo de uso con Timer:
  /// ```dart
  /// Timer.periodic(Duration(minutes: 15), (_) async {
  ///   await NotificationListenerService.checkAndReconnectIfNeeded();
  /// });
  /// ```
  static Future<bool> checkAndReconnectIfNeeded() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final hasPermission = await isPermissionGranted();
      if (!hasPermission) {
        log("⚠️ No hay permiso de notificaciones");
        return false;
      }

      final isConnected = await isServiceConnected();
      if (!isConnected) {
        log("⚠️ Servicio desconectado - Intentando reconectar...");
        return await reconnectService();
      }
      
      log("✅ Servicio funcionando correctamente");
      return true;
    } catch (e) {
      log("❌ Error en checkAndReconnectIfNeeded: $e");
      return false;
    }
  }
}
