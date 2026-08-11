/// Converts app / web invite links into in-app GoRouter locations.
String? routeFromDeepLink(Uri uri) {
  // Already an in-app path (defensive).
  if (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme.isEmpty) {
    final path = uri.path;
    if (path.startsWith('/invite/')) {
      final parts = path.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        return '/login?invite_token=${parts[1]}';
      }
    }
    if (path == '/login' || path.startsWith('/login')) {
      final invite = uri.queryParameters['invite_token'];
      if (invite != null && invite.isNotEmpty) {
        return '/login?invite_token=$invite';
      }
      return '/login';
    }
  }

  if (uri.scheme != 'rentease') return null;

  final host = uri.host.toLowerCase();
  final path = uri.path.toLowerCase();
  final invite = uri.queryParameters['invite_token'] ??
      uri.queryParameters['token'];

  // rentease://login?invite_token=xxx
  // rentease://login/?invite_token=xxx
  if (host == 'login' || path == '/login' || path.startsWith('/login')) {
    if (invite != null && invite.isNotEmpty) {
      return '/login?invite_token=$invite';
    }
    return '/login';
  }

  // rentease://accept-invite?token=xxx
  if (host == 'accept-invite' ||
      path == '/accept-invite' ||
      path.endsWith('accept-invite')) {
    if (invite != null && invite.isNotEmpty) {
      return '/login?invite_token=$invite';
    }
  }

  // rentease:///login?invite_token=xxx (empty host, path only)
  if (invite != null && invite.isNotEmpty) {
    return '/login?invite_token=$invite';
  }

  return '/login';
}

/// Normalize whatever the platform/go_router handed us into a known route.
String normalizeAppLocation(String? location) {
  if (location == null || location.isEmpty || location == '/') {
    return '/login';
  }

  // Full custom-scheme URI slipped into the router
  if (location.startsWith('rentease:') ||
      location.startsWith('http://') ||
      location.startsWith('https://')) {
    try {
      return routeFromDeepLink(Uri.parse(location)) ?? '/login';
    } catch (_) {
      return '/login';
    }
  }

  // Trailing slash variants
  if (location == '/login/') return '/login';
  if (location.startsWith('/login/?')) {
    return location.replaceFirst('/login/?', '/login?');
  }

  return location;
}
