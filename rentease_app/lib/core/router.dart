import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/owner/home/owner_home_screen.dart';
import '../features/owner/billing/owner_billing_screen.dart';
import '../features/tenant/home/tenant_home_screen.dart';
import '../features/tenant/billing/tenant_billing_screen.dart';
import '../features/tenant/issues/tenant_issues_screen.dart';
import 'api_client.dart';

final _storage = const FlutterSecureStorage();

final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (BuildContext context, GoRouterState state) async {
    final token = await _storage.read(key: accessTokenKey);
    final role = await _storage.read(key: 'user_role');
    final location = state.matchedLocation;

    // no token → go to login
    if (token == null) {
      return location == '/login' ? null : '/login';
    }

    // has token + trying to go to login → redirect by role
    if (location == '/login') {
      return role == 'tenant' ? '/tenant/home' : '/owner/home';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/owner/home',
      name: 'owner-home',
      builder: (context, state) => const OwnerHomeScreen(),
    ),
    GoRoute(
      path: '/tenant/home',
      name: 'tenant-home',
      builder: (context, state) => const TenantHomeScreen(),
    ),
    GoRoute(
      path: '/tenant/billing',
      name: 'tenant-billing',
      builder: (context, state) => const TenantBillingScreen(),
    ),
    GoRoute(
      path: '/owner/billing',
      name: 'owner-billing',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return OwnerBillingScreen(
          leaseId: extra['leaseId'] as int,
          unitNumber: extra['unitNumber'] as String,
        );
      },
    ),
    GoRoute(
      path: '/tenant/issues',
      name: 'tenant-issues',
      builder: (context, state) => const TenantIssuesScreen(),
    ),
  ],
);
