import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the session lives between launches.
///
/// Tokens go in the platform keystore — Keychain on iOS, EncryptedSharedPreferences
/// on Android — rather than in `shared_preferences` with everything else. A
/// refresh token is a bearer credential: anything holding it *is* the customer
/// for thirty days. `shared_preferences` is a plain XML file, readable by any
/// process with the app's uid on a rooted phone and copied wholesale by some
/// backup tools.
///
/// The access token is kept in memory as well, so the common case — a request
/// on a warm app — never waits on a platform channel.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                // Not available until the phone has been unlocked once since
                // boot, and never copied to a new device by a backup restore.
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  static const _kAccess = 'k9.token.access';
  static const _kRefresh = 'k9.token.refresh';
  static const _kExpiresAt = 'k9.token.expiresAt';
  static const _kSessionId = 'k9.token.sessionId';

  String? _access;
  String? _refresh;
  DateTime? _expiresAt;
  String? _sessionId;

  bool _loaded = false;

  String? get accessToken => _access;
  String? get refreshToken => _refresh;
  String? get sessionId => _sessionId;

  /// Whether there is a session to try at all. Says nothing about whether the
  /// server still honours it.
  bool get hasSession => _refresh != null;

  /// Whether the access token is spent, or close enough that a request made now
  /// would likely land after it expires.
  ///
  /// The thirty-second margin exists because the token is checked here and
  /// verified on the server a round trip later; without it, a token with two
  /// seconds left looks valid, and the request fails for no good reason.
  bool get isAccessExpired {
    if (_access == null) return true;
    final expiry = _expiresAt;
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry.subtract(const Duration(seconds: 30)));
  }

  /// Reads the session back after a cold start. Safe to call more than once.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final all = await _storage.readAll();
      _access = all[_kAccess];
      _refresh = all[_kRefresh];
      _sessionId = all[_kSessionId];
      final raw = all[_kExpiresAt];
      _expiresAt = raw == null ? null : DateTime.tryParse(raw);
    } catch (_) {
      // A keystore that will not open — a restored backup on a new device, a
      // corrupted Android keystore after an OS upgrade — is not an error worth
      // crashing on. It means there is no usable session, which is a state the
      // app already handles: the customer signs in again.
      await clear();
    }
  }

  /// Records a session returned by sign-in, sign-up completion, or a refresh.
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required int expiresInSeconds,
    String? sessionId,
  }) async {
    _access = accessToken;
    _refresh = refreshToken;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresInSeconds));
    _sessionId = sessionId ?? _sessionId;
    _loaded = true;

    await Future.wait([
      _storage.write(key: _kAccess, value: _access),
      _storage.write(key: _kRefresh, value: _refresh),
      _storage.write(key: _kExpiresAt, value: _expiresAt!.toIso8601String()),
      if (_sessionId != null) _storage.write(key: _kSessionId, value: _sessionId),
    ]);
  }

  /// Forgets the session. Called on sign-out, and whenever the server tells us
  /// the refresh token is no longer good.
  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _expiresAt = null;
    _sessionId = null;
    _loaded = true;
    try {
      await Future.wait([
        _storage.delete(key: _kAccess),
        _storage.delete(key: _kRefresh),
        _storage.delete(key: _kExpiresAt),
        _storage.delete(key: _kSessionId),
      ]);
    } catch (_) {
      // Already gone, or the keystore is unreadable. Either way the in-memory
      // copy is cleared, which is what the rest of the app reads.
    }
  }

  /// Debug aid only — never logged, never sent anywhere.
  @override
  String toString() => 'TokenStore(hasSession: $hasSession, '
      'accessExpired: $isAccessExpired, expiresAt: $_expiresAt)';
}

/// A no-op store for tests and for the widget previews, so neither needs a
/// platform channel that does not exist off-device.
class InMemoryTokenStore extends TokenStore {
  InMemoryTokenStore() : super(storage: _NullSecureStorage());
}

class _NullSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _values = {};

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      Map.of(_values);

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _values.remove(key);

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _values[key];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Decodes a JWT's payload without verifying it.
///
/// The app never *trusts* this — the server verifies every token on every
/// request, and a client-side check of a signature it cannot validate would be
/// theatre. It is used only to read the expiry so the app can refresh before a
/// request rather than after a failure.
Map<String, dynamic>? peekJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    payload = payload.padRight((payload.length + 3) & ~3, '=');
    return jsonDecode(utf8.decode(base64.decode(payload))) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}
