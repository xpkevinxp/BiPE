import 'package:bipealerta/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuración moderna para Android 15+ (Edge-to-edge)
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  // Inicializar el servicio en segundo plano
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'BiPealerta_service',
      channelName: 'BiPeAlerta Service',
      channelDescription: 'Servicio de monitoreo de BiPe',
      onlyAlertOnce: true,
      showWhen: false, // No muestra la hora
      enableVibration: false, // Deshabilita la vibración
      playSound: false, // Deshabilita el sonido
      visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      priority: NotificationPriority.LOW, // Prioridad baja para no molestar al usuario
    ),
    iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnBoot: true,
      autoRunOnMyPackageReplaced: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
  
  // Inicializar el puerto de comunicación
  FlutterForegroundTask.initCommunicationPort();
  
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt_token');

  runApp(ShowCaseWidget(
    builder: (context) => MyApp(isLoggedIn: token != null),
    autoPlay: false,
    autoPlayDelay: const Duration(seconds: 3),
    onFinish: () {
      print('Todo el tutorial completado');
      // Guardar en SharedPreferences que el tutorial ha terminado completamente
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('tutorial_completed_now', true);
      });
    },
    onComplete: (index, key) {
      // Este callback se activa en cada paso, no lo usamos para determinar el fin del tutorial
      print('Paso del showcase completado: índice $index, key $key');
    },
  ));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  
  const MyApp({super.key, required this.isLoggedIn});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BiPe Alertas',
      theme: ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8A56FF)),
  useMaterial3: true,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: Colors.black,
  ),
  scaffoldBackgroundColor: Colors.white,
),
      initialRoute: isLoggedIn ? '/home' : '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/register': (context) => const RegisterScreen(),
      },
    );
  }
}