import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lightweight offline cache for last-seen profile / role (Phase 6 polish).
/// Full Hive/drift sync can replace this later.
class OfflineCache {
  static const _storage = FlutterSecureStorage();

  static Future<void> saveProfile({
    required String email,
    required String role,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    await _storage.write(key: 'user_email', value: email);
    await _storage.write(key: 'user_role', value: role);
    await _storage.write(key: 'user_first_name', value: firstName);
    await _storage.write(key: 'user_last_name', value: lastName);
    await _storage.write(key: 'user_phone', value: phone);
  }

  static Future<Map<String, String?>> readProfile() async {
    return {
      'email': await _storage.read(key: 'user_email'),
      'role': await _storage.read(key: 'user_role'),
      'first_name': await _storage.read(key: 'user_first_name'),
      'last_name': await _storage.read(key: 'user_last_name'),
      'phone': await _storage.read(key: 'user_phone'),
    };
  }
}
