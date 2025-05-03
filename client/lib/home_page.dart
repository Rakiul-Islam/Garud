import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'fcm_service.dart';
import 'main.dart';
import 'notification_service.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _recipientUidController = TextEditingController();
  final _messageController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _fcmService = FCMService(); // Add this line to create an instance of FCMService

  @override
  void initState() {
    super.initState();

    // Request notification permissions (especially important for iOS)
    FirebaseMessaging.instance.requestPermission();

    // Listen for messages when the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📬 Received a message in the foreground!');
      print('------------------------------------------');
      if (message.notification != null) {
        print('🔔 Notification Title: ${message.notification!.title}');
        print('📝 Notification Body: ${message.notification!.body}');
        
        // Show a snackbar with the notification content
        String notificationText = message.notification!.body ?? 'New message received';
        showGlobalSnackBar('📩 $notificationText');
        
        // Show a push notification
        NotificationService.showNotification(
          message.notification!.title,
          message.notification!.body,
          message.data['senderUid'],
        );
      }
      if (message.data.isNotEmpty) {
        print('📦 Data Payload: ${message.data}');
        message.data.forEach((key, value) {
          print('   $key: $value');
        });
        
        // If there's no notification but there's a message in data, show that
        if (message.notification == null && message.data.containsKey('message')) {
          showGlobalSnackBar('📩 ${message.data['message']}');
          
          // Show a push notification for data-only messages
          NotificationService.showNotification(
            'New Message',
            message.data['message'],
            message.data['senderUid'],
          );
        }
      }
      print('------------------------------------------');
    });

    // Handle notifications opened when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🚀 App opened from background by notification tap!');
      print('------------------------------------------');
      if (message.notification != null) {
        print('🔔 Background Notification Title: ${message.notification!.title}');
        print('📝 Background Notification Body: ${message.notification!.body}');
      }
      if (message.data.isNotEmpty) {
        print('📦 Background Data Payload: ${message.data}');
        message.data.forEach((key, value) {
          print('   $key: $value');
        });
      }
      print('------------------------------------------');
    });

    // Check if app was opened from a notification (when terminated)
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('📱 App launched from terminated state by notification!');
        print('------------------------------------------');
        if (message.notification != null) {
          print('🔔 Initial Notification Title: ${message.notification!.title}');
          print('📝 Initial Notification Body: ${message.notification!.body}');
        }
        if (message.data.isNotEmpty) {
          print('📦 Initial Data Payload: ${message.data}');
          message.data.forEach((key, value) {
            print('   $key: $value');
          });
        }
        print('------------------------------------------');
      }
    });
  }

  void _sendMessage() async {
    String recipientUid = _recipientUidController.text.trim();
    String message = _messageController.text.trim();

    try {
      // Retrieve the recipient's device token from Firestore
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientUid)
          .get();

      if (doc.exists && doc['token'] != null) {
        String recipientToken = doc['token'];

        // Actually send the notification using FCMService
        await _fcmService.sendNotification(
          targetToken: recipientToken,
          title: 'New Message from ${_auth.currentUser?.displayName ?? 'User'}',
          body: message,
        );

        // Also store the message in Firestore (optional - for chat history)
        await FirebaseFirestore.instance.collection('messages').add({
          'sender': _auth.currentUser!.uid,
          'recipient': recipientUid,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Clear the message field after sending
        _messageController.clear();

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Message sent')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recipient token not found')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Home')),
        body: Padding(
            padding: EdgeInsets.all(16),
            child: Column(children: [
              TextField(
                  controller: _recipientUidController,
                  decoration: InputDecoration(labelText: 'Recipient UID')),
              TextField(
                  controller: _messageController,
                  decoration: InputDecoration(labelText: 'Message')),
              SizedBox(height: 20),
              ElevatedButton(onPressed: _sendMessage, child: Text('Send'))
            ])));
  }
}
