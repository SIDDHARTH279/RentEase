import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/login_screen.dart';
import '../features/owner/home/owner_home_screen.dart';
import 'api_client.dart';


final _storage = FlutterSecureStorage();

final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (BuildContext context, GoRouterState state) async{
    final token = await _storage.read(key: accessTokenKey);
    final isGoingToLogin = state.matchedLocation == '/login';

    if(token == null && !isGoingToLogin) return '/login';
    if(token != null && isGoingToLogin) return '/home';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      name: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => OwnerHomeScreen(),
    ),

  ],
);