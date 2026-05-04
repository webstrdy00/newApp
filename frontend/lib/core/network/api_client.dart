import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000/api',
);

final authTokenProvider = StateProvider<String?>((ref) => null);

BaseOptions _baseOptions() {
  return BaseOptions(
    baseUrl: defaultApiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Accept': 'application/json'},
  );
}

final authDioProvider = Provider<Dio>((ref) {
  return Dio(_baseOptions());
});

final dioProvider = Provider<Dio>((ref) {
  final token = ref.watch(authTokenProvider);
  final dio = Dio(_baseOptions());
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          ref.read(authTokenProvider.notifier).state = null;
        }
        handler.next(error);
      },
    ),
  );
  return dio;
});

Dio createStandaloneDio() {
  return Dio(
    BaseOptions(
      baseUrl: defaultApiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ),
  );
}
