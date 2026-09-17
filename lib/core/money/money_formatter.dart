import 'package:intl/intl.dart';

class MoneyFormatter {
  MoneyFormatter._();

  static final NumberFormat _nairaGrouping = NumberFormat('#,##0', 'en_NG');

  static String formatKobo(int kobo) {
    final isNegative = kobo < 0;
    final abs = kobo.abs();
    final naira = abs ~/ 100;
    final koboRemainder = abs % 100;
    final sign = isNegative ? '-' : '';
    return '$sign₦${_nairaGrouping.format(naira)}.'
        '${koboRemainder.toString().padLeft(2, '0')}';
  }

  static int parseToKobo(String input) {
    final cleaned = input.replaceAll(',', '').replaceAll('₦', '').trim();
    if (cleaned.isEmpty) return 0;
    final parts = cleaned.split('.');
    final naira = int.tryParse(parts[0]) ?? 0;
    var koboFromDecimal = 0;
    if (parts.length > 1) {
      final decimalPart = parts[1].padRight(2, '0').substring(0, 2);
      koboFromDecimal = int.tryParse(decimalPart) ?? 0;
    }
    return (naira * 100) + koboFromDecimal;
  }

  static double progressRatio(int contributedKobo, int targetKobo) {
    if (targetKobo <= 0) return 0.0;
    return (contributedKobo / targetKobo).clamp(0.0, 1.0);
  }

  static String progressPercent(int contributedKobo, int targetKobo) {
    final ratio = progressRatio(contributedKobo, targetKobo);
    return '${(ratio * 100).toStringAsFixed(0)}%';
  }
}
