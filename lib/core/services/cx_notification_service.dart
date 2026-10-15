import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../api/api_client.dart';
import '../storage/secure_storage.dart';
import '../../firebase_options.dart';
import '../../app/router.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
}

class CxNotificationService {
  static const MethodChannel _nativeChannel = MethodChannel(
    'online.codexa/notifications',
  );

  /// Callback hook invoked when shared data arrives from Android Sharesheet
  static void Function(Map<String, dynamic> shareData)? onIncomingShareReceived;

  static bool _initialized = false;

  /// Callback hook invoked when a chat message arrives in foreground
  static void Function(String? conversationId)? onForegroundChatMessageReceived;

  /// Tracks currently viewed conversation ID for smart notification suppression
  static String? _activeConversationId;
  static String? get activeConversationId => _activeConversationId;

  /// Sets the currently active conversation and notifies backend presence
  static Future<void> setActiveConversation(String? convId) async {
    _activeConversationId = convId;
    if (kDebugMode) {
      debugPrint('[PUSH] Active conversation set to: $convId');
    }
    try {
      final token = await CxStorage.getToken();
      if (token != null && token.isNotEmpty) {
        final deviceId = await CxStorage.getOrCreateDeviceId();
        final api = CxApiClient();
        await api.dio.post(
          '/api/mobile/chat/presence',
          data: {
            'deviceId': deviceId,
            'conversationId': convId,
            'isActive': convId != null && convId.isNotEmpty,
          },
        );
      }
    } catch (_) {}
  }

  /// Callback hook invoked when a payment approval/event arrives
  static void Function(String? paymentId)? onPaymentNotificationReceived;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;

      // Request system notification permissions (Android 13+ / iOS)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (kDebugMode) {
        debugPrint(
          '[PUSH] Notification authorization status: ${settings.authorizationStatus}',
        );
      }

      // Fetch and persist initial FCM push token
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await CxStorage.saveFcmToken(token);
        if (kDebugMode) {
          debugPrint('[PUSH] FCM Token acquired: ${token.substring(0, 15)}...');
        }
        await syncFcmTokenWithBackend();
      }

      // Handle token rotation dynamically
      messaging.onTokenRefresh.listen((newToken) async {
        if (newToken.isNotEmpty) {
          await CxStorage.saveFcmToken(newToken);
          await syncFcmTokenWithBackend();
        }
      });

      // Foreground message listener: Show native notification banner and alert UI
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleForegroundMessage(message);
      });

      // Handle cold-start from notification click
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationClick(initialMessage);
      }

      // App opened from background notification click
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationClick(message);
      });

      // Native MethodChannel listener for intents tapped from Android notification shade
      _nativeChannel.setMethodCallHandler((call) async {
        if (call.method == 'onNotificationOpened') {
          final args = Map<String, dynamic>.from(call.arguments ?? {});
          final convId = args['conversationId']?.toString();
          final messageId = args['messageId']?.toString();
          final paymentId = args['paymentId']?.toString();
          if (convId != null && convId.isNotEmpty) {
            onForegroundChatMessageReceived?.call(convId);
            try {
              final query = (messageId != null && messageId.isNotEmpty)
                  ? '?messageId=$messageId'
                  : '';
              appRouter.push('/chat/$convId$query');
            } catch (_) {}
          } else if (paymentId != null && paymentId.isNotEmpty) {
            onPaymentNotificationReceived?.call(paymentId);
            try {
              appRouter.push('/payments?paymentId=$paymentId');
            } catch (_) {}
          }
        } else if (call.method == 'onSharedDataReceived') {
          final args = Map<String, dynamic>.from(call.arguments ?? {});
          onIncomingShareReceived?.call(args);
        }
      });

      // Check cold-start notification extra from native launch
      try {
        final launchData = await _nativeChannel
            .invokeMethod<Map<dynamic, dynamic>>('getLaunchNotification');
        if (launchData != null) {
          final convId = launchData['conversationId']?.toString();
          final messageId = launchData['messageId']?.toString();
          final paymentId = launchData['paymentId']?.toString();
          if (convId != null && convId.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 600), () {
              try {
                final query = (messageId != null && messageId.isNotEmpty)
                    ? '?messageId=$messageId'
                    : '';
                appRouter.push('/chat/$convId$query');
              } catch (_) {}
            });
          } else if (paymentId != null && paymentId.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 600), () {
              try {
                appRouter.push('/payments?paymentId=$paymentId');
              } catch (_) {}
            });
          }
        }

        // Check cold-start share data from Android Sharesheet
        final shareData = await _nativeChannel
            .invokeMethod<Map<dynamic, dynamic>>('getLaunchShareData');
        if (shareData != null) {
          final mapped = Map<String, dynamic>.from(shareData);
          Future.delayed(const Duration(milliseconds: 800), () {
            onIncomingShareReceived?.call(mapped);
          });
        }
      } catch (_) {}
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PUSH] Initialization warning: $e');
      }
    }
  }

  static void _handleNotificationClick(RemoteMessage message) {
    final convId = message.data['conversationId']?.toString();
    final messageId = message.data['messageId']?.toString();
    if (convId != null && convId.isNotEmpty) {
      onForegroundChatMessageReceived?.call(convId);
      try {
        final query = (messageId != null && messageId.isNotEmpty)
            ? '?messageId=$messageId'
            : '';
        appRouter.push('/chat/$convId$query');
      } catch (_) {}
    }

    final paymentId = message.data['paymentId']?.toString();
    if (paymentId != null && paymentId.isNotEmpty) {
      onPaymentNotificationReceived?.call(paymentId);
      try {
        appRouter.push('/payments?paymentId=$paymentId');
      } catch (_) {}
    }
  }

  /// Displays native system notification banner with sound when app is in foreground,
  /// unless the user is actively viewing this exact conversation.
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    try {
      final title =
          message.notification?.title ??
          message.data['senderName'] ??
          message.data['title'] ??
          'CodeXa Notification';

      final body =
          message.notification?.body ??
          message.data['message'] ??
          message.data['body'] ??
          'New notification received';

      final conversationId = message.data['conversationId']?.toString();
      final messageId = message.data['messageId']?.toString();
      final paymentId = message.data['paymentId']?.toString();
      final mediaUrl = message.data['mediaUrl']?.toString();
      final stickerId = message.data['stickerId']?.toString();
      final messageType = message.data['messageType']?.toString();
      final senderName = message.data['senderName']?.toString();
      final senderAvatar = message.data['senderAvatar']?.toString();
      final isGroup = message.data['isGroup']?.toString();
      final groupName = message.data['groupName']?.toString();

      // Notify active listeners first (so open chat views and inbox lists refresh immediately)
      if (conversationId != null && conversationId.isNotEmpty) {
        onForegroundChatMessageReceived?.call(conversationId);
      }
      if (paymentId != null && paymentId.isNotEmpty) {
        onPaymentNotificationReceived?.call(paymentId);
      }

      // CRITICAL FIX: SMART FOREGROUND NOTIFICATION SUPPRESSION
      // When the user is actively viewing the exact conversation that receives a new message,
      // suppress duplicate system notification banner, sounds, and vibrations on this device!
      if (conversationId != null &&
          _activeConversationId != null &&
          _activeConversationId == conversationId) {
        if (kDebugMode) {
          debugPrint(
            '[PUSH] Suppressed duplicate foreground notification for active chat: $conversationId',
          );
        }
        return;
      }

      // Trigger native Android status-bar notification banner via MainActivity with actions & rich media
      await _nativeChannel.invokeMethod('showNotification', {
        'title': title,
        'body': body,
        'conversationId': conversationId,
        'messageId': messageId,
        'paymentId': paymentId,
        'mediaUrl': mediaUrl,
        'stickerId': stickerId,
        'messageType': messageType,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'isGroup': isGroup,
        'groupName': groupName,
      });
    } catch (err) {
      if (kDebugMode) {
        debugPrint('[PUSH] Foreground notification display error: $err');
      }
    }
  }

  /// Authoritatively registers the device push token with the active user session
  static Future<void> syncFcmTokenWithBackend() async {
    try {
      final authToken = await CxStorage.getToken();
      if (authToken == null || authToken.isEmpty) {
        // User not logged in yet; registration will happen upon login
        return;
      }

      String? fcmToken = await CxStorage.getFcmToken();
      if (fcmToken == null || fcmToken.isEmpty) {
        fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await CxStorage.saveFcmToken(fcmToken);
        }
      }

      if (fcmToken == null || fcmToken.isEmpty) return;

      final deviceId = await CxStorage.getOrCreateDeviceId();
      final api = CxApiClient();

      final res = await api.dio.post(
        '/api/mobile/devices',
        data: {
          'deviceId': deviceId,
          'fcmToken': fcmToken,
          'platform': 'ANDROID',
          'appVersion': '1.0.0',
        },
      );

      if (kDebugMode) {
        debugPrint('[PUSH] Device push token synced: ${res.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PUSH] Push token sync notice: $e');
      }
    }
  }
}
