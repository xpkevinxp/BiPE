package com.centralizador.bipealerta

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d("BootReceiver", "BiPE Device Booted - Process Created")
            // El sistema debería reconectar el NotificationListener automáticamente.
            // La existencia de este receiver asegura que el proceso pueda despertar.
        }
    }
}
