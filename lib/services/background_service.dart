import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'notification_service.dart';
import 'signalr_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(YapeAlertTaskHandler());
}

class YapeAlertTaskHandler extends TaskHandler {
  final NotificationService _notificationService = NotificationService();
  final SignalRService _signalRService = SignalRService();

  @override
Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
  print('TaskHandler - iniciando servicios');
  try {
    print('TaskHandler - inicializando NotificationService');
    // Asegurar que el servicio de notificaciones tenga los permisos
    final isGranted = await NotificationListenerService.isPermissionGranted();
    if (!isGranted) {
      print('TaskHandler - solicitando permisos de notificación');
      await NotificationListenerService.requestPermission();
    }
    
    // Inicializar el servicio de notificaciones
    await _notificationService.initialize();
    print('TaskHandler - NotificationService inicializado');
    
    final prefs = await SharedPreferences.getInstance();
    final idNegocio = prefs.getInt('idNegocio')?.toString();
    final idUsuario = prefs.getInt('idUsuario')?.toString();
    
    if (idNegocio != null && idUsuario != null) {
      // Configurar callbacks
      _notificationService.onNotificationReceived = (message) {
        print('TaskHandler - Notificación recibida: $message');
        FlutterForegroundTask.sendDataToMain({
          'type': 'notification',
          'message': message
        });
      };

      _signalRService.onConnectionStateChanged = (isConnected, message) {
        print('TaskHandler - Estado SignalR: $isConnected, $message');
        FlutterForegroundTask.updateService(
          notificationTitle: 'YapeAlerta',
          notificationText: message,
        );
        FlutterForegroundTask.sendDataToMain({
          'isConnected': isConnected,
          'message': message
        });
      };

      await _signalRService.iniciarConexion(idNegocio, idUsuario);
    }
  } catch (e) {
    print('TaskHandler - Error en onStart: $e');
  }
}

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Verificar que los servicios sigan activos
    print('Service is running - ${DateTime.now()}');
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('onDestroy');
    await _signalRService.detenerConexion();
    _notificationService.dispose();
  }


  @override
  void onNotificationButtonPressed(String id) {
    print('onNotificationButtonPressed: $id');
  }

  @override
  void onNotificationPressed() {
    print('onNotificationPressed');
  }

  @override
void onReceiveData(Object data) {
  if (data == 'getStatus') {
    // Enviamos el estado actual a la UI
    FlutterForegroundTask.sendDataToMain({
      'isConnected': _signalRService.isConnected,
      'message': _signalRService.isConnected ? 'Conectado' : 'Desconectado'
    });
  }
}
}