import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'dart:io';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  
  factory PermissionService() {
    return _instance;
  }
  
  PermissionService._internal();

  Future<Map<String, bool>> checkAllPermissions() async {
    final Map<String, bool> permissions = {
      'notification': false,
      'battery': false,
      'notificationListener': false,
    };

    // Verificar permiso de notificaciones
    final notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
    permissions['notification'] = notificationPermission == NotificationPermission.granted;

    if (Platform.isAndroid) {
      // Verificar optimización de batería
      permissions['battery'] = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      
      // Verificar permiso de lectura de notificaciones
      permissions['notificationListener'] = await NotificationListenerService.isPermissionGranted();
    } else {
      // En iOS estos permisos no son necesarios
      permissions['battery'] = true;
      permissions['notificationListener'] = true;
    }

    return permissions;
  }

  Future<bool> requestNotificationPermission() async {
    final permission = await FlutterForegroundTask.requestNotificationPermission();
    return permission == NotificationPermission.granted;
  }

  Future<bool> requestBatteryOptimization() async {
    if (!Platform.isAndroid) return true;
    return await FlutterForegroundTask.requestIgnoreBatteryOptimization();
  }

  Future<bool> requestNotificationListener() async {
    if (!Platform.isAndroid) return true;
    return await NotificationListenerService.requestPermission();
  }
}