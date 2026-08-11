import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/accept_invite_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/activity/activity_screen.dart';
import '../features/chat/chat_list_screen.dart';
import '../features/documents/documents_screen.dart';
import '../features/owner/home/owner_home_screen.dart';
import '../features/owner/billing/owner_billing_screen.dart';
import '../features/owner/invite/invite_tenant_screen.dart';
import '../features/owner/expenses/owner_expenses_screen.dart';
import '../features/owner/payments/razorpay_settings_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/tenant/home/tenant_home_screen.dart';
import '../features/tenant/billing/tenant_billing_screen.dart';
import '../features/tenant/issues/tenant_issues_screen.dart';
import 'api_client.dart';
import 'deep_links.dart';

final _storage = const FlutterSecureStorage();

// Called from main.dart so deep link initial route can be passed in
GoRouter buildRouter({String? initialRoute}) => GoRouter(
  initialLocation: normalizeAppLocation(initialRoute),
  errorBuilder: (context, state) {
    // Recover invite deep links that GoRouter failed to match
    final recovered = normalizeAppLocation(state.uri.toString());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        GoRouter.of(context).go(recovered);
      }
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Color(0xFF1A3C6E))),
    );
  },
  redirect: (BuildContext context, GoRouterState state) async {
    final raw = state.uri.toString();

    // Platform handed us rentease://... as the location — rewrite it.
    if (state.uri.scheme == 'rentease' || raw.startsWith('rentease:')) {
      return normalizeAppLocation(raw);
    }

    final token = await _storage.read(key: accessTokenKey);
    final role = await _storage.read(key: 'user_role');
    final location = state.matchedLocation;

    if (location == '/') {
      if (token == null) return '/login';
      return role == 'tenant' ? '/tenant/home' : '/owner/home';
    }

    // no token → go to login (but allow accept-invite without token)
    if (token == null) {
      if (location == '/login' ||
          location == '/register' ||
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
      path: '/',
      redirect: (context, state) async {
        final token = await _storage.read(key: accessTokenKey);
        final role = await _storage.read(key: 'user_role');
        if (token == null) return '/login';
        return role == 'tenant' ? '/tenant/home' : '/owner/home';
      },
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) {
        final inviteToken = state.uri.queryParameters['invite_token'];
        return LoginScreen(inviteToken: inviteToken);
      },
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/documents',
      name: 'documents',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final role = extra?['isOwner'] as bool? ?? true;
        return DocumentsScreen(
          isOwner: role,
          unitId: extra?['unitId'] as int?,
          unitNumber: extra?['unitNumber'] as String?,
        );
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
    GoRoute(
      path: '/chat',
      name: 'chat',
      builder: (context, state) => const ChatListScreen(),
    ),
    GoRoute(
      path: '/invite-tenant',
      name: 'invite-tenant',
      builder: (context, state) => const InviteTenantScreen(),
    ),
    GoRoute(
      path: '/activity',
      name: 'activity',
      builder: (context, state) => const ActivityScreen(),
    ),
    GoRoute(
      path: '/owner/razorpay-settings',
      name: 'razorpay-settings',
      builder: (context, state) => const RazorpaySettingsScreen(),
    ),
    GoRoute(
      path: '/owner/expenses',
      name: 'owner-expenses',
      builder: (context, state) => const OwnerExpensesScreen(),
    ),
  ],
);
