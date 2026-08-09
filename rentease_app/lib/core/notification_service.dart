import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Call once from main() after Firebase.initializeApp().
/// Only sets up listeners — does NOT send token to backend (no JWT yet).
Future<void> initNotifications() async {
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Refresh token when it changes (only sends if user is logged in)
  messaging.onTokenRefresh.listen((newToken) async {
    await _sendTokenToBackend(newToken);
  });

  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    debugPrint('Notification opened: ${message.notification?.title}');
  });

  FirebaseMessaging.onMessage.listen((message) {
    debugPrint('Foreground notification: ${message.notification?.title}');
  });
}

/// Call this right after a successful login so the JWT is already stored.
Future<void> registerFCMTokenAfterLogin() async {
  final messaging = FirebaseMessaging.instance;
  await _registerToken(messaging);
}

Future<void> _registerToken(FirebaseMessaging messaging) async {
  try {
    final token = await messaging.getToken();
    if (token != null) {
      await _sendTokenToBackend(token);
    }
  } catch (e) {
    debugPrint('FCM token registration failed: $e');
  }
}

Future<void> _sendTokenToBackend(String token) async {
  try {
    await apiClient.post(
      '/api/v1/auth/fcm-token/',
      data: {'token': token},
    );
    debugPrint('FCM token saved to backend.');
  } catch (e) {
    debugPrint('Failed to save FCM token: $e');
  }
}
