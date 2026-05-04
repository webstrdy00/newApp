import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';
import '../data/token_store.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(authDioProvider));
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final controller = AuthController(
    ref: ref,
    repository: ref.watch(authRepositoryProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
  ref.listen<String?>(authTokenProvider, (previous, next) {
    if (previous != null && next == null) {
      controller.expireSession();
    }
  });
  return controller;
});

class AuthState {
  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
  });

  final AppUser? user;
  final String? token;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user != null && token != null;

  AuthState copyWith({
    AppUser? user,
    String? token,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearToken = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : user ?? this.user,
      token: clearToken ? null : token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required Ref ref,
    required AuthRepository repository,
    required TokenStore tokenStore,
  })  : _ref = ref,
        _repository = repository,
        _tokenStore = tokenStore,
        super(const AuthState(isLoading: true)) {
    restore();
  }

  final Ref _ref;
  final AuthRepository _repository;
  final TokenStore _tokenStore;

  Future<void> restore() async {
    final token = await _tokenStore.read();
    if (token == null || token.isEmpty) {
      _ref.read(authTokenProvider.notifier).state = null;
      state = const AuthState();
      return;
    }

    try {
      _ref.read(authTokenProvider.notifier).state = token;
      final user = await _repository.me(token);
      state = AuthState(user: user, token: token);
    } catch (_) {
      await expireSession();
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final token = await _repository.login(email: email, password: password);
      await _tokenStore.write(token.accessToken);
      _ref.read(authTokenProvider.notifier).state = token.accessToken;
      final user = await _repository.me(token.accessToken);
      state = AuthState(user: user, token: token.accessToken);
    } catch (error) {
      state = AuthState(error: _friendlyError(error));
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      await login(email: email, password: password);
    } catch (error) {
      state = AuthState(error: _friendlyError(error));
      rethrow;
    }
  }

  Future<void> logout() async {
    await expireSession();
  }

  Future<void> expireSession() async {
    await _tokenStore.clear();
    _ref.read(authTokenProvider.notifier).state = null;
    state = const AuthState();
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('이미 가입된 이메일입니다')) {
      return '이미 가입된 이메일입니다.';
    }
    if (message.contains('이메일 또는 비밀번호가 올바르지 않습니다')) {
      return '이메일 또는 비밀번호가 올바르지 않습니다.';
    }
    if (message.contains('Connection refused') ||
        message.contains('SocketException') ||
        message.contains('XMLHttpRequest')) {
      return '백엔드 API에 연결할 수 없어요.';
    }
    return '요청을 처리하지 못했어요.';
  }
}
