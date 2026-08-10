import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/accept_invite_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/owner/home/owner_home_screen.dart';
import '../features/owner/billing/owner_billing_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/tenant/home/tenant_home_screen.dart';
import '../features/tenant/billing/tenant_billing_screen.dart';
import '../features/tenant/issues/tenant_issues_screen.dart';
import 'api_client.dart';

final _storage = const FlutterSecureStorage();

// Called from main.dart so deep link initial route can be passed in
GoRouter buildRouter({String? initialRoute}) => GoRouter(
  initialLocation: initialRoute ?? '/login',
  redirect: (BuildContext context, GoRouterState state) async {
    final token = await _storage.read(key: accessTokenKey);
    final role = await _storage.read(key: 'user_role');
    final location = state.matchedLocation;

    // no token → go to login (but allow accept-invite without token)
    if (token == null) {
      if (location == '/login' ||
          location.startsWith('/accept-invite') ||
          location == '/profile') {
        return location == '/profile' ? '/login' : null;
      }
      return '/login';
    }

    // already logged in → skip login (unless joining via invite link)
    if (location == '/login') {
      final hasInvite = state.uri.queryParameters['invite_token'] != null;
      if (hasInvite) return null;
      return role == 'tenant' ? '/tenant/home' : '/owner/home';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) {
        final inviteToken = state.uri.queryParameters['invite_token'];
        return LoginScreen(inviteToken: inviteToken);
      },
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
    GoRoute(
      path: '/accept-invite',
      name: 'accept-invite',
      builder: (context, state) {
        final token = state.uri.queryParameters['token'];
        return AcceptInviteScreen(prefillToken: token);
      },
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) {
        final requireComplete =
            state.uri.queryParameters['complete'] == '1';
        return EditProfileScreen(requireComplete: requireComplete);
      },
    ),
  ],
);
