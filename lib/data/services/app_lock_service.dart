import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Device authentication for the app lock.
///
/// Wraps `local_auth` so the rest of the app never has to care that it throws
/// on platforms with no biometrics — desktop among them. [isAvailable] is what
/// Settings uses to decide whether the switch can be turned on at all, because
/// an app lock you cannot pass would lock you out of your own records.
class AppLockService {
  AppLockService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  bool get _isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<bool> isAvailable() async {
    if (!_isSupportedPlatform) return false;
    try {
      // `isDeviceSupported` covers a device PIN or pattern as well as
      // biometrics, which is what the Settings copy promises.
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Returns true when the user proved who they are, false otherwise. Never
  /// throws: a failure here must leave the caller able to decide what to do.
  Future<bool> authenticate({required String reason}) async {
    if (!_isSupportedPlatform) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          // Falling back to the device PIN matters: a wet or unrecognised
          // fingerprint should not mean losing access to your budget.
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
