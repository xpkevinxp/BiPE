# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
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

# Reglas mínimas para window
-keep class androidx.window.core.** { *; }
-keep class androidx.window.layout.** { *; }
-dontwarn androidx.window.**