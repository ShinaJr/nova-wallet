import 'package:flutter_test/flutter_test.dart';
import 'package:nova_wallet/core/money/money_formatter.dart';

void main() {
  group('MoneyFormatter — kobo-only, no floating point drift', () {
    test('formats kobo to naira correctly', () {
      expect(MoneyFormatter.formatKobo(0), '₦0.00');
      expect(MoneyFormatter.formatKobo(1), '₦0.01');
      expect(MoneyFormatter.formatKobo(45750000), '₦457,500.00');
      expect(MoneyFormatter.formatKobo(999999999), '₦9,999,999.99');
    });

    test('parses naira input strings to kobo', () {
      expect(MoneyFormatter.parseToKobo('5000'), 500000);
      expect(MoneyFormatter.parseToKobo('5,000.50'), 500050);
      expect(MoneyFormatter.parseToKobo('0.01'), 1);
      expect(MoneyFormatter.parseToKobo(''), 0);
    });

    test('summing 1000 one-kobo amounts stays exact — the trap doubles fall into', () {
      var total = 0;
      for (var i = 0; i < 1000; i++) {
        total += 1; // integer addition
      }
      expect(total, 1000);
      expect(MoneyFormatter.formatKobo(total), '₦10.00');

      // Demonstrate why doubles were rejected for storage/summation:
      var drift = 0.0;
      for (var i = 0; i < 1000; i++) {
        drift += 0.01;
      }
      expect(
        drift == 10.0,
        isFalse,
        reason: 'Double accumulation drifts — exactly why amounts are kobo ints',
      );
    });

    test('progress ratio is display-only and integer-derived', () {
      expect(MoneyFormatter.progressRatio(65000, 200000), closeTo(0.325, 0.0001));
      expect(MoneyFormatter.progressRatio(0, 0), 0.0);
      expect(MoneyFormatter.progressPercent(65000, 200000), '33%');
    });
  });
}
