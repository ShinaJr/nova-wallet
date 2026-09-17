import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nova_wallet/core/biometrics/biometric_service.dart';
import 'package:nova_wallet/core/connectivity/connectivity_service.dart';
import 'package:nova_wallet/core/database/app_database.dart';
import 'package:nova_wallet/core/network/dio_client.dart';
import 'package:nova_wallet/core/theme/app_theme.dart';
import 'package:nova_wallet/features/send_money/presentation/recipient_page.dart';
import 'package:nova_wallet/features/send_money/providers/send_money_provider.dart';
import 'package:nova_wallet/features/wallet/providers/wallet_provider.dart';
import 'package:nova_wallet/l10n/app_localizations.dart';

/// Reports offline on demand without touching a real platform channel —
/// mirrors the fake already used by the provider-level tests.
class _FakeConnectivity extends ConnectivityService {
  bool online;
  _FakeConnectivity({this.online = true}) : super(initialize: false);

  @override
  Future<bool> checkOnline() async => online;

  @override
  bool get isOnline => online;
}

void main() {
  late AppDatabase db;
  late DioClient dio;
  late _FakeConnectivity connectivity;
  late SendMoneyProvider sendMoneyProvider;
  late WalletProvider walletProvider;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dio = DioClient();
    connectivity = _FakeConnectivity(online: false);
    await db.upsertWallet(WalletTableCompanion.insert(
      id: 'primary',
      accountName: 'Moses Adeyemi',
      accountNumber: '3012345678',
      ledgerBalanceKobo: 10000000, // ₦100,000 — comfortably above the test amount
      lastSyncedAt: DateTime.now(),
    ));
    sendMoneyProvider = SendMoneyProvider(
      dio: dio,
      db: db,
      connectivity: connectivity,
      biometrics: BiometricService(),
    );
    walletProvider = WalletProvider(dio: dio, db: db);
  });

  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SendMoneyProvider>.value(value: sendMoneyProvider),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
          ChangeNotifierProvider<WalletProvider>.value(value: walletProvider),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('yo')],
          home: const RecipientPage(),
        ),
      ),
    );
  }

  testWidgets(
    'Send Money: recipient -> amount -> confirm -> queued while offline',
    (tester) async {
      await pumpApp(tester);

      // RecipientPage: entering a 10-digit account ending in 0 resolves a name.
      await tester.enterText(find.byType(TextField).first, '0123456780');
      await tester.pump(); // triggers the resolve future
      await tester.pump(const Duration(milliseconds: 700)); // let it settle

      expect(find.text('Adaobi Okafor'), findsOneWidget);

      final continueOnRecipient = find.widgetWithText(FilledButton, 'Continue');
      expect(tester.widget<FilledButton>(continueOnRecipient).onPressed, isNotNull);
      await tester.tap(continueOnRecipient);
      await tester.pumpAndSettle();

      // AmountPage: tap a quick-amount chip rather than typing, then continue.
      expect(find.text('Send to Adaobi Okafor'), findsOneWidget);
      await tester.tap(find.widgetWithText(ActionChip, '₦1,000.00'));
      await tester.pump();

      final continueOnAmount = find.widgetWithText(FilledButton, 'Continue');
      expect(tester.widget<FilledButton>(continueOnAmount).onPressed, isNotNull);
      await tester.tap(continueOnAmount);
      await tester.pumpAndSettle();

      // ConfirmPage: offline banner is shown, and confirming queues the send.
      expect(find.text('Confirm Transfer'), findsOneWidget);
      expect(find.textContaining("You're offline"), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm & Send'));
      await tester.pumpAndSettle();

      // ResultPage reflects the queued (not lost, not silently retried) state.
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Will send when back online'), findsOneWidget);
      expect(sendMoneyProvider.status, SendMoneyStatus.queued);

      final queued = await db.getDispatchableActions();
      expect(queued.length, 1);
      expect(queued.first.debitAmountKobo, 100000);
    },
  );

  testWidgets(
    'Send Money: Continue stays disabled until a recipient is resolved',
    (tester) async {
      await pumpApp(tester);

      final continueButton = find.widgetWithText(FilledButton, 'Continue');
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, '123');
      await tester.pump();

      // Too short to resolve — still disabled, no lookup spinner or name.
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
      expect(find.text('Looking up account...'), findsNothing);
    },
  );
}
