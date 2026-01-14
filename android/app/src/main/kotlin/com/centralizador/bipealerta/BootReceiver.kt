package com.centralizador.bipealerta

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.content.ComponentName
import android.service.notification.NotificationListenerService
import notification.listener.service.NotificationListener
import androidx.work.WorkManager
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.ExistingWorkPolicy
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.Constraints
import androidx.work.NetworkType
import java.util.concurrent.TimeUnit

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == "android.intent.action.QUICKBOOT_POWERON") {
            Log.d("BootReceiver", "BiPE Device Booted")
            try {
                NotificationListener.reconnectService(context)
            } catch (_: Exception) {}
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    val cn = ComponentName(context, NotificationListener::class.java)
                    NotificationListenerService.requestRebind(cn)
                }
            } catch (_: Exception) {}
            try {
                val readyIntent = Intent(context, NotificationListener::class.java)
                readyIntent.action = "RECEIVER_READY"
                context.startService(readyIntent)
            } catch (_: Exception) {}
            try {
                val constraints = Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build()
                val oneTime = OneTimeWorkRequestBuilder<BipeHealthWorker>()
                    .setConstraints(constraints)
                    .build()
                WorkManager.getInstance(context).enqueueUniqueWork(
                    "bipe_health_boot",
                    ExistingWorkPolicy.REPLACE,
                    oneTime
                )
                val periodic = PeriodicWorkRequestBuilder<BipeHealthWorker>(15, TimeUnit.MINUTES)
                    .setConstraints(constraints)
                    .build()
                WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                    "bipe_health_periodic",
                    ExistingPeriodicWorkPolicy.KEEP,
                    periodic
                )
            } catch (_: Exception) {}
        }
    }
}
