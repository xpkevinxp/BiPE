package com.centralizador.bipealerta

import android.content.Context
import android.content.Intent
import android.os.Build
import android.service.notification.NotificationListenerService
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL
import notification.listener.service.NotificationListener

class BipeHealthWorker(appContext: Context, workerParams: WorkerParameters) :
    Worker(appContext, workerParams) {

    override fun doWork(): Result {
        try {
            try {
                NotificationListener.reconnectService(applicationContext)
            } catch (_: Exception) {}
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    NotificationListenerService.requestRebind(
                        android.content.ComponentName(
                            applicationContext,
                            NotificationListener::class.java
                        )
                    )
                }
            } catch (_: Exception) {}
            try {
                val readyIntent = Intent(applicationContext, NotificationListener::class.java)
                readyIntent.action = "RECEIVER_READY"
                applicationContext.startService(readyIntent)
            } catch (_: Exception) {}
            flushNativeQueue()
            return Result.success()
        } catch (_: Exception) {
            return Result.retry()
        }
    }

    private fun flushNativeQueue() {
        try {
            val prefs = applicationContext.getSharedPreferences(
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE
            )
            val token = prefs.getString("flutter.jwt_token", null) ?: return
            val queueStr = prefs.getString("flutter.native_retry_queue", "[]") ?: "[]"
            val arr = JSONArray(queueStr)
            if (arr.length() == 0) return
            val toKeep = JSONArray()
            for (i in 0 until arr.length()) {
                val payload = arr.optJSONObject(i) ?: continue
                val ok = postPayload(token, payload)
                if (!ok) toKeep.put(payload)
            }
            prefs.edit().putString("flutter.native_retry_queue", toKeep.toString()).apply()
        } catch (_: Exception) {}
    }

    private fun postPayload(token: String, payload: JSONObject): Boolean {
        return try {
            val url = URL("https://apialert.c-centralizador.com/api/yape")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.connectTimeout = 15000
            conn.readTimeout = 15000
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Authorization", "Bearer $token")
            val body = payload.toString().toByteArray(Charsets.UTF_8)
            val os: OutputStream = conn.outputStream
            os.write(body)
            os.flush()
            os.close()
            val code = conn.responseCode
            conn.disconnect()
            code == 200
        } catch (_: Exception) {
            false
        }
    }
}
