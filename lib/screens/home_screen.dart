import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/background_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final List<String> notifications = [];
  final ValueNotifier<Object?> _taskDataListenable = ValueNotifier(null);
  bool _isLoggingOut = false;
  bool _isLoading = true;
  String? _connectionMessage;
  var nombre = "";
  var nombreNegocio = "";
  var nombrePlan = "";

  Future<void> _requestPermissions() async {
    final NotificationPermission notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (Platform.isAndroid) {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }

      // Cambiar por la nueva librería
      final hasPermission = await NotificationsListener.hasPermission;
      if (!hasPermission!) {
        await NotificationsListener.openPermissionSettings();
      }
    }
}

  Future<void> _startForegroundTask() async {
    if (!await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'BiPeAlerta',
        notificationText: 'Monitoreando notificaciones',
        callback: startCallback,
      );
    }
  }

  Future<void> _stopForegroundTask() async {
    try {
      await FlutterForegroundTask.stopService()
          .timeout(const Duration(seconds: 5), onTimeout: () {
        print('Timeout al detener el servicio');
        throw TimeoutException('No se pudo detener el servicio');
      });
    } catch (e) {
      print('Error al detener el servicio: $e');
    }
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _onReceiveTaskData(Object? data) {
    print('HomeScreen - Datos recibidos: $data');
    if (data != null && mounted) {
      final Map<String, dynamic> receivedData = data as Map<String, dynamic>;

      if (receivedData.containsKey('type') &&
          receivedData['type'] == 'notification') {
        setState(() {
          // Agregar la nueva notificación al inicio
          notifications.insert(
              0, '${DateTime.now()}: ${receivedData['message']}');

          // Mantener solo las 10 más recientes
          if (notifications.length > 10) {
            notifications.removeLast(); // Elimina la más antigua
          }
        });
      } else {
        setState(() {
          _connectionMessage = receivedData['message'] as String;
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idUsuario = prefs.getInt('idUsuario');
      final idNegocio = prefs.getInt('idNegocio');

      nombre = (await _authService.getNombre())!;
      nombreNegocio = (await _authService.getNombreNegocio())!;
      nombrePlan = (await _authService.getNombrePlan())!;

      if (idUsuario == null || idNegocio == null) {
        throw Exception('Datos de usuario no encontrados');
      }

      if (await FlutterForegroundTask.isRunningService) {
        print('Servicio ya en ejecución, esperando estado...');
        FlutterForegroundTask.sendDataToTask('getStatus');
      } else {
        setState(() {
          _connectionMessage = 'Iniciando...';
        });
      }
    } catch (e) {
      print('Error cargando datos: $e');
      _mostrarError('Error al cargar datos');
    }
  }

  Future<void> _initializeApp() async {
    try {
      await _requestPermissions();
      await _startForegroundTask();
      await _loadUserData();
    } catch (e) {
      print('Error en inicialización: $e');
      _mostrarError('Error al iniciar la aplicación');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogout({bool showError = true}) async {
    if (_isLoggingOut) return;

    setState(() => _isLoggingOut = true);
    try {
      print('Iniciando proceso de logout...');
      await _stopForegroundTask();
      print('Servicio detenido');

      await _authService.logout();
      print('Logout completado');

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('Error al cerrar sesión: $e');
      if (showError && mounted) {
        _mostrarError('Error al cerrar sesión');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  // Agregar estos métodos para el WhatsApp
  void _abrirWhatsAppSoporte() async {
    final whatsappUrl =
        "https://wa.me/51901089996?text=Hola,%20necesito%20soporte%20técnico";
    if (await canLaunch(whatsappUrl)) {
      await launch(whatsappUrl);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir WhatsApp'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _abrirWhatsAppUpgrade() async {
    final whatsappUrl =
        "https://wa.me/51901089996?text=Hola,%20quisiera%20información%20sobre%20los%20planes%20premium";
    if (await canLaunch(whatsappUrl)) {
      await launch(whatsappUrl);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir WhatsApp'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return WithForegroundTask(
      child: WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          body: Container(
            width: double.infinity,
            decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, colors: [
              Colors.green.shade300,
              Colors.green.shade200,
              Colors.green.shade100,
            ])),
            child: Column(
              children: [
                const SizedBox(height: 60),
                // Header con título y menú
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FadeInUp(
                              duration: const Duration(milliseconds: 1000),
                              child: const Text(
                                "BiPe Alerta",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold),
                              )),
                          const SizedBox(height: 10),
                          FadeInUp(
                              duration: const Duration(milliseconds: 1300),
                              child: const Text(
                                "Panel de Control",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 18),
                              )),
                        ],
                      ),
                      Row(
                        children: [
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert,
                                color: Colors.white),
                            onSelected: (value) {
                              if (value == 'support') {
                                _abrirWhatsAppSoporte();
                              } else if (value == 'upgrade') {
                                _abrirWhatsAppUpgrade();
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              const PopupMenuItem(
                                value: 'support',
                                child: Row(
                                  children: [
                                    Icon(Icons.support_agent,
                                        color: Colors.green),
                                    SizedBox(width: 8),
                                    Text('Soporte'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'upgrade',
                                child: Row(
                                  children: [
                                    Icon(Icons.upgrade, color: Colors.green),
                                    SizedBox(width: 8),
                                    Text('Mejorar Plan'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: _isLoggingOut
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.logout, color: Colors.white),
                            onPressed: _isLoggingOut ? null : _handleLogout,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Contenido principal con efecto curvo
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(60),
                            topRight: Radius.circular(60))),
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        // Tarjeta de información
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.shade100,
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.business,
                                color: Colors.green.shade400,
                                size: 24,
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nombreNegocio,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      nombre,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        nombrePlan,
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Estado de conexión
                        if (_connectionMessage != null)
                          Container(
                            margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green.shade400,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Conectado",
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 20),
                        // Título de notificaciones
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notifications_none,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Últimas Notificaciones',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Lista de notificaciones
                        Expanded(
                          child: notifications.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.notifications_off_outlined,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No hay notificaciones',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(20),
                                  itemCount: notifications.length,
                                  itemBuilder: (context, index) {
                                    return Card(
                                      elevation: 0,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ListTile(
                                        title: Text(
                                          notifications[index],
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    );
                                  },
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
      ),
    );
  }

  @override
  void dispose() {
    print('Disposing HomeScreen');
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    _taskDataListenable.dispose();
    super.dispose();
  }
}
