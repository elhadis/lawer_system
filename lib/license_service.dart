import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:win32_registry/win32_registry.dart' as reg;

import 'license_crypto.dart' as crypto;

/// Offline licensing (device id + SHA256 key). Crypto lives in [license_crypto.dart]
/// so `dart run lib/key_generator.dart` does not need the Flutter SDK.
class LicenseService {
  LicenseService._();

  /// Same string as [crypto.licenseSecretSalt]; exposed for documentation / tests.
  static const String secretSalt = crypto.licenseSecretSalt;

  static const String prefsKeyIsActivated = 'is_activated';

  /// First 8 hex characters of SHA256([machineId] + [secretSalt]).
  static String deriveActivationKey(String machineId) =>
      crypto.deriveLicenseActivationKey(machineId);

  /// Case-insensitive match; [enteredKey] uses `.trim().toLowerCase()` per product spec.
  static bool verifyActivationKey({
    required String machineId,
    required String enteredKey,
  }) =>
      crypto.verifyLicenseActivationKey(machineId, enteredKey);

  /// Identifier shown on the activation screen (platform-specific).
  static Future<String> getUniqueDeviceId() async {
    if (kIsWeb) {
      final w = await DeviceInfoPlugin().webBrowserInfo;
      return w.userAgent ?? 'web-unknown';
    }
    if (Platform.isWindows) {
      return _windowsMachineId();
    }
    if (Platform.isAndroid) {
      final a = await DeviceInfoPlugin().androidInfo;
      return a.id;
    }
    if (Platform.isIOS) {
      final i = await DeviceInfoPlugin().iosInfo;
      return i.identifierForVendor ?? 'ios-unknown';
    }
    if (Platform.isLinux) {
      final l = await DeviceInfoPlugin().linuxInfo;
      return l.machineId ?? 'linux-unknown';
    }
    if (Platform.isMacOS) {
      final m = await DeviceInfoPlugin().macOsInfo;
      return m.systemGUID ?? 'mac-unknown';
    }
    return 'unknown-device';
  }

  /// Windows: MachineGuid from registry (same source as legacy desktop builds).
  static Future<String> _windowsMachineId() async {
    try {
      final key = reg.Registry.openPath(
        reg.RegistryHive.localMachine,
        path: r'SOFTWARE\Microsoft\Cryptography',
      );
      final guid = key.getStringValue('MachineGuid');
      key.close();
      if (guid != null && guid.trim().isNotEmpty) {
        return _braceGuid(guid.trim());
      }
    } catch (_) {
      // Fall through to device_info_plus.
    }
    final win = await DeviceInfoPlugin().windowsInfo;
    if (win.deviceId.isNotEmpty) {
      return _braceGuid(win.deviceId.trim());
    }
    return win.computerName;
  }

  static String _braceGuid(String raw) {
    if (raw.startsWith('{') && raw.endsWith('}')) return raw;
    if (raw.contains('-')) return '{$raw}';
    return raw;
  }
}
