import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ThousandsSeparatorFormatter extends TextInputFormatter {
  static final _grouping = NumberFormat('#,##0');

  static String formatKoboForField(int kobo) =>
      NumberFormat('#,##0.00').format(kobo / 100);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsAndDot = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');
    if (digitsAndDot.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final firstDot = digitsAndDot.indexOf('.');
    final wholePart =
        firstDot == -1 ? digitsAndDot : digitsAndDot.substring(0, firstDot);
    final decimalPart = firstDot == -1
        ? ''
        : '.${digitsAndDot.substring(firstDot + 1).replaceAll('.', '')}';

    final formattedWhole =
        wholePart.isEmpty ? '' : _grouping.format(int.parse(wholePart));
    final formatted = '$formattedWhole$decimalPart';

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
