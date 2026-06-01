import 'license_crypto.dart';

/// تشغيل من جذر المشروع:
/// `dart run lib/key_generator.dart`
///
/// — ضع هنا معرف جهاز العميل (Machine ID) بالضبط كما يظهر له في شاشة التفعيل.
/// — انسخ النص كاملاً (بما في ذلك الأقواس { } إن وُجدت) لأن المفتاح يُحسب على هذا النص حرفياً.
void main() {
  String targetId = '{FEE2F198-AC39-4CA0-AE12-BE6C1016EFCC}';

  if (targetId.isEmpty) {
    // ignore: avoid_print
    print(
      'ضع معرف الجهاز في المتغير targetId أعلاه، ثم نفّذ: dart run lib/key_generator.dart',
    );
    return;
  }

  final key = deriveLicenseActivationKey(targetId);
  // ignore: avoid_print
  print(key);
}
