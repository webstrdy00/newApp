import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return const TokenStore(FlutterSecureStorage());
});

class TokenStore {
  const TokenStore(this._storage);

  static const _tokenKey = 'haemeoknote.auth_token';

  final FlutterSecureStorage _storage;

  Future<String?> read() {
    return _storage.read(key: _tokenKey);
  }

  Future<void> write(String token) {
    return _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clear() {
    return _storage.delete(key: _tokenKey);
  }
}
