import 'dart:async';

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

  NotificationCallback? onNotificationReceived;
  ErrorCallback? onError;

  StreamSubscription? _notificationSubscription;

  Future<void> initialize() async {
    try {
      print("NotificationService - Iniciando servicio...");
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

  void _handleNotification(ServiceNotificationEvent event) async {
    try {
      final content = event.content;
      final idnotifacion = event.id;
      print('Notification received: $content');

      if (content == null || idnotifacion == null) {
        print('Notificación inválida: contenido o ID nulo');
        return;
      }

      if (content.contains("Yape!")) {
        await processYapeMessage(content, idnotifacion);
      } else if (content.contains("PLINEARON")) {
        await processPlinMessage(content, idnotifacion);
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

  Future<void> processPlinMessage(String message, int idnotifacion) async {
    try {
      final userData = await _getUserData();
      if (userData == null) {
        return;
      }
      final RegExp regex = RegExp(r"Te PLINEARON S/(\d+\.\d+).*");
      final match = regex.firstMatch(message);

      if (match?.group(1) == null) {
        print('Formato de mensaje PLIN inválido');
        return;
      }

      await sendToApi({
        'IdUsuarioNegocio': userData['idUsuario'],
        'IdNegocio': userData['idNegocio'],
        'NombreCliente': 'PLIN',
        'Monto': double.parse(match!.group(1)!),
        'Estado': "ACTIVO",
        'FechaHora': DateTime.now().toIso8601String(),
        'IdNotificationApp': idnotifacion
      });
    } catch (e) {
      print('Error procesando mensaje PLIN: $e');
      onError?.call('Error al procesar pago PLIN');
    }
  }

  Future<void> processYapeMessage(String message, int idnotifacion) async {
    try {
      final userData = await _getUserData();
      if (userData == null){
        return;
      }

      final RegExp regex =
          RegExp(r"Yape! (.*?) te envi[oó] un pago por S/ (\d+)");
      final match = regex.firstMatch(message);

      if (match?.group(1) == null || match?.group(2) == null) {
        print('Formato de mensaje Yape inválido');
        return;
      }

      await sendToApi({
        'IdUsuarioNegocio': userData['idUsuario'],
        'IdNegocio': userData['idNegocio'],
        'NombreCliente': match!.group(1)!,
        'Monto': int.parse(match.group(2)!),
        'Estado': "ACTIVO",
        'FechaHora': DateTime.now().toIso8601String(),
        'IdNotificationApp': idnotifacion
      });
    } catch (e) {
      print('Error procesando mensaje Yape: $e');
      onError?.call('Error al procesar pago Yape');
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
    _notificationSubscription?.cancel();
  }
}
