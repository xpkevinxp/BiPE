import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
              'Para que BiPe Alerta funcione correctamente, necesitas activar el permiso especial de notificaciones:'
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
                  _buildStep('1', 'El botón te llevará a "Notificaciones de apps y dispositivos"'),
                  _buildStep('2', 'Buscar "BiPe Alerta" en la lista'),
                  _buildStep('3', 'Activar el permiso para "BiPe Alerta"'),
                  _buildStep('4', 'Confirmar que está activado (aparecerá en la lista)'),
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
                    child:                     Text(
                      'Este permiso es esencial para que BiPe Alerta pueda detectar las notificaciones de Yape, Plin y otras apps de pago.',
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
          child: const Text('Ir a Permisos Especiales', style: TextStyle(color: Colors.white)),
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
    const platform = MethodChannel('com.centralizador.bipealerta/settings');
    
    try {
      // Intentar abrir directamente la configuración de Notification Listener
      await platform.invokeMethod('openNotificationListenerSettings');
    } catch (e) {
      print('No se pudo abrir Notification Listener Settings: $e');
      
      try {
        // Segundo intento: abrir la configuración de notificaciones generales
        await platform.invokeMethod('openNotificationSettings');
      } catch (e2) {
        print('No se pudo abrir configuración de notificaciones: $e2');
        
        try {
          // Último intento: abrir configuración de la aplicación
          await platform.invokeMethod('openAppSettings');
        } catch (e3) {
          print('No se pudo abrir ninguna configuración: $e3');
        }
      }
    }
  }
}