import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:permission_handler/permission_handler.dart';
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
    final notificationStatus = await Permission.notification.status;
    permissions['notification'] = notificationStatus.isGranted;

    if (Platform.isAndroid) {
      // Verificar optimización de batería
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      permissions['battery'] = batteryStatus.isGranted;
      
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
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> requestBatteryOptimization() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  Future<bool> requestNotificationListener() async {
    if (!Platform.isAndroid) return true;
    return await NotificationListenerService.requestPermission();
  }
}
