# Estas líneas mantenían todo el paquete, lo que provocaba que se incluyeran referencias no deseadas
#-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
#-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }


# Http
-keep class com.android.okhttp.** { *; }
-keep class okio.** { *; }

# Shared Preferences
-keep class androidx.preference.** { *; }

# Background Service
-keep class com.example.myapp.** { *; }

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }

# Notification Listener
-keep class com.pravera.notification_listener_service.** { *; }