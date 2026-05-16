package com.munawwaracare.andriod

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.telecom.DisconnectCause
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.telecom.CallAttributesCompat
import androidx.core.telecom.CallControlScope
import androidx.core.telecom.CallsManager
import kotlinx.coroutines.*
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

/**
 * Foreground service that manages incoming calls via Core-Telecom.
 *
 * Key design: each incoming call gets a FRESH coroutine scope so that
 * previous call cleanup never breaks subsequent calls.
 */
class IncomingCallService : Service() {

    companion object {
        private const val TAG = "IncomingCallService"
        private const val CHANNEL_ID = "incoming_call_service"
        private const val NOTIFICATION_ID = 9999

        const val ACTION_INCOMING = "com.munawwaracare.andriod.ACTION_INCOMING_CALL"
        const val ACTION_DECLINE = "com.munawwaracare.andriod.ACTION_DECLINE_CALL"
        const val ACTION_ACCEPT = "com.munawwaracare.andriod.ACTION_ACCEPT_CALL"
        const val ACTION_END = "com.munawwaracare.andriod.ACTION_END_CALL"
        /**
         * Remove duplicate tray entry; CallKit already shows incoming/ongoing UI.
         * Must match `${applicationId}.ACTION_DISMISS_FG_NOTIFICATION` from CallkitIncomingBroadcastReceiver.
         */
        const val ACTION_DISMISS_FG_NOTIFICATION =
            "com.munawwaracare.andriod.ACTION_DISMISS_FG_NOTIFICATION"

        const val EXTRA_CALLER_ID = "callerId"
        const val EXTRA_CALLER_NAME = "callerName"
        const val EXTRA_CHANNEL_NAME = "channelName"

        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_API_BASE_URL = "flutter.api_base_url"
        private const val KEY_DECLINER_ID = "flutter.user_id"
        private const val KEY_CALL_RECORD_ID = "flutter.pending_call_record_id"
        private val FALLBACK_URL = BackendConfig.API_BASE_URL_FALLBACK
    }

    // Each call gets a fresh scope — never reuse a cancelled scope
    private var callScope: CoroutineScope? = null
    private var callControlScope: CallControlScope? = null
    private var currentCallerId: String? = null
    private var callJob: Job? = null
    private var callWasAnswered = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        Log.i(TAG, "📞 onStartCommand action=$action")

        when (action) {
            ACTION_INCOMING -> handleIncoming(intent)
            ACTION_DECLINE -> handleDecline(
                intent,
                intent?.getBooleanExtra("noAnswer", false) == true,
            )
            ACTION_ACCEPT -> handleAccept()
            ACTION_END -> handleEnd()
            ACTION_DISMISS_FG_NOTIFICATION -> dismissForegroundNotificationOnly()
        }
        return START_NOT_STICKY
    }

    private fun handleIncoming(intent: Intent) {
        // Cancel any previous call that wasn't cleaned up
        callJob?.cancel()
        callScope?.cancel()
        callControlScope = null
        callWasAnswered = false

        val callerId = intent.getStringExtra(EXTRA_CALLER_ID) ?: ""
        val callerName = intent.getStringExtra(EXTRA_CALLER_NAME) ?: "Unknown"

        if (callerId.isBlank()) {
            Log.w(TAG, "📞 No callerId in intent, reading from SharedPreferences")
            val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            currentCallerId = prefs.getString("flutter.pending_call_caller_id", null) ?: ""
        } else {
            currentCallerId = callerId
        }

        if (currentCallerId.isNullOrBlank()) {
            Log.e(TAG, "📞 No callerId available at all — stopping")
            stopSelf()
            return
        }

        Log.i(TAG, "📞 Starting foreground for call from $callerName (id=$currentCallerId)")

        // Start as foreground service immediately (must happen within 5 seconds)
        startForeground(NOTIFICATION_ID, buildForegroundNotification(callerName))

        // Create a FRESH coroutine scope for this call
        val freshScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        callScope = freshScope

        // Register with Core-Telecom
        callJob = freshScope.launch {
            try {
                val callsManager = CallsManager(this@IncomingCallService)
                try {
                    callsManager.registerAppWithTelecom(CallsManager.CAPABILITY_BASELINE)
                } catch (e: Exception) {
                    // Already registered — that's fine
                    Log.w(TAG, "📞 registerAppWithTelecom: ${e.message}")
                }

                val attributes = CallAttributesCompat(
                    displayName = callerName,
                    address = Uri.parse("munawwara:$currentCallerId"),
                    direction = CallAttributesCompat.DIRECTION_INCOMING,
                    callType = CallAttributesCompat.CALL_TYPE_AUDIO_CALL
                )

                callsManager.addCall(
                    attributes,
                    onAnswer = { callType ->
                        Log.i(TAG, "📞 Core-Telecom onAnswer")
                        callWasAnswered = true
                    },
                    onDisconnect = { disconnectCause ->
                        Log.i(TAG, "📞 Core-Telecom onDisconnect: ${disconnectCause.reason}")
                        val cid = currentCallerId
                        if (!cid.isNullOrBlank() && !callWasAnswered) {
                            sendDeclineHttp(cid, noAnswer = false)
                        } else if (callWasAnswered) {
                            Log.i(TAG, "📞 Skip decline HTTP — call was already answered")
                        }
                        resetCallState()
                    },
                    onSetActive = {
                        Log.i(TAG, "📞 Core-Telecom onSetActive")
                        callWasAnswered = true
                    },
                    onSetInactive = {
                        Log.i(TAG, "📞 Core-Telecom onSetInactive")
                    }
                ) {
                    callControlScope = this
                    Log.i(TAG, "📞 Core-Telecom call registered successfully")
                }

                // addCall returned — call is over
                Log.i(TAG, "📞 Core-Telecom addCall completed")
                resetCallState()
            } catch (e: Exception) {
                Log.e(TAG, "📞 Core-Telecom error: ${e.message}", e)
                // Core-Telecom failed — service still stays alive for HTTP decline
            }
        }
    }

    private fun handleDecline(intent: Intent?, noAnswer: Boolean = false) {
        Log.i(TAG, "📞 handleDecline called noAnswer=$noAnswer")
        var cid = currentCallerId
        if (cid.isNullOrBlank()) {
            cid = intent?.getStringExtra(EXTRA_CALLER_ID)
        }
        if (cid.isNullOrBlank()) {
            val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            cid = prefs.getString("flutter.pending_call_caller_id", null)
        }
        if (!cid.isNullOrBlank()) {
            val scope = callScope ?: CoroutineScope(Dispatchers.IO)
            scope.launch {
                sendDeclineHttp(cid, noAnswer = noAnswer)
            }
            scope.launch {
                try {
                    callControlScope?.disconnect(DisconnectCause(DisconnectCause.REJECTED))
                } catch (e: Exception) {
                    Log.w(TAG, "📞 Core-Telecom disconnect failed: ${e.message}")
                }
            }
        } else {
            val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            val callRecordId = prefs.getString(KEY_CALL_RECORD_ID, null).orEmpty()
            if (callRecordId.isNotBlank()) {
                val scope = callScope ?: CoroutineScope(Dispatchers.IO)
                scope.launch {
                    sendDeclineHttp("", noAnswer = noAnswer)
                }
            } else {
                Log.w(TAG, "📞 handleDecline skipped — no callerId/callRecordId")
            }
        }
        val scope = callScope ?: CoroutineScope(Dispatchers.IO)
        scope.launch {
            delay(3000)
            resetCallState()
        }
    }

    private fun handleAccept() {
        Log.i(TAG, "📞 handleAccept called")
        callWasAnswered = true
        val scope = callScope ?: return
        scope.launch {
            try {
                callControlScope?.answer(CallAttributesCompat.CALL_TYPE_AUDIO_CALL)
            } catch (e: Exception) {
                Log.w(TAG, "📞 Core-Telecom answer failed: ${e.message}")
            }
        }
    }

    private fun handleEnd() {
        Log.i(TAG, "📞 handleEnd called")
        val scope = callScope ?: CoroutineScope(Dispatchers.IO)
        scope.launch {
            try {
                callControlScope?.disconnect(DisconnectCause(DisconnectCause.LOCAL))
            } catch (e: Exception) {
                Log.w(TAG, "📞 Core-Telecom end failed: ${e.message}")
            }
            resetCallState()
        }
    }

    /**
     * CallKit already shows the incoming / ongoing call notification.
     * This removes our duplicate FGS notification without cancelling Core-Telecom work.
     */
    private fun dismissForegroundNotificationOnly() {
        try {
            Log.i(TAG, "📞 Dismiss duplicate FGS notification (CallKit owns UI)")
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (e: Exception) {
            Log.w(TAG, "📞 dismissForegroundNotificationOnly: ${e.message}")
        }
    }

    /**
     * Reset call state WITHOUT stopping the service.
     * This allows the service to handle subsequent incoming calls.
     */
    private fun resetCallState() {
        Log.i(TAG, "📞 Resetting call state (service stays alive)")
        callJob?.cancel()
        callJob = null
        callControlScope = null
        currentCallerId = null
        callWasAnswered = false
        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (e: Exception) {
            Log.w(TAG, "📞 resetCallState stopForeground: ${e.message}")
        }
    }

    private fun sendDeclineHttp(callerId: String, noAnswer: Boolean = false) {
        val baseUrl = resolveBaseUrl()
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val declinerId = prefs.getString(KEY_DECLINER_ID, null).orEmpty()
        val callRecordId = prefs.getString(KEY_CALL_RECORD_ID, null).orEmpty()
        if (callerId.isBlank() && callRecordId.isBlank()) {
            Log.w(TAG, "📞 Decline HTTP skipped — no callerId/callRecordId")
            return
        }
        Log.i(
            TAG,
            "📞 Sending decline HTTP for callerId=$callerId callRecordId=$callRecordId noAnswer=$noAnswer to $baseUrl",
        )

        repeat(3) { attempt ->
            try {
                val url = URL("$baseUrl/call-history/decline")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.doOutput = true
                conn.connectTimeout = 10000
                conn.readTimeout = 10000

                val body = buildString {
                    append("{\"callerId\":\"$callerId\"")
                    if (declinerId.isNotBlank()) {
                        append(",\"declinerId\":\"$declinerId\"")
                    }
                    if (callRecordId.isNotBlank()) {
                        append(",\"callRecordId\":\"$callRecordId\"")
                    }
                    if (noAnswer) {
                        append(",\"noAnswer\":true")
                    }
                    append("}")
                }
                OutputStreamWriter(conn.outputStream, "UTF-8").use { it.write(body) }

                val code = conn.responseCode
                conn.disconnect()

                Log.i(TAG, "📞 Decline HTTP response: $code (attempt $attempt)")
                if (code in 200..299) return // Success!
            } catch (e: Exception) {
                Log.e(TAG, "📞 Decline HTTP attempt $attempt failed: ${e.message}")
                if (attempt < 2) Thread.sleep(2000)
            }
        }
        Log.e(TAG, "📞 All decline HTTP attempts failed")
    }

    private fun resolveBaseUrl(): String {
        return try {
            val prefs: SharedPreferences =
                getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            prefs.getString(KEY_API_BASE_URL, null)
                ?.takeIf { it.isNotBlank() } ?: FALLBACK_URL
        } catch (_: Exception) {
            FALLBACK_URL
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Active Call",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "Required for call management; CallKit shows the visible call UI"
                setShowBadge(false)
                setSound(null, null)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildForegroundNotification(callerName: String): Notification {
        // Short-lived: dismissed on accept/connected/end. CallKit shows the real call UI.
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(callerName.ifBlank { "Call" })
            .setContentText("Connecting…")
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setSilent(true)
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        super.onDestroy()
        callScope?.cancel()
        callScope = null
        Log.i(TAG, "📞 IncomingCallService destroyed")
    }
}
