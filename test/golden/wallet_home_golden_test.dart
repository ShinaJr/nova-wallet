import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:nova_wallet/core/theme/app_theme.dart';
import 'package:nova_wallet/features/wallet/presentation/widgets/balance_header.dart';

/// Golden test for the balance header — the single most visually and
/// functionally important widget in the app (it's where "available vs
/// ledger vs pending" is communicated to the user). A pixel regression
/// here — a font change, a colour change, a layout shift under a large
/// font-scale — is exactly the kind of thing this test class is meant
/// to catch before it reaches a reviewer's device.
///
/// To (re)generate the golden file after an intentional UI change:
///   flutter test --update-goldens test/golden/wallet_home_golden_test.dart
void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  testGoldens('BalanceHeader renders correctly with no pending actions',
      (tester) async {
    await tester.pumpWidgetBuilder(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: BalanceHeader(
            accountName: 'Moses Adeyemi',
            accountNumber: '3012345678',
            ledgerKobo: 45750000,
            pendingKobo: 0,
          ),
        ),
      ),
      surfaceSize: const Size(390, 280), // budget-device-ish width
    );

    await screenMatchesGolden(tester, 'balance_header_no_pending');
  });

  testGoldens('BalanceHeader renders correctly WITH a pending queued amount',
      (tester) async {
    await tester.pumpWidgetBuilder(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: BalanceHeader(
            accountName: 'Moses Adeyemi',
            accountNumber: '3012345678',
            ledgerKobo: 40000, // ₦400.00
            pendingKobo: 20000, // ₦200.00 queued — matches the interview scenario
          ),
        ),
      ),
      surfaceSize: const Size(390, 280),
    );

    await screenMatchesGolden(tester, 'balance_header_with_pending');
  });

  testGoldens('BalanceHeader survives a large system font-scale factor',
      (tester) async {
    await tester.pumpWidgetBuilder(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.6),
          ),
          child: child!,
        ),
        home: const Scaffold(
          body: BalanceHeader(
            accountName: 'Moses Adeyemi',
            accountNumber: '3012345678',
            ledgerKobo: 45750000,
            pendingKobo: 0,
          ),
        ),
      ),
      surfaceSize: const Size(390, 320), // slightly taller — text takes more room
    );

    await screenMatchesGolden(tester, 'balance_header_large_font_scale');
  });
}
