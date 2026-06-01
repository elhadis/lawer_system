import 'package:intl/intl.dart' as intl;

String formatMoney(num value) {
  final f = intl.NumberFormat('#,##0.00', 'ar');
  return f.format(value);
}

String formatDate(String iso, {String pattern = 'yyyy/MM/dd'}) {
  if (iso.isEmpty) return '-';
  try {
    final d = DateTime.parse(iso);
    return intl.DateFormat(pattern, 'ar').format(d);
  } catch (_) {
    return iso;
  }
}

String formatDateTime(String iso) =>
    formatDate(iso, pattern: 'yyyy/MM/dd HH:mm');
