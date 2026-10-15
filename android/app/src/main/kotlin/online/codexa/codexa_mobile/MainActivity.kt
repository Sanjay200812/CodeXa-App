package online.codexa.codexa_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput
import android.content.pm.PackageManager
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : FlutterActivity() {
    private val CHANNEL = "online.codexa/notifications"
    private var methodChannel: MethodChannel? = null
    private var pendingLaunchNotification: Map<String, String>? = null
    private var pendingLaunchShareData: Map<String, Any>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
        extractNotificationExtras(intent)
        extractShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractNotificationExtras(intent)
        extractShareIntent(intent)
        dispatchPendingNotification()
        dispatchPendingShare()
    }

    private fun extractNotificationExtras(intent: Intent?) {
        if (intent == null) return
        val convId = intent.getStringExtra("conversationId")
        val messageId = intent.getStringExtra("messageId")
        val paymentId = intent.getStringExtra("paymentId")
        val storyId = intent.getStringExtra("storyId")
        if (!convId.isNullOrEmpty() || !paymentId.isNullOrEmpty() || !storyId.isNullOrEmpty()) {
            val map = mutableMapOf<String, String>()
            if (!convId.isNullOrEmpty()) map["conversationId"] = convId
            if (!messageId.isNullOrEmpty()) map["messageId"] = messageId
            if (!paymentId.isNullOrEmpty()) map["paymentId"] = paymentId
            if (!storyId.isNullOrEmpty()) map["storyId"] = storyId
            pendingLaunchNotification = map
        }
    }

    private fun extractShareIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val type = intent.type ?: ""

        if (Intent.ACTION_SEND == action) {
            val map = mutableMapOf<String, Any>()
            map["action"] = "SEND"
            map["mimeType"] = type

            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (!sharedText.isNullOrEmpty()) {
                map["text"] = sharedText
            }

            val streamUri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            if (streamUri != null) {
                map["uri"] = streamUri.toString()
            }

            if (map.containsKey("text") || map.containsKey("uri")) {
                pendingLaunchShareData = map
            }
        } else if (Intent.ACTION_SEND_MULTIPLE == action) {
            val map = mutableMapOf<String, Any>()
            map["action"] = "SEND_MULTIPLE"
            map["mimeType"] = type

            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (!sharedText.isNullOrEmpty()) {
                map["text"] = sharedText
            }

            val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            if (!uris.isNullOrEmpty()) {
                map["uris"] = uris.map { it.toString() }
            }

            if (map.containsKey("uris") || map.containsKey("text")) {
                pendingLaunchShareData = map
            }
        }
    }

    private fun dispatchPendingNotification() {
        val payload = pendingLaunchNotification ?: return
        methodChannel?.invokeMethod("onNotificationOpened", payload)
        pendingLaunchNotification = null
    }

    private fun dispatchPendingShare() {
        val payload = pendingLaunchShareData ?: return
        methodChannel?.invokeMethod("onSharedDataReceived", payload)
        pendingLaunchShareData = null
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "CodeXa Messages"
            val descriptionText = "Direct messages and team channel notifications"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel("codexa_messages_channel", name, importance).apply {
                description = descriptionText
                enableLights(true)
                enableVibration(true)
                setShowBadge(true)
                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .build()
                setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION), audioAttributes)
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getLaunchNotification" -> {
                    val payload = pendingLaunchNotification
                    pendingLaunchNotification = null
                    result.success(payload)
                }
                "getLaunchShareData" -> {
                    val payload = pendingLaunchShareData
                    pendingLaunchShareData = null
                    result.success(payload)
                }
                "showNotification" -> {
                    val title = call.argument<String>("title") ?: "CodeXa"
                    val body = call.argument<String>("body") ?: ""
                    val conversationId = call.argument<String>("conversationId")
                    val messageId = call.argument<String>("messageId")
                    val paymentId = call.argument<String>("paymentId")
                    val mediaUrl = call.argument<String>("mediaUrl")
                    val stickerId = call.argument<String>("stickerId")

                    val senderAvatar = call.argument<String>("senderAvatar")

                    val notifId = if (!conversationId.isNullOrEmpty()) {
                        conversationId.hashCode()
                    } else if (!paymentId.isNullOrEmpty()) {
                        paymentId.hashCode()
                    } else {
                        System.currentTimeMillis().toInt()
                    }

                    // Intent for tapping notification body
                    val openIntent = Intent(this, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("conversationId", conversationId)
                        putExtra("messageId", messageId)
                        putExtra("paymentId", paymentId)
                    }
                    val openPendingIntent = PendingIntent.getActivity(
                        this,
                        notifId,
                        openIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    val builder = NotificationCompat.Builder(this, "codexa_messages_channel")
                        .setSmallIcon(R.mipmap.ic_launcher)
                        .setContentTitle(title)
                        .setContentText(body)
                        .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                        .setPriority(NotificationCompat.PRIORITY_HIGH)
                        .setAutoCancel(true)
                        .setContentIntent(openPendingIntent)

                    // Add Notification Actions if it's a chat message
                    if (!conversationId.isNullOrEmpty()) {
                        // 1. ❤️ Like Action
                        if (!messageId.isNullOrEmpty()) {
                            val likeIntent = Intent(this, CxNotificationReplyReceiver::class.java).apply {
                                action = CxNotificationReplyReceiver.ACTION_LIKE_MESSAGE
                                putExtra(CxNotificationReplyReceiver.EXTRA_MESSAGE_ID, messageId)
                                putExtra(CxNotificationReplyReceiver.EXTRA_CONVERSATION_ID, conversationId)
                                putExtra(CxNotificationReplyReceiver.EXTRA_NOTIFICATION_ID, notifId)
                            }
                            val likePendingIntent = PendingIntent.getBroadcast(
                                this,
                                (notifId + 1),
                                likeIntent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )
                            val likeAction = NotificationCompat.Action.Builder(
                                android.R.drawable.btn_star,
                                "❤️ Like",
                                likePendingIntent
                            ).build()
                            builder.addAction(likeAction)
                        }

                        // 2. Direct Reply RemoteInput Action
                        val remoteInput = RemoteInput.Builder(CxNotificationReplyReceiver.KEY_TEXT_REPLY)
                            .setLabel("Reply...")
                            .build()

                        val replyIntent = Intent(this, CxNotificationReplyReceiver::class.java).apply {
                            action = CxNotificationReplyReceiver.ACTION_INLINE_REPLY
                            putExtra(CxNotificationReplyReceiver.EXTRA_CONVERSATION_ID, conversationId)
                            putExtra(CxNotificationReplyReceiver.EXTRA_NOTIFICATION_ID, notifId)
                        }

                        val replyPendingIntent = PendingIntent.getBroadcast(
                            this,
                            notifId,
                            replyIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                        )

                        val replyAction = NotificationCompat.Action.Builder(
                            android.R.drawable.ic_menu_send,
                            "Reply",
                            replyPendingIntent
                        )
                            .addRemoteInput(remoteInput)
                            .setAllowGeneratedReplies(true)
                            .build()

                        builder.addAction(replyAction)
                    }

                    // Add Review Action for Payment notifications
                    if (!paymentId.isNullOrEmpty()) {
                        val reviewAction = NotificationCompat.Action.Builder(
                            android.R.drawable.ic_menu_agenda,
                            "Review Payment",
                            openPendingIntent
                        ).build()

                        builder.addAction(reviewAction)
                    }

                    // Rich preview handling (Sticker or Image)
                    Thread {
                        var richBitmap: Bitmap? = null
                        try {
                            if (!stickerId.isNullOrEmpty()) {
                                // Try loading local sticker artwork from files
                                val appDocsDir = applicationContext.filesDir
                                val stickerFile = File(appDocsDir, "stickers/$stickerId.webp")
                                if (stickerFile.exists()) {
                                    richBitmap = BitmapFactory.decodeFile(stickerFile.absolutePath)
                                } else {
                                    // Try loading from bundled flutter assets
                                    try {
                                        val assetKey = "flutter_assets/assets/stickers/bundled/$stickerId.webp"
                                        val isStream = applicationContext.assets.open(assetKey)
                                        richBitmap = BitmapFactory.decodeStream(isStream)
                                        isStream.close()
                                    } catch (e: Exception) {}
                                }
                            } else if (!mediaUrl.isNullOrEmpty() && mediaUrl.startsWith("http")) {
                                val url = URL(mediaUrl)
                                val conn = url.openConnection() as HttpURLConnection
                                conn.connectTimeout = 3000
                                conn.readTimeout = 3000
                                conn.doInput = true
                                conn.connect()
                                val isStream: InputStream = conn.inputStream
                                richBitmap = BitmapFactory.decodeStream(isStream)
                                isStream.close()
                                conn.disconnect()
                            }
                            if (richBitmap == null && !senderAvatar.isNullOrEmpty() && senderAvatar.startsWith("http")) {
                                val url = URL(senderAvatar)
                                val conn = url.openConnection() as HttpURLConnection
                                conn.connectTimeout = 3000
                                conn.readTimeout = 3000
                                conn.doInput = true
                                conn.connect()
                                val isStream: InputStream = conn.inputStream
                                val avatarBmp = BitmapFactory.decodeStream(isStream)
                                isStream.close()
                                conn.disconnect()
                                if (avatarBmp != null) {
                                    builder.setLargeIcon(avatarBmp)
                                }
                            }
                        } catch (e: Exception) {
                            // Safe fallback to text style
                        }

                        if (richBitmap != null) {
                            builder.setLargeIcon(richBitmap)
                            builder.setStyle(
                                NotificationCompat.BigPictureStyle()
                                    .bigPicture(richBitmap)
                                    .setSummaryText(body)
                            )
                        }

                        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        notificationManager.notify(notifId, builder.build())
                    }.start()

                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // =========================================================================
        // CODEXA PACKAGE INSTALLER & UPDATE MANAGEMENT CHANNEL
        // =========================================================================
        val installerChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "online.codexa/package_installer")
        installerChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestPackageInstalls" -> {
                    val canInstall = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        packageManager.canRequestPackageInstalls()
                    } else {
                        true
                    }
                    result.success(canInstall)
                }
                "openInstallPermissionSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "getPackageInfo" -> {
                    try {
                        val pInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
                        } else {
                            packageManager.getPackageInfo(packageName, 0)
                        }
                        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            pInfo.longVersionCode
                        } else {
                            pInfo.versionCode.toLong()
                        }
                        val map = mapOf(
                            "packageName" to pInfo.packageName,
                            "versionName" to (pInfo.versionName ?: ""),
                            "versionCode" to versionCode,
                            "firstInstallTime" to pInfo.firstInstallTime,
                            "lastUpdateTime" to pInfo.lastUpdateTime
                        )
                        result.success(map)
                    } catch (e: Exception) {
                        result.error("PACKAGE_INFO_ERROR", e.message, null)
                    }
                }
                "verifyApkCompatibility" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "File path cannot be empty", null)
                        return@setMethodCallHandler
                    }
                    val file = File(filePath)
                    if (!file.exists() || !file.canRead()) {
                        result.error("FILE_NOT_FOUND", "APK file does not exist or cannot be read", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val archiveInfo = packageManager.getPackageArchiveInfo(filePath, 0)
                        if (archiveInfo == null) {
                            result.success(mapOf(
                                "compatible" to false,
                                "error" to "Unable to parse APK manifest. Corrupt or invalid package."
                            ))
                            return@setMethodCallHandler
                        }
                        val archivePackageName = archiveInfo.packageName
                        val archiveVersionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            archiveInfo.longVersionCode
                        } else {
                            archiveInfo.versionCode.toLong()
                        }
                        val archiveVersionName = archiveInfo.versionName ?: ""
                        val matchesSelf = (archivePackageName == packageName)

                        result.success(mapOf(
                            "compatible" to matchesSelf,
                            "archivePackageName" to archivePackageName,
                            "currentPackageName" to packageName,
                            "archiveVersionCode" to archiveVersionCode,
                            "archiveVersionName" to archiveVersionName,
                            "fileSizeBytes" to file.length()
                        ))
                    } catch (e: Exception) {
                        result.error("VERIFY_ERROR", e.message, null)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "APK path cannot be empty", null)
                        return@setMethodCallHandler
                    }
                    val file = File(filePath)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "APK file does not exist at $filePath", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val apkUri = FileProvider.getUriForFile(
                            applicationContext,
                            "${applicationContext.packageName}.fileprovider",
                            file
                        )

                        val installIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }

                        startActivity(installIntent)
                        result.success(mapOf(
                            "initiated" to true,
                            "packageName" to packageName,
                            "filePath" to filePath
                        ))
                    } catch (e: Exception) {
                        result.error("INSTALL_LAUNCH_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        dispatchPendingNotification()
        dispatchPendingShare()
    }
}
