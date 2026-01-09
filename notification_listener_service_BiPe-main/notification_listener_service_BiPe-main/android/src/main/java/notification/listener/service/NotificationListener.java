package notification.listener.service;

import static notification.listener.service.NotificationUtils.getBitmapFromDrawable;
import static notification.listener.service.models.ActionCache.cachedNotifications;

import android.annotation.SuppressLint;
import android.app.Notification;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.Icon;
import android.os.Build;
import android.os.Build.VERSION_CODES;
import android.os.Bundle;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.util.Log;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Notification;
import android.graphics.Color;

import androidx.annotation.RequiresApi;

import java.io.ByteArrayOutputStream;

import notification.listener.service.models.Action;


@SuppressLint("OverrideAbstract")
@RequiresApi(api = VERSION_CODES.JELLY_BEAN_MR2)
public class NotificationListener extends NotificationListenerService {

    private static final String TAG = "NotificationListener";
    
    // Estado de conexión del listener - accesible desde el plugin
    public static boolean isConnected = false;
    
    // Timestamp de última conexión para debugging
    public static long lastConnectedTime = 0;
    public static long lastDisconnectedTime = 0;

    /**
     * Llamado cuando el listener se conecta correctamente al sistema.
     * Xiaomi puede llamar esto múltiples veces si reconecta el servicio.
     */
    @Override
    public void onListenerConnected() {
        super.onListenerConnected();
        isConnected = true;
        
        // Iniciar como Foreground Service para evitar que el sistema mate el proceso
        startForegroundService();

        lastConnectedTime = System.currentTimeMillis();
        Log.i(TAG, "✅ Listener CONECTADO correctamente al sistema");
        
        // Notificar a Flutter sobre la conexión
        Intent intent = new Intent(NotificationConstants.INTENT);
        intent.putExtra("connection_event", true);
        intent.putExtra("is_connected", true);
        intent.putExtra("timestamp", lastConnectedTime);
        sendBroadcast(intent);
    }

    /**
     * Llamado cuando el sistema desconecta el listener.
     * En Xiaomi esto puede pasar silenciosamente - aquí intentamos reconectar.
     */
    @Override
    public void onListenerDisconnected() {
        super.onListenerDisconnected();
        isConnected = false;
        
        // Detener foreground pero intentar mantener vivo si es posible
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
             stopForeground(true);
        }

        lastDisconnectedTime = System.currentTimeMillis();
        Log.w(TAG, "⚠️ Listener DESCONECTADO por el sistema - Intentando reconectar...");
        
        // Notificar a Flutter sobre la desconexión
        Intent intent = new Intent(NotificationConstants.INTENT);
        intent.putExtra("connection_event", true);
        intent.putExtra("is_connected", false);
        intent.putExtra("timestamp", lastDisconnectedTime);
        sendBroadcast(intent);
        
        // Intentar reconexión automática (API 24+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                requestRebind(new ComponentName(this, NotificationListener.class));
                Log.i(TAG, "🔄 Solicitando reconexión con requestRebind()...");
            } catch (Exception e) {
                Log.e(TAG, "❌ Error al solicitar reconexión: " + e.getMessage());
            }
        }
    }

    /**
     * Método estático para forzar reconexión desde el Plugin.
     * Implementa el "Toggle del Componente" recomendado para Xiaomi.
     */
    public static void reconnectService(Context context) {
        try {
            PackageManager pm = context.getPackageManager();
            ComponentName componentName = new ComponentName(context, NotificationListener.class);
            
            Log.i(TAG, "🔄 Iniciando Toggle del Componente para reconectar...");
            
            // 1. Deshabilitar el componente
            pm.setComponentEnabledSetting(
                componentName,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            );
            
            // Pequeña pausa para asegurar que el sistema procese el cambio
            try {
                Thread.sleep(100);
            } catch (InterruptedException e) {
                // Ignorar
            }
            
            // 2. Habilitar el componente inmediatamente
            pm.setComponentEnabledSetting(
                componentName,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            );
            
            Log.i(TAG, "✅ Toggle completado - El sistema debería reconectar el listener");
            
        } catch (Exception e) {
            Log.e(TAG, "❌ Error en reconnectService: " + e.getMessage());
        }
    }

    /**
     * Verifica si el listener puede obtener notificaciones activas.
     * Este es el test real de si el "binder" está vivo o muerto.
     */
    public boolean isBinderAlive() {
        try {
            StatusBarNotification[] activeNotifications = getActiveNotifications();
            return activeNotifications != null;
        } catch (Exception e) {
            Log.w(TAG, "Binder parece estar muerto: " + e.getMessage());
            return false;
        }
    }

    @RequiresApi(api = VERSION_CODES.KITKAT)
    @Override
    public void onNotificationPosted(StatusBarNotification notification) {
        // Actualizar estado de conexión - si recibimos notificaciones, estamos conectados
        if (!isConnected) {
            isConnected = true;
            Log.i(TAG, "📥 Notificación recibida - Actualizando estado a CONECTADO");
        }
        handleNotification(notification, false);
    }

    @RequiresApi(api = VERSION_CODES.KITKAT)
    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        handleNotification(sbn, true);
    }

    @RequiresApi(api = VERSION_CODES.KITKAT)
private void handleNotification(StatusBarNotification notification, boolean isRemoved) {
    try {
        String packageName = notification.getPackageName();
        Bundle extras = notification.getNotification().extras;
        byte[] appIcon = getAppIcon(packageName);
        byte[] largeIcon = null;
        Action action = NotificationUtils.getQuickReplyAction(notification.getNotification(), packageName);

        if (Build.VERSION.SDK_INT >= VERSION_CODES.M) {
            largeIcon = getNotificationLargeIcon(getApplicationContext(), notification.getNotification());
        }

        Intent intent = new Intent(NotificationConstants.INTENT);
        intent.putExtra(NotificationConstants.PACKAGE_NAME, packageName);
        intent.putExtra(NotificationConstants.ID, notification.getId());
        intent.putExtra(NotificationConstants.CAN_REPLY, action != null);

        if (NotificationUtils.getQuickReplyAction(notification.getNotification(), packageName) != null) {
            cachedNotifications.put(notification.getId(), action);
        }

        intent.putExtra(NotificationConstants.NOTIFICATIONS_ICON, appIcon);
        intent.putExtra(NotificationConstants.NOTIFICATIONS_LARGE_ICON, largeIcon);

        if (extras != null) {
            CharSequence title = extras.getCharSequence(Notification.EXTRA_TITLE);
            CharSequence text = extras.getCharSequence(Notification.EXTRA_TEXT);

            // Limitar tamaño del texto para evitar TransactionTooLargeException
            String safeTitle = (title == null) ? null : 
                (title.length() > 100 ? title.subSequence(0, 100) + "..." : title.toString());
            
            String safeText = (text == null) ? null : 
                (text.length() > 500 ? text.subSequence(0, 500) + "..." : text.toString());
                
            intent.putExtra(NotificationConstants.NOTIFICATION_TITLE, safeTitle);
            intent.putExtra(NotificationConstants.NOTIFICATION_CONTENT, safeText);
            intent.putExtra(NotificationConstants.IS_REMOVED, isRemoved);
            
            // Solo incluir imagen si la notificación no es demasiado grande
            boolean containsImage = extras.containsKey(Notification.EXTRA_PICTURE);
            intent.putExtra(NotificationConstants.HAVE_EXTRA_PICTURE, containsImage);

            if (containsImage) {
                try {
                    Bitmap bmp = (Bitmap) extras.get(Notification.EXTRA_PICTURE);
                    if (bmp != null) {
                        // Reducir tamaño de imagen si es muy grande
                        Bitmap scaledBmp = bmp;
                        if (bmp.getWidth() > 300 || bmp.getHeight() > 300) {
                            int maxSize = 300;
                            float ratio = Math.min(
                                (float) maxSize / bmp.getWidth(),
                                (float) maxSize / bmp.getHeight()
                            );
                            int width = Math.round(bmp.getWidth() * ratio);
                            int height = Math.round(bmp.getHeight() * ratio);
                            scaledBmp = Bitmap.createScaledBitmap(bmp, width, height, true);
                        }
                        
                        ByteArrayOutputStream stream = new ByteArrayOutputStream();
                        scaledBmp.compress(Bitmap.CompressFormat.JPEG, 70, stream);
                        byte[] imageData = stream.toByteArray();
                        
                        // Solo incluir si no es demasiado grande
                        if (imageData.length < 200000) { // 200KB límite
                            intent.putExtra(NotificationConstants.EXTRAS_PICTURE, imageData);
                        }
                    }
                } catch (Exception e) {
                    // Ignorar errores de procesamiento de imagen
                    Log.e("NotificationListener", "Error procesando imagen: " + e.getMessage());
                }
            }
        }
        sendBroadcast(intent);
    } catch (Exception e) {
        Log.e("NotificationListener", "Error en handleNotification: " + e.getMessage());
    }
}

    public byte[] getAppIcon(String packageName) {
        try {
            PackageManager manager = getBaseContext().getPackageManager();
            Drawable icon = manager.getApplicationIcon(packageName);
            ByteArrayOutputStream stream = new ByteArrayOutputStream();
            getBitmapFromDrawable(icon).compress(Bitmap.CompressFormat.PNG, 100, stream);
            return stream.toByteArray();
        } catch (PackageManager.NameNotFoundException e) {
            e.printStackTrace();
            return null;
        }
    }

    @RequiresApi(api = VERSION_CODES.M)
    private byte[] getNotificationLargeIcon(Context context, Notification notification) {
        try {
            Icon largeIcon = notification.getLargeIcon();
            if (largeIcon == null) {
                return null;
            }
            Drawable iconDrawable = largeIcon.loadDrawable(context);
            Bitmap iconBitmap = ((BitmapDrawable) iconDrawable).getBitmap();
            ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
            iconBitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream);

            return outputStream.toByteArray();
        } catch (Exception e) {
            e.printStackTrace();
            Log.d("ERROR LARGE ICON", "getNotificationLargeIcon: " + e.getMessage());
            return null;
        }
    }

    private void startForegroundService() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                String channelId = "bipe_notification_listener_service";
                String channelName = "BiPE Servicio Activo";
                NotificationChannel channel = new NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_LOW);
                channel.setLightColor(Color.BLUE);
                channel.setLockscreenVisibility(Notification.VISIBILITY_SECRET);
                
                NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
                if (manager != null) {
                    manager.createNotificationChannel(channel);
                    
                    Notification.Builder builder = new Notification.Builder(this, channelId);
                    
                    // Intentar obtener el icono de la app
                    try {
                        int iconId = getApplicationInfo().icon;
                        if (iconId != 0) {
                            builder.setSmallIcon(iconId);
                        } else {
                            builder.setSmallIcon(android.R.drawable.ic_dialog_info);
                        }
                    } catch (Exception e) {
                        builder.setSmallIcon(android.R.drawable.ic_dialog_info);
                    }
                    
                    Notification notification = builder.setOngoing(true)
                            .setContentTitle("BiPE está activo")
                            .setContentText("Escuchando notificaciones en segundo plano...")
                            .setPriority(Notification.PRIORITY_MIN)
                            .setCategory(Notification.CATEGORY_SERVICE)
                            .build();
                            
                    startForeground(112233, notification);
                    Log.i(TAG, "🛡️ Servicio promovido a Foreground");
                }
            } catch (Exception e) {
                Log.e(TAG, "Error iniciando Foreground Service: " + e.getMessage());
            }
        }
    }

}
