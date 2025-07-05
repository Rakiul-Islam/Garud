import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;

class FCMService {
  static const _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  Future<String> _getAccessToken() async {
    final serviceAccountJson =
        await rootBundle.loadString('assets/service_account.json');
    final credentials =
        auth.ServiceAccountCredentials.fromJson(json.decode(serviceAccountJson));
    final client = await auth.clientViaServiceAccount(credentials, _scopes);
    final accessToken = client.credentials.accessToken.data;
    client.close();
    return accessToken;
  }

  Future<void> sendNotification({
    required String targetToken,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final accessToken = await _getAccessToken();
    final url =
        'https://fcm.googleapis.com/v1/projects/garud-21e17/messages:send';

    final message = {
      'message': {
        'token': targetToken,
        'notification': {'title': title, 'body': body},
        'data': data,
      }
    };

    final response = await http.post(Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(message));

    if (response.statusCode == 200) {
      print('Notification sent successfully');
    } else {
      print('Failed to send notification: ${response.statusCode}');
      print('Response body: ${response.body}');
    }
  }
}