import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import 'api_client.dart';

const _storage = FlutterSecureStorage();

/// Call from any screen to log the user out cleanly.
Future<void> logout(BuildContext context) async {
  try {
    final refresh = await _storage.read(key: refreshTokenKey);
    if (refresh != null) {
      await apiClient.post(
        '/api/v1/auth/logout/',
        data: {'refresh': refresh},
      );
    }
  } catch (_) {
    // Even if API call fails, clear local storage
  }
  await _storage.deleteAll();
  if (context.mounted) context.go('/login');
}
