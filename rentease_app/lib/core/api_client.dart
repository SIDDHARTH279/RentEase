import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String accessTokenKey = 'access_token';
const String refreshTokenKey = 'refresh_token';

final _storage = FlutterSecureStorage();

final Dio apiClient = Dio(
  BaseOptions(
    baseUrl: 'http://192.168.29.75:8000',
    connectTimeout: Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
    },
  ),
)..interceptors.add(
  InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await _storage.read(key: accessTokenKey);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },

    onError: (DioException err, handler) async {
      if (err.response?.statusCode == 401) {
        final refreshToken = await _storage.read(key: refreshTokenKey);

        if (refreshToken == null) {
          await _storage.deleteAll();
          handler.reject(err);
          return;
        }

        try {
          final response = await Dio().post(
            'http://10.0.2.2:8000/api/v1/auth/refresh/',
            data: {'refresh': refreshToken},
          );

          final newAccessToken = response.data['access'];
          await _storage.write(key: accessTokenKey, value: newAccessToken);

          err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          final retryResponse = await apiClient.fetch(err.requestOptions);
          handler.resolve(retryResponse);
        } catch (_) {
          await _storage.deleteAll();
          handler.reject(err);
        }
      } else {
        handler.next(err);
      }
    },
  ),
);