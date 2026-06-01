import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Salt must match [LicenseService.secretSalt] in `license_service.dart`.
const String licenseSecretSalt = 'Ragabaat';

/// First 8 hex characters of SHA256([machineId] + salt).
String deriveLicenseActivationKey(String machineId) {
  final input = machineId + licenseSecretSalt;
  final digest = sha256.convert(utf8.encode(input));
  return digest.toString().substring(0, 8);
}

/// Case-insensitive; [enteredKey] is trimmed then lowercased.
bool verifyLicenseActivationKey(String machineId, String enteredKey) {
  final expected = deriveLicenseActivationKey(machineId).toLowerCase();
  final normalized = enteredKey.trim().toLowerCase();
  return normalized.length == 8 && normalized == expected;
}
