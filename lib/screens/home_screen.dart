import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

        // Agregar permiso para leer notificaciones
        final isGranted = await NotificationListenerService.isPermissionGranted();
        if (!isGranted) {
            await NotificationListenerService.requestPermission();
        }
    }
  }

  Future<void> _startForegroundTask() async {
    if (!await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'YapeAlerta',
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

      if (receivedData.containsKey('type') && receivedData['type'] == 'notification') {
        setState(() {
          // Agregar la nueva notificación al inicio
          notifications.insert(0, '${DateTime.now()}: ${receivedData['message']}');

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
          appBar: AppBar(
            title: const Text('Home'),
            actions: [
              IconButton(
                icon: _isLoggingOut
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.logout),
                onPressed: _isLoggingOut ? null : _handleLogout,
              ),
            ],
          ),
          body: Column(
            children: [
              if (_connectionMessage != null)
                Container(
                  color: _connectionMessage?.contains('Conectado') == true
                      ? Colors.green[100]
                      : Colors.red[100],
                  padding: const EdgeInsets.all(8),
                  width: double.infinity,
                  child: Text(
                    _connectionMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _connectionMessage?.contains('Conectado') == true
                          ? Colors.green[900]
                          : Colors.red[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Últimas Notificaciones',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: notifications.isEmpty
                    ? Center(
                  child: Text('No hay notificaciones',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
                    : ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(notifications[index]),
                    );
                  },
                ),
              ),
            ],
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