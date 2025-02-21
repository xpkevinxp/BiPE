import 'package:flutter/material.dart';

class PermissionsWidget extends StatelessWidget {
  final Map<String, bool> permissions;
  final Function(String) onRequestPermission;

  const PermissionsWidget({
    Key? key,
    required this.permissions,
    required this.onRequestPermission,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final missingPermissions = permissions.entries.where((e) => !e.value).toList();

    if (missingPermissions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text(
                'Permisos requeridos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...missingPermissions.map((permission) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ElevatedButton.icon(
              onPressed: () => onRequestPermission(permission.key),
              icon: _getPermissionIcon(permission.key),
              label: Text(_getPermissionText(permission.key)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade100,
                foregroundColor: Colors.orange.shade900,
              ),
            ),
          )),
        ],
      ),
    );
  }

  Icon _getPermissionIcon(String permission) {
    switch (permission) {
      case 'notification':
        return const Icon(Icons.notifications);
      case 'battery':
        return const Icon(Icons.battery_alert);
      case 'notificationListener':
        return const Icon(Icons.notifications_active);
      default:
        return const Icon(Icons.error);
    }
  }

  String _getPermissionText(String permission) {
    switch (permission) {
      case 'notification':
        return 'Permitir notificaciones';
      case 'battery':
        return 'Optimización de batería';
      case 'notificationListener':
        return 'Acceso a notificaciones';
      default:
        return 'Permiso desconocido';
    }
  }
}