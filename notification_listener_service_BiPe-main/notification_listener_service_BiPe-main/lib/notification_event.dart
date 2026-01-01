import 'dart:typed_data';

import 'notification_listener_service.dart';

class ServiceNotificationEvent {
  /// the notification id
  int? id;

  /// check if we can reply the Notification
  bool? canReply;

  /// if the notification has an extras image
  bool? haveExtraPicture;

  /// if the notification has been removed
  bool? hasRemoved;

  /// notification extras image
  /// To display an image simply use the [Image.memory] widget.
  /// Example:
  ///
  /// ```
  /// Image.memory(notif.extrasPicture)
  /// ```
  Uint8List? extrasPicture;

  /// notification package name
  String? packageName;

  /// notification title
  String? title;

  /// the notification app icon
  /// To display an image simply use the [Image.memory] widget.
  /// Example:
  ///
  /// ```
  /// Image.memory(notif.appIcon)
  /// ```
  Uint8List? appIcon;

  /// the notification large icon (ex: album covers)
  /// To display an image simply use the [Image.memory] widget.
  /// Example:
  ///
  /// ```
  /// Image.memory(notif.largeIcon)
  /// ```
  Uint8List? largeIcon;

  /// the content of the notification
  String? content;

  // ============================================================
  // NUEVOS CAMPOS PARA EVENTOS DE CONEXIÓN (Xiaomi fix)
  // ============================================================
  
  /// Indica si este evento es de conexión/desconexión del servicio
  /// En lugar de una notificación real.
  bool isConnectionEvent;

  /// Estado de conexión cuando [isConnectionEvent] es true
  bool? isConnected;

  /// Timestamp del evento de conexión
  DateTime? connectionTimestamp;

  ServiceNotificationEvent({
    this.id,
    this.canReply,
    this.haveExtraPicture,
    this.hasRemoved,
    this.extrasPicture,
    this.packageName,
    this.title,
    this.appIcon,
    this.largeIcon,
    this.content,
    this.isConnectionEvent = false,
    this.isConnected,
    this.connectionTimestamp,
  });

  ServiceNotificationEvent.fromMap(Map<dynamic, dynamic> map) : isConnectionEvent = false {
    // Verificar si es un evento de conexión/desconexión
    if (map['connection_event'] == true) {
      isConnectionEvent = true;
      isConnected = map['is_connected'];
      connectionTimestamp = map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : DateTime.now();
      return;
    }

    // Evento de notificación normal
    id = map['id'];
    canReply = map['canReply'];
    haveExtraPicture = map['haveExtraPicture'];
    hasRemoved = map['hasRemoved'];
    extrasPicture = map['notificationExtrasPicture'];
    packageName = map['packageName'];
    title = map['title'];
    appIcon = map['appIcon'];
    largeIcon = map['largeIcon'];
    content = map['content'];
  }

  /// send a direct message reply to the incoming notification
  Future<bool> sendReply(String message) async {
    if (!canReply!) throw Exception("The notification is not replyable");
    try {
      return await methodeChannel.invokeMethod<bool>("sendReply", {
            'message': message,
            'notificationId': id,
          }) ??
          false;
    } catch (e) {
      rethrow;
    }
  }

  @override
  String toString() {
    if (isConnectionEvent) {
      return '''ServiceNotificationEvent.ConnectionEvent(
      isConnected: $isConnected
      timestamp: $connectionTimestamp
      )''';
    }
    return '''ServiceNotificationEvent(
      id: $id
      can reply: $canReply
      packageName: $packageName
      title: $title
      content: $content
      hasRemoved: $hasRemoved
      haveExtraPicture: $haveExtraPicture
      )''';
  }
}
