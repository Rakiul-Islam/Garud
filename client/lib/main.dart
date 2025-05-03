import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:garudclient/firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'login_page.dart';
import 'notification_service.dart';

// Global key to access the scaffold state from anywhere in the app
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = 
    GlobalKey<ScaffoldMessengerState>();

// This is the background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Need to ensure Firebase is initialized here too
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.handleBackgroundMessage(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize notification service
  await NotificationService.initialize();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FCM Messaging App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      home: LoginPage(),
    );
  }
}

// A helper function to show snackbars from anywhere in the app
void showGlobalSnackBar(String message, {Duration duration = const Duration(seconds: 4)}) {
  rootScaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(bottom: 10.0, left: 10.0, right: 10.0),
    ),
  );
}
