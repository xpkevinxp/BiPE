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
        // Notificar a la UI que se recibió una notificación
        onNotificationReceived?.call(content); // Añade esta línea
        await processYapeMessage(content, idnotifacion);
      } else if (content.contains("PLINEARON")) {
        // Notificar a la UI que se recibió una notificación
        onNotificationReceived?.call(content); // Añade esta línea
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
      // Regex más flexible que ignora espacios y hace opcional el S/
      final RegExp regex = RegExp(r"PLINEARON\s*(?:S/)?\s*(\d+\.?\d*)");
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
        'IdNotificationApp': idnotifacion,
        'Tipo': "Plin"
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
      // Ajusta la expresión regular para capturar decimales (ej: 5.50)
      final RegExp regex = RegExp(r"Yape[!]?\s+(.*?)\s+te\s+envi[oó]\s+(?:un\s+pago\s+por\s+)?(?:S/)?\s*(\d+\.?\d*)");
      final match = regex.firstMatch(message);

      if (match?.group(1) == null || match?.group(2) == null) {
        print('Formato de mensaje Yape inválido');
        return;
      }

      // Parsea el monto como double en lugar de int
      await sendToApi({
        'IdUsuarioNegocio': userData['idUsuario'],
        'IdNegocio': userData['idNegocio'],
        'NombreCliente': match!.group(1)!,
        'Monto': double.parse(match.group(2)!), // Usa double.parse
        'Estado': "ACTIVO",
        'FechaHora': DateTime.now().toIso8601String(),
        'IdNotificationApp': idnotifacion,
        'Tipo': "Yape"
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
