import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Personal app PIN (Layer 2). Separate from [license_crypto.dart] / licensing.
class PersonalPin {
  PersonalPin._();

  static const String prefsKeySalt = 'personal_pin_salt_b64';
  static const String prefsKeyHash = 'personal_pin_sha256_hex';

  static bool hasPin(SharedPreferences prefs) {
    final h = prefs.getString(prefsKeyHash);
    return h != null && h.isNotEmpty;
  }

  static bool verify(SharedPreferences prefs, String pin) {
    final salt = prefs.getString(prefsKeySalt);
    final stored = prefs.getString(prefsKeyHash);
    if (salt == null || stored == null) return false;
    return _hash(salt, pin) == stored;
  }

  static Future<void> saveNewPin(SharedPreferences prefs, String pin) async {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final salt = base64Url.encode(bytes);
    final hex = _hash(salt, pin);
    await prefs.setString(prefsKeySalt, salt);
    await prefs.setString(prefsKeyHash, hex);
  }

  static String _hash(String salt, String pin) =>
      sha256.convert(utf8.encode(salt + pin)).toString();
}
