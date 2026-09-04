import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';

/// Hashing, OTP issuing and biometric access.
class SecurityService {
  static const _pepper = 'kudi9ja.v1.7f3a';

  /// Salted SHA-256. Passcodes are never stored or compared in the clear.
  static String hash(String value) =>
      sha256.convert(utf8.encode('$_pepper|$value')).toString();

  static bool verify(String value, String? storedHash) =>
      storedHash != null && hash(value) == storedHash;

  static final _rand = Random.secure();

  /// Issues a 6-digit one-time code. A real deployment sends this from the
  /// server; in this build it is surfaced in-app so the flow is testable.
  static String issueOtp() =>
      List.generate(6, (_) => _rand.nextInt(10)).join();

  static String reference(String prefix) {
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final noise = _rand.nextInt(0xFFFF).toRadixString(36).padLeft(4, '0');
    return '$prefix-${ts.toUpperCase()}${noise.toUpperCase()}';
  }

  static final _auth = LocalAuthentication();

  static Future<bool> get isBiometricAvailable async {
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
