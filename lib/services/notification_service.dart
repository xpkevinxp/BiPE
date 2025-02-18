import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:bipealerta/models/BipeModel.dart';
import 'package:bipealerta/services/auth_service.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

typedef NotificationCallback = void Function(String message);
typedef ErrorCallback = void Function(String error);

class NotificationService {
  static const String baseUrl = 'https://apialert.c-centralizador.com/api';
  static const Duration requestTimeout = Duration(seconds: 30);
  final AuthService _authService = AuthService();
  NotificationCallback? onNotificationReceived;
  ErrorCallback? onError;

  ReceivePort port = ReceivePort();
  bool isInitialized = false;

  // Callback estático para manejar notificaciones en background
  @pragma('vm:entry-point')
  static void _notificationCallback(NotificationEvent evt) {
    print("Notificación recibida en background: $evt");
    final SendPort? send =
        IsolateNameServer.lookupPortByName("_notification_service_");
    if (send == null) print("No se encontró el SendPort");
    send?.send(evt);
  }

  Future<void> initialize() async {
    try {
      print("NotificationService - Iniciando servicio...");

      if (isInitialized) {
        print("NotificationService - Ya inicializado");
        return;
      }

      // Inicializar el listener con nuestro callback
      await NotificationsListener.initialize(
          callbackHandle: _notificationCallback);

      // Configurar la comunicación entre isolates
      IsolateNameServer.removePortNameMapping("_notification_service_");
      IsolateNameServer.registerPortWithName(
          port.sendPort, "_notification_service_");

      // Escuchar las notificaciones
      port.listen((message) {
        if (message is NotificationEvent) {
          _handleNotification(message);
        }
      });

      final hasPermission = await NotificationsListener.hasPermission;
      print("NotificationService - Permiso concedido: $hasPermission");

      if (hasPermission != true) {
        print("NotificationService - Solicitando permiso...");
        await NotificationsListener.openPermissionSettings();
      }

      // Iniciar el servicio
      final isRunning = await NotificationsListener.isRunning;
      if (isRunning != true) {
        await NotificationsListener.startService(
            foreground: false,
            title: "BiPe Alerta",
            description: "Monitoreando notificaciones");
      }

      isInitialized = true;
      print("NotificationService - Inicialización completada");
    } catch (e) {
      print('NotificationService - Error en initialize: $e');
      onError?.call('Error al inicializar notificaciones');
    }
  }

  void _handleNotification(NotificationEvent event) async {
    try {
      final content = event.text;
      final idnotifacion = "${event.uniqueId!}-${event.id}";

      print('Notification received: $content');

      if (content == null) {
        print('Notificación inválida: contenido o ID nulo');
        return;
      }

      final bipes = await _authService.getBipes();
      for (var bipe in bipes) {
        if (content.contains(bipe.contain)) {
          onNotificationReceived?.call(content);
          await processMessage(content, idnotifacion, bipe);

          // Limpiar la notificación después de procesarla
          if (event.canTap == true) {
            event.tap();
          }
          break;
        }
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
      String message, String idnotifacion, Bipe bipe) async {
    try {
      final userData = await _getUserData();
      if (userData == null) {
        return;
      }

      final RegExp regex = RegExp(bipe.regex);
      final match = regex.firstMatch(message);

      if (match == null) {
        print('Formato de mensaje inválido para ${bipe.contain}');
        return;
      }

      // Para Yape que tiene dos grupos (nombre y monto)
      final String nombreCliente =
          match.groupCount > 1 ? match.group(1)! : bipe.contain;
      final String montoStr =
          match.groupCount > 1 ? match.group(2)! : match.group(1)!;

      await sendToApi({
        'IdUsuarioNegocio': userData['idUsuario'],
        'IdNegocio': userData['idNegocio'],
        'NombreCliente': nombreCliente,
        'Monto': double.parse(montoStr),
        'Estado': "ACTIVO",
        'FechaHora': DateTime.now().toIso8601String(),
        'IdNotificationApp': idnotifacion,
        'IdBilletera': bipe.idBilletera // Cambiamos 'Tipo' por 'IdBilletera'
      });
    } catch (e) {
      print('Error procesando mensaje ${bipe.contain}: $e');
      onError?.call('Error al procesar pago ${bipe.contain}');
    }
  }

  Future<void> sendToApi(Map<String, dynamic> data) async {
    try {
      final token = await getToken();
      if (token == null) {
        print('Token no encontrado');
        return;
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
      } else if (response.statusCode == 401) {
        print('Token inválido o expirado');
        onError?.call('Sesión expirada');
      } else {
        print('Failed to send data. Status code: ${response.statusCode}');
        onError?.call('Error al enviar datos al servidor');
      }
    } catch (e) {
      print('Error sending data: $e');
      onError?.call('Error de conexión');
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

  void dispose() {
    port.close();
    IsolateNameServer.removePortNameMapping("_notification_service_");
    NotificationsListener.stopService();
    isInitialized = false;
  }
}
