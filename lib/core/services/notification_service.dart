import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level background message handler required by FirebaseMessaging.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM Background message received: ${message.messageId}');
  // Background FCM messages with 'notification' payload are automatically displayed
  // by Android/iOS system trays. For data-only messages, show local notification:
  if (message.notification == null && message.data.isNotEmpty) {
    await NotificationService.showNotificationFromRemoteMessage(message);
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'high_importance_channel';
  static const String channelName = 'Chat Notifications';
  static const String channelDescription =
      'High priority channel for chat and message alerts';

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesWatcher;
  String? _currentOpenChatId;
  bool _isInitialized = false;

  void setCurrentOpenChatId(String? chatId) {
    _currentOpenChatId = chatId;
  }

  Future<void> initialize({
    void Function(String chatId)? onNotificationTapped,
  }) async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Request notification permissions
    await _requestPermissions();

    // 2. Setup Local Notifications Channel & Settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty && onNotificationTapped != null) {
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            final chatId = data['chatId'] as String?;
            if (chatId != null && chatId.isNotEmpty) {
              onNotificationTapped(chatId);
            }
          } catch (_) {}
        }
      },
    );

    // Create High Importance Notification Channel on Android
    final androidChannel = const AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // 3. Setup Foreground Presentation Options for iOS
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 4. Save FCM Token for the signed-in user
    await updateFcmToken();
    _fcm.onTokenRefresh.listen((token) {
      _saveTokenToFirestore(token);
    });

    // 5. Handle FCM message states:
    // A) App opened from terminated / killed state via notification click
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      final chatId = initialMessage.data['chatId'] as String?;
      if (chatId != null && chatId.isNotEmpty && onNotificationTapped != null) {
        onNotificationTapped(chatId);
      }
    }

    // B) App opened from background state via notification click
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final chatId = message.data['chatId'] as String?;
      if (chatId != null && chatId.isNotEmpty && onNotificationTapped != null) {
        onNotificationTapped(chatId);
      }
    });

    // C) Foreground FCM messages (display custom heads-up notification)
    FirebaseMessaging.onMessage.listen((message) {
      final incomingChatId = message.data['chatId'] as String?;
      // If user is currently looking at this exact chat room, suppress banner
      if (_currentOpenChatId != null && _currentOpenChatId == incomingChatId) {
        return;
      }
      showNotificationFromRemoteMessage(message);
    });

    // 6. Real-time Firestore Foreground Listener:
    // Ensures instant notifications even when peer-to-peer sending on Firestore
    // without requiring an external Cloud Functions backend.
    _startFirestoreForegroundWatcher();
  }

  Future<void> _requestPermissions() async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('Notification permission status: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  Future<void> updateFcmToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving FCM token to user profile: $e');
    }
  }

  /// Listen for new messages in conversations where user is a participant while app is in foreground
  void _startFirestoreForegroundWatcher() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _messagesWatcher?.cancel();
      _messagesWatcher = null;

      if (user == null) return;

      final currentUid = user.uid;
      final startTime = Timestamp.now();

      // Listen to conversations collection for changes where current user is participant
      _messagesWatcher = FirebaseFirestore.instance
          .collection('conversations')
          .where('participantIds', arrayContains: currentUid)
          .snapshots()
          .listen((convSnapshot) {
        for (final docChange in convSnapshot.docChanges) {
          if (docChange.type == DocumentChangeType.modified ||
              docChange.type == DocumentChangeType.added) {
            final data = docChange.doc.data();
            if (data == null) continue;

            final lastSenderId = data['lastMessageSenderId'] as String?;
            final lastMsgTime = data['lastMessageAt'] as Timestamp?;
            final lastText = data['lastMessage'] as String?;
            final convId = docChange.doc.id;

            // Only notify if message was sent by the other user and is newer than session start
            if (lastSenderId != null &&
                lastSenderId != currentUid &&
                lastMsgTime != null &&
                lastMsgTime.compareTo(startTime) >= 0 &&
                lastText != null &&
                lastText.isNotEmpty) {
              // Suppress if the user currently has this conversation open
              if (_currentOpenChatId == convId) {
                continue;
              }

              // Extract sender name from participant metadata if available
              _showForegroundNotification(
                title: 'New message',
                body: lastText,
                chatId: convId,
              );
            }
          }
        }
      });
    });
  }

  Future<void> _showForegroundNotification({
    required String title,
    required String body,
    required String chatId,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = chatId.hashCode.abs() % 100000;
    final payload = jsonEncode({'chatId': chatId});

    await _localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  static Future<void> showNotificationFromRemoteMessage(
      RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'New message';
    final body = notification?.body ?? message.data['body'] ?? message.data['lastMessage'] ?? '';
    final chatId = message.data['chatId'] as String? ?? '';

    final localNotifications = FlutterLocalNotificationsPlugin();
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = chatId.isNotEmpty
        ? chatId.hashCode.abs() % 100000
        : DateTime.now().millisecondsSinceEpoch % 100000;

    await localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: jsonEncode({'chatId': chatId}),
    );
  }

  void dispose() {
    _messagesWatcher?.cancel();
    _isInitialized = false;
  }
}
