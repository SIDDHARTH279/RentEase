import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rentease_app/core/router.dart';
import 'core/notification_service.dart';

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await initNotifications();
  // Initialize Google Sign-In (v7 requires explicit init)
  await GoogleSignIn.instance.initialize(
    // serverClientId is your OAuth2 Web client ID from Google Cloud Console
    // Replace with your actual web client ID
    serverClientId: '295375781024-ssdrf9722c00q72moj89g5r9tdpug5ic.apps.googleusercontent.com',
  );

  runApp(
    const ProviderScope(
      child: RentLedgerApp(),
    ),
  );
}

class RentLedgerApp extends StatelessWidget {
  const RentLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RentEase',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A3C6E),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
    );
  }
}
