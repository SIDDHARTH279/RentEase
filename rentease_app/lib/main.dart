import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rentease_app/core/router.dart';
import 'core/notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Converts app deep links into in-app routes.
String? routeFromDeepLink(Uri uri) {
  if (uri.scheme != 'rentease') return null;

  // rentease://login?invite_token=xxx
  if (uri.host == 'login') {
    final invite = uri.queryParameters['invite_token'];
    if (invite != null && invite.isNotEmpty) {
      return '/login?invite_token=$invite';
    }
    return '/login';
  }

  // Legacy: rentease://accept-invite?token=xxx → login with invite
  final isInviteHost = uri.host == 'accept-invite';
  final isInvitePath =
      uri.path == '/accept-invite' || uri.path.endsWith('accept-invite');
  if (isInviteHost || isInvitePath) {
    final token =
        uri.queryParameters['token'] ?? uri.queryParameters['invite_token'];
    if (token != null && token.isNotEmpty) {
      return '/login?invite_token=$token';
    }
  }
  return null;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await initNotifications();
  await GoogleSignIn.instance.initialize(
    serverClientId:
        '295375781024-ssdrf9722c00q72moj89g5r9tdpug5ic.apps.googleusercontent.com',
  );

  final appLinks = AppLinks();
  final initialLink = await appLinks.getInitialLink();
  final initialRoute =
      initialLink != null ? routeFromDeepLink(initialLink) : null;

  runApp(
    ProviderScope(
      child: RentLedgerApp(initialRoute: initialRoute),
    ),
  );
}

class RentLedgerApp extends StatefulWidget {
  final String? initialRoute;
  const RentLedgerApp({super.key, this.initialRoute});

  @override
  State<RentLedgerApp> createState() => _RentLedgerAppState();
}

class _RentLedgerAppState extends State<RentLedgerApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(initialRoute: widget.initialRoute);

    AppLinks().uriLinkStream.listen((uri) {
      final route = routeFromDeepLink(uri);
      if (route != null) {
        _router.go(route);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RentEase',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
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
