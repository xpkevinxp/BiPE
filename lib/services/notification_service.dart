import 'dart:async';

import 'package:bipealerta/models/BipeModel.dart';
import 'package:bipealerta/services/auth_service.dart';
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
  final AuthService _authService = AuthService();
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


      // Verificamos si es un evento de eliminación
    if (event.hasRemoved == true) {
      print('Notificación eliminada: $content');
      return;
    }


      print('Notification received: $content');

      if (content == null || idnotifacion == null) {
        print('Notificación inválida: contenido o ID nulo');
        return;
      }

      final bipes = await _authService.getBipes();
      for (var bipe in bipes) {
        if (content.contains(bipe.contain)) {
          onNotificationReceived?.call(content);
          await processMessage(content, idnotifacion, bipe);
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
      String message, int idnotifacion, Bipe bipe) async {
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
    _notificationSubscription?.cancel();
  }
}
