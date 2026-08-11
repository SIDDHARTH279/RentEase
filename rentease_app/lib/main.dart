import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rentease_app/core/deep_links.dart';
import 'package:rentease_app/core/router.dart';
import 'package:rentease_app/core/theme/app_theme.dart';
import 'package:rentease_app/core/theme/theme_controller.dart';
import 'core/notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await initNotifications();
  await ThemeController.instance.load();
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
      child: RentEaseApp(initialRoute: initialRoute),
    ),
  );
}

class RentEaseApp extends StatefulWidget {
  final String? initialRoute;
  const RentEaseApp({super.key, this.initialRoute});

  @override
  State<RentEaseApp> createState() => _RentEaseAppState();
}

class _RentEaseAppState extends State<RentEaseApp> {
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
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'RentEase',
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeController.instance.mode,
        );
      },
    );
  }
}
