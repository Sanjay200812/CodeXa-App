package online.codexa.codexa_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.RemoteInput
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import org.json.JSONObject

class CxNotificationReplyReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_INLINE_REPLY = "online.codexa.ACTION_INLINE_REPLY"
        const val ACTION_LIKE_MESSAGE = "online.codexa.ACTION_LIKE_MESSAGE"
        const val KEY_TEXT_REPLY = "key_text_reply"
        const val EXTRA_CONVERSATION_ID = "extra_conversation_id"
        const val EXTRA_MESSAGE_ID = "extra_message_id"
        const val EXTRA_NOTIFICATION_ID = "extra_notification_id"
        const val CHANNEL_ID = "codexa_messages_channel"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val conversationId = intent.getStringExtra(EXTRA_CONVERSATION_ID) ?: ""
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, conversationId.hashCode())
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Ensure notification channel exists
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "CodeXa Messages",
                NotificationManager.IMPORTANCE_HIGH
            )
            notificationManager.createNotificationChannel(channel)
        }

        // Read stored auth token from SharedPreferences
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val token = prefs.getString("flutter.cxa_access_token", null)

        when (action) {
            ACTION_LIKE_MESSAGE -> {
                val messageId = intent.getStringExtra(EXTRA_MESSAGE_ID) ?: return
                if (messageId.isEmpty()) return

                // Show feedback in notification shade
                val likedNotification = NotificationCompat.Builder(context, CHANNEL_ID)
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentTitle("CodeXa Message")
                    .setContentText("❤️ Liked message")
                    .setAutoCancel(true)
                    .setTimeoutAfter(2500)
                    .build()
                notificationManager.notify(notificationId, likedNotification)

                // Dispatch reaction asynchronously to CodeXa API
                Thread {
                    try {
                        val url = URL("https://codxa-agency.online/api/chat/messages/$messageId/reactions")
                        val conn = url.openConnection() as HttpURLConnection
                        conn.requestMethod = "POST"
                        conn.setRequestProperty("Content-Type", "application/json; charset=UTF-8")
                        if (!token.isNullOrEmpty()) {
                            conn.setRequestProperty("Authorization", "Bearer $token")
                        }
                        conn.doOutput = true

                        val payload = JSONObject().apply {
                            put("reaction", "❤️")
                            put("emoji", "❤️")
                        }

                        val os = conn.outputStream
                        val writer = OutputStreamWriter(os, "UTF-8")
                        writer.write(payload.toString())
                        writer.flush()
                        writer.close()
                        os.close()

                        val code = conn.responseCode
                        conn.disconnect()
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }.start()
            }

            ACTION_INLINE_REPLY -> {
                val remoteInput = RemoteInput.getResultsFromIntent(intent) ?: return
                val replyText = remoteInput.getCharSequence(KEY_TEXT_REPLY)?.toString()?.trim() ?: return
                if (replyText.isEmpty()) return
                if (conversationId.isEmpty()) return

                // Show sending feedback
                val sendingNotification = NotificationCompat.Builder(context, CHANNEL_ID)
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentTitle("CodeXa Message")
                    .setContentText("Sending: $replyText")
                    .setProgress(0, 0, true)
                    .setAutoCancel(false)
                    .build()
                notificationManager.notify(notificationId, sendingNotification)

                // Dispatch reply asynchronously
                Thread {
                    try {
                        val url = URL("https://codxa-agency.online/api/chat/messages")
                        val conn = url.openConnection() as HttpURLConnection
                        conn.requestMethod = "POST"
                        conn.setRequestProperty("Content-Type", "application/json; charset=UTF-8")
                        if (!token.isNullOrEmpty()) {
                            conn.setRequestProperty("Authorization", "Bearer $token")
                        }
                        conn.doOutput = true

                        val payload = JSONObject().apply {
                            put("conversationId", conversationId)
                            put("message", replyText)
                            put("text", replyText)
                            put("clientId", UUID.randomUUID().toString())
                            put("clientMessageId", UUID.randomUUID().toString())
                        }

                        val os = conn.outputStream
                        val writer = OutputStreamWriter(os, "UTF-8")
                        writer.write(payload.toString())
                        writer.flush()
                        writer.close()
                        os.close()

                        val responseCode = conn.responseCode
                        if (responseCode in 200..299) {
                            val openIntent = Intent(context, MainActivity::class.java).apply {
                                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                                putExtra("conversationId", conversationId)
                            }
                            val openPendingIntent = PendingIntent.getActivity(
                                context,
                                notificationId,
                                openIntent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )

                            val successNotification = NotificationCompat.Builder(context, CHANNEL_ID)
                                .setSmallIcon(R.mipmap.ic_launcher)
                                .setContentTitle("CodeXa Message")
                                .setContentText("Replied: $replyText")
                                .setContentIntent(openPendingIntent)
                                .setAutoCancel(true)
                                .setTimeoutAfter(3500)
                                .build()
                            notificationManager.notify(notificationId, successNotification)
                        } else {
                            val errorNotification = NotificationCompat.Builder(context, CHANNEL_ID)
                                .setSmallIcon(R.mipmap.ic_launcher)
                                .setContentTitle("Could not send reply")
                                .setContentText("Open CodeXa to sign in again.")
                                .setAutoCancel(true)
                                .build()
                            notificationManager.notify(notificationId, errorNotification)
                        }
                        conn.disconnect()
                    } catch (e: Exception) {
                        val errorNotification = NotificationCompat.Builder(context, CHANNEL_ID)
                            .setSmallIcon(R.mipmap.ic_launcher)
                            .setContentTitle("Could not send reply")
                            .setContentText("Network error. Tap to open CodeXa.")
                            .setAutoCancel(true)
                            .build()
                        notificationManager.notify(notificationId, errorNotification)
                    }
                }.start()
            }
        }
    }
}
