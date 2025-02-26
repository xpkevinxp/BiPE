import 'package:bipealerta/services/auth_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  bool isFirst = true;
  DateTime lastNotificationTime = DateTime.now();
  final AuthService authService = AuthService();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> sendNotification() async {
    try {
      print("Entrando a dar notificaciones");
      await flutterLocalNotificationsPlugin.cancelAll();
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'bipe_alerts_channel',
        'BiPe Alertas',
        channelDescription:
            'Notificaciones sobre recordatorios programados para limpiar sus notificaciones',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'BiPe',
        icon: 'mipmap/ic_launcher',
      );
      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidNotificationDetails);
      await flutterLocalNotificationsPlugin.show(
          0,
          'BiPe Alerta',
          'Recuerda limpiar tus notificaciones y asi evitar problemas con el aplicativo',
          notificationDetails,
          payload: 'item x');
    } catch (e) {
      print('Error enviando notificación: $e');
    }
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('TaskHandler - iniciando servicios');
    try {
      // Verificar y actualizar bipes si es necesario
      try {
        print('Verificando Bipes en onStart');
        
        await authService.migrateAndUpdateBipes();
      } catch (e) {
        print('TaskHandler - Error actualizando bipes: $e');
      }

      print('TaskHandler - inicializando NotificationService');
      final isGranted = await NotificationListenerService.isPermissionGranted();
      if (!isGranted) {
        print('TaskHandler - solicitando permisos de notificación');
        await NotificationListenerService.requestPermission();
      }

      await _notificationService.initialize();
      await _notificationService.debugBipesStatus();
      print('TaskHandler - NotificationService inicializado');

      final prefs = await SharedPreferences.getInstance();
      final idNegocio = prefs.getInt('idNegocio')?.toString();
      final idUsuario = prefs.getInt('idUsuario')?.toString();

      if (idNegocio != null && idUsuario != null) {
        _configureCallbacks();
        await _signalRService.iniciarConexion(idNegocio, idUsuario);
      } else {
        print('TaskHandler - ID de negocio o usuario no encontrado');
      }
    } catch (e) {
      print('TaskHandler - Error en onStart: $e');
    }
  }

  void _configureCallbacks() {
    _notificationService.onNotificationReceived = (message) {
      print('TaskHandler - Notificación recibida: $message');
      FlutterForegroundTask.sendDataToMain(
          {'type': 'notification', 'message': message});
    };

    _signalRService.onConnectionStateChanged = (isConnected, message) {
      print('TaskHandler - Estado SignalR: $isConnected, $message');
      FlutterForegroundTask.updateService(
        notificationTitle: 'BiPe Alerta',
        notificationText: message,
      );
      FlutterForegroundTask.sendDataToMain(
          {'isConnected': isConnected, 'message': message});
    };
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    print('Service is running - ${DateTime.now()}');

    try {
      if (isFirst) {
        await sendNotification();
        isFirst = false;
      } else if (DateTime.now().difference(lastNotificationTime).inMinutes >= 30) {
        await sendNotification();
        lastNotificationTime = DateTime.now();
      }
    } catch (e) {
      print('Error en onRepeatEvent: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('onDestroy');
    try {
      await _signalRService.detenerConexion();
      await _notificationService.dispose();
    } catch (e) {
      print('Error en onDestroy: $e');
    }
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
Future<void> onReceiveData(Object data) async {
  try {
    if (data == 'getStatus') {
      FlutterForegroundTask.sendDataToMain({
        'isConnected': _signalRService.isConnected,
        'message': _signalRService.isConnected ? 'Conectado' : 'Desconectado'
      });
    } 
    else if (data is Map<String, dynamic> && data['action'] == 'updateBipes') {
      print('Actualizando bipes en el servicio en segundo plano');
      try {
        await authService.migrateAndUpdateBipes();

         // Reiniciar el servicio de notificaciones
        await _notificationService.dispose();
        await _notificationService.initialize();
        await _notificationService.debugBipesStatus();
        // Confirmar que los bipes se actualizaron correctamente
        FlutterForegroundTask.sendDataToMain({
          'message': 'Bipes actualizados y servicio reiniciado'
        });
      } catch (e) {
        print('Error actualizando bipes en servicio: $e');
        FlutterForegroundTask.sendDataToMain({
          'message': 'Error actualizando bipes en servicio'
        });
      }
    }
  } catch (e) {
    print('Error en onReceiveData: $e');
  }
}
}