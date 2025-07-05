import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:garudclient/screens/guardians_page.dart';
import 'package:garudclient/screens/notifications_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:garudclient/blocs/auth/auth_bloc.dart';
import 'package:garudclient/blocs/auth/auth_state.dart';
import 'package:garudclient/screens/home_page.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static final AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description:
        'This channel is used for important notifications.', // description
    importance: Importance.high,
    playSound: true,
  );

  static Future<void> initialize(BuildContext context) async {
    if (kIsWeb) return;

    // Request notification permissions
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) async {
        print('Notification tapped: ${details.payload}');
        // Optional: Handle notification tap here too if needed
      },
    );

    // Create notification channel for Android
    if (!kIsWeb && Platform.isAndroid) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // Show notifications when in foreground
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground message listener
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle tap when app is in background or resumed
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _handleMessageOpenedApp(message, context),
    );

    // Handle tap when app was killed
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage, context);
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print("Got a message whilst in the foreground!");
    print("Message data: ${message.data}");

    if (message.notification != null) {
      await showNotification(
        message.notification?.title,
        message.notification?.body,
        message.data['payload'],
      );
    }
  }

  @pragma('vm:entry-point')
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    print("Handling a background message: ${message.messageId}");

    if (message.notification != null) {
      await showNotification(
        message.notification?.title,
        message.notification?.body,
        message.data['payload'],
      );
    }
  }

  static void _handleMessageOpenedApp(
      RemoteMessage message, BuildContext context) {
    print("Message opened app: ${message.data}");

    // Get the message_type from the data
    final messageType = message.data['type'];

    if (messageType != null) {
      switch (messageType) {
        case 'guardian_related':
          // Navigate to threat screen or handle accordingly
          print("Handle guardian flow");
          final authState = BlocProvider.of<AuthBloc>(context).state;
          if (authState is AuthSuccess) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HomePage(user: authState.user, selectedIndex: 1,)),
            );
          }
          break;
        case 'protege_related':
          // Navigate to threat screen or handle accordingly
          print("Handle protege flow");
          final authState = BlocProvider.of<AuthBloc>(context).state;
          if (authState is AuthSuccess) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HomePage(user: authState.user, selectedIndex: 2,)),
            );
          }
          break;
        case 'threat_related':
          // Navigate to guardian request screen or handle accordingly
          print("Handle threat flow");
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NotificationsPage()),
          );
          break;
        default:
          print("Unknown message type: $messageType");
          final authState = BlocProvider.of<AuthBloc>(context).state;
          if (authState is AuthSuccess) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HomePage(user: authState.user)),
            );
          }
      }
    }
  }

  static Future<void> showNotification(
    String? title,
    String? body,
    String? payload,
  ) async {
    if (kIsWeb) return;

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond,
      title ?? 'Notification',
      body ?? 'No message body',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }
}
