import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const _keyAuthToken = 'nova_wallet_auth_token';

  Future<void> saveMockAuthToken() async {
    await _storage.write(
      key: _keyAuthToken,
      value: 'mock-jwt-${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Future<String?> readAuthToken() => _storage.read(key: _keyAuthToken);

  Future<void> clear() => _storage.deleteAll();
}
