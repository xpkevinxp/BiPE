import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class XiaomiNotificationGuide extends StatelessWidget {
  const XiaomiNotificationGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
          const SizedBox(width: 10),
          const Text('Configuración adicional'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hemos detectado que estás usando un dispositivo Xiaomi/Redmi.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Para que BiPe Alerta funcione correctamente, se requiere una configuración adicional:'
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStep('1', 'Ir a Configuración del teléfono'),
                  _buildStep('2', 'Buscar "Notificaciones"'),
                  _buildStep('3', 'Entrar en "Notificaciones de apps y dispositivos"'),
                  _buildStep('4', 'Activar permiso para "Servicios de Google Play"'),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sin esta configuración, la aplicación no podrá detectar todas las notificaciones correctamente.',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Más tarde'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            _openSettings();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
          ),
          child: const Text('Ir a Configuración', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _openSettings() async {
    // Intentar abrir directamente la configuración de notificaciones
    const settingsUri = 'android-app://com.android.settings/notification_listener_settings';
    final uri = Uri.parse(settingsUri);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Alternativa: abrir configuración general
        await launchUrl(Uri.parse('package:com.android.settings'));
      }
    } catch (e) {
      print('No se pudo abrir la configuración: $e');
    }
  }
}