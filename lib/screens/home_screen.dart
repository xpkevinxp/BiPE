import 'package:animate_do/animate_do.dart';
import 'package:bipealerta/services/device_helper.dart';
import 'package:bipealerta/services/permissions_widget.dart';
import 'package:bipealerta/widgets/xiaomiguide_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/background_service.dart';
import '../services/permission_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Añadir GlobalKeys para cada elemento que queremos mostrar en el tutorial
  final GlobalKey _negocioShowcaseKey = GlobalKey();
  final GlobalKey _permisosShowcaseKey = GlobalKey();
  final GlobalKey _notificacionesShowcaseKey = GlobalKey();
  final GlobalKey _menuOpcionesShowcaseKey = GlobalKey();
  final GlobalKey _cerrarSesionShowcaseKey = GlobalKey();

  final AuthService _authService = AuthService();
  final PermissionService _permissionService = PermissionService();
  final List<String> notifications = [];
  final ValueNotifier<Object?> _taskDataListenable = ValueNotifier(null);
  bool _isLoggingOut = false;
  bool _isLoading = true;
  String? _connectionMessage;
  Map<String, bool> _permissions = {};
  var nombre = "";
  var nombreNegocio = "";
  var nombrePlan = "";
  bool _isUpdating = false;

  @override
void initState() {
  super.initState();
  FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
  _checkPermissions();
  _initializeApp();
  
  
  // Iniciar el tutorial después de que la pantalla esté cargada
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _startTutorialIfNeeded();
  });
}


  Future<void> _startTutorialIfNeeded() async {
  final prefs = await SharedPreferences.getInstance();
  bool tutorialShown = prefs.getBool('tutorial_shown') ?? false;
  
  if (!tutorialShown && mounted) {
    await Future.delayed(const Duration(milliseconds: 500));
    
    ShowCaseWidget.of(context).startShowCase([
      _negocioShowcaseKey,
      _permisosShowcaseKey,
      _notificacionesShowcaseKey,
      _menuOpcionesShowcaseKey,
      _cerrarSesionShowcaseKey,
    ]);
    
    // Marcar que el tutorial ya se mostró
    await prefs.setBool('tutorial_shown', true);
  }
}
  
  // Implementar un método para iniciar el tutorial manualmente
  void _reiniciarTutorial() {
    ShowCaseWidget.of(context).startShowCase([
      _negocioShowcaseKey,
      _permisosShowcaseKey,
      _notificacionesShowcaseKey,
      _menuOpcionesShowcaseKey,
      _cerrarSesionShowcaseKey,
    ]);
  }

  Future<void> _checkPermissions() async {
    final permissions = await _permissionService.checkAllPermissions();
    if (mounted) {
      setState(() {
        _permissions = permissions;
      });
    }
  }

  Future<void> _handlePermissionRequest(String permission) async {
    bool granted = false;
    switch (permission) {
      case 'notification':
        granted = await _permissionService.requestNotificationPermission();
        break;
      case 'battery':
        granted = await _permissionService.requestBatteryOptimization();
        break;
      case 'notificationListener':
        granted = await _permissionService.requestNotificationListener();
        _checkXiaomiDevice();
        break;
    }

    if (granted && mounted) {
      await _checkPermissions();
    }
  }

  Future<void> checkForUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        await _stopForegroundTask();
        final result = await InAppUpdate.performImmediateUpdate();
        
        if (result == AppUpdateResult.inAppUpdateFailed) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se puede actualizar en este momento. Verifica el espacio de almacenamiento y la batería del dispositivo.'),
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error en actualización: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se puede actualizar en este momento. Inténtalo más tarde.'),
            duration: Duration(seconds: 5),
          ),
        );
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
          notifications.insert(
              0, '${DateTime.now()}: ${receivedData['message']}');
          if (notifications.length > 10) {
            notifications.removeLast();
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

  Future<void> _handleUpdateBipes() async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
      _connectionMessage = 'Actualizando datos...';
    });

    try {
      await _authService.migrateAndUpdateBipes();
      
      // Notificar al servicio en segundo plano
      FlutterForegroundTask.sendDataToTask({'action': 'updateBipes'});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datos actualizados correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _mostrarError('Error al actualizar datos');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _connectionMessage = 'Monitoreando notificaciones';
        });
      }
    }
  }

  Future<void> _initializeApp() async {
    try {
      // Primero verificar actualizaciones de la app
      await checkForUpdate();

      final bipes = await _authService.getBipes();
      if (bipes.any((bipe) => bipe.packageName == '')) {
        await _handleUpdateBipes();
      }

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

  Future<void> _checkXiaomiDevice() async {
    try {
      bool isXiaomi = await DeviceHelper.isXiaomiDevice();
      
      if (isXiaomi && mounted) {
        // Esperar a que la pantalla esté completamente cargada
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Verificar si el diálogo ya se ha mostrado antes
          SharedPreferences.getInstance().then((prefs) {
            bool? dialogShown = prefs.getBool('xiaomi_dialog_shown');
            
            if (dialogShown != true) {
              showDialog(
                context: context,
                builder: (context) => const XiaomiNotificationGuide(),
              ).then((_) {
                // Marcar que el diálogo ya se mostró
                prefs.setBool('xiaomi_dialog_shown', true);
              });
            }
          });
        });
      }
    } catch (e) {
      print('Error al verificar el tipo de dispositivo: $e');
    }
  }

  void _abrirWhatsAppSoporte() async {
    final whatsappUri = Uri.parse(
        "https://wa.me/51901089996?text=Hola,%20necesito%20soporte%20técnico");

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al abrir WhatsApp'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _abrirWhatsAppUpgrade() async {
    final whatsappUri = Uri.parse(
        "https://wa.me/51901089996?text=Hola,%20quisiera%20información%20sobre%20los%20planes%20premium");

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al abrir WhatsApp'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                Colors.green.shade600,
                Colors.green.shade500,
                Colors.green.shade400,
              ])
            ),
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
                            )
                          ),
                          const SizedBox(height: 10),
                          FadeInUp(
                            duration: const Duration(milliseconds: 1300),
                            child: const Text(
                              "Panel de Control",
                              style: TextStyle(
                                color: Colors.white, fontSize: 18),
                            )
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Showcase(
                            key: _menuOpcionesShowcaseKey,
                            title: 'Opciones del menú',
                            description: 'Aquí encontrarás opciones como actualizar bipes, contactar soporte o mejorar tu plan.',
                            targetShapeBorder: const CircleBorder(),
                            tooltipActionConfig: const TooltipActionConfig(
                              position: TooltipActionPosition.inside,
                              alignment: MainAxisAlignment.spaceBetween,
                            ),
                            tooltipActions: [
                              TooltipActionButton(
                                type: TooltipDefaultActionType.previous,
                                name: "Atras",
                                textStyle: const TextStyle(color: Colors.white),
                              ),
                              TooltipActionButton(
                                type: TooltipDefaultActionType.next,
                                name: "Siguiente",
                                textStyle: const TextStyle(color: Colors.white),
                              ),
                            ],
                            child: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.white),
                              onSelected: (value) {
                                switch (value) {
                                  case 'support':
                                    _abrirWhatsAppSoporte();
                                    break;
                                  case 'upgrade':
                                    _abrirWhatsAppUpgrade();
                                    break;
                                  case 'update':
                                    _handleUpdateBipes();
                                    break;
                                  case 'tutorial':
                                    _reiniciarTutorial();
                                    break;
                                  case 'xiaomi_guide':
                                    showDialog(
                                      context: context,
                                      builder: (context) => const XiaomiNotificationGuide(),
                                    );
                                    break;
                                }
                              },
                              itemBuilder: (BuildContext context) => [
                                const PopupMenuItem(
                                  value: 'update',
                                  child: Row(
                                    children: [
                                      Icon(Icons.sync, color: Colors.green),
                                      SizedBox(width: 8),
                                      Text('Actualizar Bipes'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'support',
                                  child: Row(
                                    children: [
                                      Icon(Icons.support_agent, color: Colors.green),
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
                                const PopupMenuItem(
                                  value: 'xiaomi_guide',
                                  child: Row(
                                    children: [
                                      Icon(Icons.phone_android, color: Colors.green),
                                      SizedBox(width: 8),
                                      Text('Configuración Xiaomi/Redmi'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'tutorial',
                                  child: Row(
                                    children: [
                                      Icon(Icons.help_outline, color: Colors.green),
                                      SizedBox(width: 8),
                                      Text('Ver Tutorial'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Showcase(
                            key: _cerrarSesionShowcaseKey,
                            title: 'Cerrar sesión',
                            description: 'Presiona aquí para cerrar sesión y salir de la aplicación.',
                            targetShapeBorder: const CircleBorder(),
                            tooltipActionConfig: const TooltipActionConfig(
                              position: TooltipActionPosition.inside,
                              alignment: MainAxisAlignment.spaceBetween,
                            ),
                            tooltipActions: [
                              TooltipActionButton(
                                type: TooltipDefaultActionType.previous,
                                name: "Atras",
                                textStyle: const TextStyle(color: Colors.white),
                              ),
                              TooltipActionButton(
                                type: TooltipDefaultActionType.skip,
                                name: "Saltar",
                                textStyle: const TextStyle(color: Colors.white),
                              ),
                            ],
                            child: IconButton(
                              icon: _isLoggingOut
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.logout, color: Colors.white),
                              onPressed: _isLoggingOut ? null : _handleLogout,
                            ),
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
                        topRight: Radius.circular(60)
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 30),
                          
                          // Tarjeta de información
                          Showcase(
                            key: _negocioShowcaseKey,
                            title: 'Información de Negocio',
                            description: 'Aquí verás la información de tu negocio, tu nombre y el plan que tienes contratado.',
                            targetShapeBorder: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            tooltipActionConfig: const TooltipActionConfig(
                              position: TooltipActionPosition.inside,
                              alignment: MainAxisAlignment.spaceBetween,
                            ),
                            tooltipActions: [
                              TooltipActionButton(
                                type: TooltipDefaultActionType.skip,
                                name: "Saltar",
                                textStyle: const TextStyle(color: Colors.white),
                              ),
                              TooltipActionButton(
                                type: TooltipDefaultActionType.next,
                                name: "Siguiente",
                                textStyle: const TextStyle(color: Colors.white),
                              ),
                            ],
                            child: Container(
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
                          ),

                          // Widget de Permisos
                          Showcase(
                            key: _permisosShowcaseKey,
                            title: 'Permisos necesarios',
                            description: 'En esta sección puedes verificar y activar los permisos necesarios para que la aplicación funcione correctamente.',
                            targetShapeBorder: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            tooltipActionConfig: const TooltipActionConfig(
                              position: TooltipActionPosition.inside,
                              alignment: MainAxisAlignment.spaceBetween,
                            ),
                            tooltipActions: [
                              TooltipActionButton(
                                type: TooltipDefaultActionType.previous,
                                name: "Atras",
                                textStyle: const TextStyle(color: Colors.white),
                              ),
                              TooltipActionButton(
                                type: TooltipDefaultActionType.next,
                                name: "Siguiente",
                                textStyle: const TextStyle(color: Colors.white),
                              ),
                            ],
                            child: PermissionsWidget(
                              permissions: _permissions,
                              onRequestPermission: _handlePermissionRequest,
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
                                color: _connectionMessage!
                                  .toLowerCase()
                                  .contains('desconectado') ||
                                  _connectionMessage!
                                  .toLowerCase()
                                  .contains('error')
                                  ? Colors.red.shade50
                                  : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _connectionMessage!
                                      .toLowerCase()
                                      .contains('desconectado') ||
                                      _connectionMessage!
                                      .toLowerCase()
                                      .contains('error')
                                      ? Icons.error_outline
                                      : Icons.check_circle,
                                    color: _connectionMessage!
                                      .toLowerCase()
                                      .contains('desconectado') ||
                                      _connectionMessage!
                                      .toLowerCase()
                                      .contains('error')
                                      ? Colors.red.shade400
                                      : Colors.green.shade400,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _connectionMessage!,
                                    style: TextStyle(
                                      color: _connectionMessage!
                                        .toLowerCase()
                                        .contains('desconectado') ||
                                        _connectionMessage!
                                        .toLowerCase()
                                        .contains('error')
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
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
                          Showcase(
                            key: _notificacionesShowcaseKey,
                            title: 'Notificaciones capturadas',
                            description: 'Aquí verás todas las notificaciones de tus apps de pagos que BiPe Alerta ha capturado y procesado.',
                            targetShapeBorder: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            tooltipActionConfig: const TooltipActionConfig(
                              position: TooltipActionPosition.outside,
                              alignment: MainAxisAlignment.spaceBetween,
                            ),
                            tooltipActions: [
                              TooltipActionButton(
                                type: TooltipDefaultActionType.previous,
                                name: "Atras",
                                textStyle: const TextStyle(color: Colors.white),
                              ),
                              TooltipActionButton(
                                type: TooltipDefaultActionType.next,
                                name: "Siguiente",
                                textStyle: const TextStyle(color: Colors.white),
                              ),
                            ],
                            child: Container(
                              height: 300, // Altura fija para la lista
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
                          ),
                        ],
                      ),
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