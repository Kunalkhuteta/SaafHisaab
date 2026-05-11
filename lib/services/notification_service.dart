import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.initialize();
  await NotificationService.showLocalNotification(
    title: message.notification?.title ?? 'SaafHisaab',
    body: message.notification?.body ?? '',
  );
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'saafhisaab_channel',
    'SaafHisaab Notifications',
    description: 'Stock alerts, udhar reminders, daily summary',
    importance: Importance.high,
    playSound: true,
  );

  static Future<void> initialize() async {
    // ✅ Skip notifications on web — only works on Android
    if (kIsWeb) return;

    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettings = InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        showLocalNotification(
          title: message.notification?.title ?? 'SaafHisaab',
          body: message.notification?.body ?? '',
        );
      });

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Notification init error: $e');
    }
  }

  static Future<String?> getDeviceToken() async {
    if (kIsWeb) return null; // No tokens on web
    try {
      final token = await _messaging.getToken();
      debugPrint('FCM Token: $token');
      return token;
    } catch (e) {
      debugPrint('FCM Token error: $e');
      return null;
    }
  }

  static Future<void> saveTokenToSupabase(String userId) async {
    if (kIsWeb) return; // Skip on web
    final token = await getDeviceToken();
    if (token == null) return;
    try {
      await Supabase.instance.client
          .from('shops')
          .update({'fcm_token': token})
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Token save error: $e');
    }
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: payload,
    );
  }

  static Future<void> showLowStockAlert(String itemName) async {
    await showLocalNotification(
      title: '⚠️ Low Stock Alert',
      body: '$itemName ka stock khatam hone wala hai',
      payload: 'low_stock',
    );
  }

  static Future<void> showDailySummary(double sales, int bills) async {
    await showLocalNotification(
      title: '📊 Aaj ka hisaab',
      body: 'Aaj ₹${sales.toStringAsFixed(0)} ki sale hui — $bills bills',
      payload: 'daily_summary',
    );
  }

  static Future<void> showUdharReminder(
    String customerName,
    double amount,
  ) async {
    await showLocalNotification(
      title: '💰 Udhar Reminder',
      body: '$customerName ka ₹${amount.toStringAsFixed(0)} baaki hai',
      payload: 'udhar_reminder',
    );
  }

  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }
}
