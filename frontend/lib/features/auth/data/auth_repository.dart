import 'package:dio/dio.dart';

import 'auth_models.dart';

class AuthRepository {
  const AuthRepository(this._dio);

  final Dio _dio;

  Future<AppUser> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'display_name': displayName,
      },
    );
    return AppUser.fromJson(response.data!);
  }

  Future<AuthToken> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return AuthToken.fromJson(response.data!);
  }

  Future<AppUser> me(String token) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return AppUser.fromJson(response.data!);
  }
}
