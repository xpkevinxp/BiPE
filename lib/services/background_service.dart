import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'notification_service.dart';
import 'signalr_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(BiPeAlertTaskHandler());
}

class BiPeAlertTaskHandler extends TaskHandler {
  final NotificationService _notificationService = NotificationService();
  final SignalRService _signalRService = SignalRService();

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('TaskHandler - iniciando servicios');
    try {
      print('TaskHandler - inicializando NotificationService');
      
      // Ya no necesitamos verificar los permisos aquí porque lo hace el NotificationService
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

        _notificationService.onError = (error) {
          print('TaskHandler - Error en notificaciones: $error');
          FlutterForegroundTask.updateService(
            notificationTitle: 'BiPe Alerta',
            notificationText: 'Error: $error',
          );
        };

        _signalRService.onConnectionStateChanged = (isConnected, message) {
          print('TaskHandler - Estado SignalR: $isConnected, $message');
          FlutterForegroundTask.updateService(
            notificationTitle: 'BiPe Alerta',
            notificationText: message,
          );
          FlutterForegroundTask.sendDataToMain({
            'isConnected': isConnected,
            'message': message
          });
        };

        await _signalRService.iniciarConexion(idNegocio, idUsuario);
      } else {
        print('TaskHandler - No se encontraron credenciales');
      }
    } catch (e) {
      print('TaskHandler - Error en onStart: $e');
      FlutterForegroundTask.updateService(
        notificationTitle: 'BiPe Alerta',
        notificationText: 'Error al iniciar el servicio',
      );
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
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
      FlutterForegroundTask.sendDataToMain({
        'isConnected': _signalRService.isConnected,
        'message': _signalRService.isConnected ? 'Conectado' : 'Desconectado'
      });
    }
  }
}