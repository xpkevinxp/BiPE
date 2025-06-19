import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class HowItWorksWidget extends StatelessWidget {
  const HowItWorksWidget({super.key});

  void _shareWorkerLink() async {
    const String link = 'https://www.bipealerta.com/login';
    const String message = 'Este es el link de trabajador que accederás para recibir las notificaciones de BiPe Alerta en tiempo real: $link';
    
    try {
      await Share.share(message, subject: 'Link de Acceso - BiPe Alerta');
    } catch (e) {
      print('Error al compartir: $e');
    }
  }

  void _copyToClipboard(BuildContext context) async {
    const String link = 'https://www.bipealerta.com/login';
    await Clipboard.setData(const ClipboardData(text: link));
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copiado al portapapeles'),
          backgroundColor: Color(0xFF8A56FF),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8A56FF), Color(0xFF9E73FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.help_outline,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '¿Cómo funciona BiPe Alerta?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Paso 1
                    _buildStep(
                      number: '1',
                      icon: Icons.smartphone,
                      title: 'Instalación Principal',
                      description:
                          'Como dueño ya has instalado la app que te permitirá capturar y reenviar automáticamente las notificaciones de Yape, Plin u otras apps de pago a tus trabajadores.',
                      color: const Color(0xFF8A56FF),
                    ),

                    const SizedBox(height: 20),

                    // Paso 2
                    _buildStep(
                      number: '2',
                      icon: Icons.settings,
                      title: 'Gestión de Trabajadores',
                      description:
                          'Desde el "Panel de Administración" puedes crear y gestionar las credenciales de acceso para tus trabajadores de forma segura.',
                      color: const Color(0xFF9E73FF),
                    ),

                    const SizedBox(height: 20),

                    // Paso 3
                    _buildStep(
                      number: '3',
                      icon: Icons.people,
                      title: 'Acceso de Trabajadores',
                      description:
                          'Toca y comparte este link con tus trabajadores. Ellos accederán con las credenciales enviadas a tu WhatsApp durante el registro.',
                      color: const Color(0xFFAB85FF),
                      hasWebLink: true,
                      context: context,
                    ),

                    const SizedBox(height: 20),

                    // Paso 4
                    _buildStep(
                      number: '4',
                      icon: Icons.notifications_active,
                      title: 'Funcionamiento Automático',
                      description:
                          'BiPe Alerta detecta automáticamente las notificaciones de pagos y las reenvía instantáneamente a todos tus trabajadores conectados.',
                      color: const Color(0xFF7847E0),
                    ),

                    const SizedBox(height: 24),

                    // Sección de seguridad
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.security,
                                color: Colors.green.shade600,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '100% Seguro y Privado',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '🔒 Nunca pedimos credenciales bancarias\n🔒 No accedemos a cuentas personales\n🔒 Solo detectamos y reenvía notificaciones\n🔒 Tus datos están completamente protegidos',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Botón de acción
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _shareWorkerLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8A56FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.share, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Compartir Link con Trabajadores',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    bool hasWebLink = false,
    BuildContext? context,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Número del paso
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Contenido del paso
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              if (hasWebLink) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => context != null ? _copyToClipboard(context) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, color: color, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Toca para copiar: www.bipealerta.com/login',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
} 