import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nova_wallet/core/connectivity/connectivity_service.dart';
import 'package:nova_wallet/core/database/app_database.dart';
import 'package:nova_wallet/core/network/dio_client.dart';
import 'package:nova_wallet/core/theme/app_theme.dart';
import 'package:nova_wallet/features/nova_save/presentation/contribute_page.dart';
import 'package:nova_wallet/features/nova_save/providers/nova_save_provider.dart';
import 'package:nova_wallet/features/wallet/providers/wallet_provider.dart';

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
  late NovaSaveProvider novaSaveProvider;
  late WalletProvider walletProvider;
  late SavingsGoalsTableData goal;

  var goalCounter = 0;

  Future<SavingsGoalsTableData> seedGoal({
    int targetAmountKobo = 3000000, // ₦30,000
    int contributedAmountKobo = 0,
  }) async {
    final id = 'goal-${goalCounter++}';
    await db.insertGoal(SavingsGoalsTableCompanion.insert(
      id: id,
      name: 'Rent Fund',
      targetAmountKobo: targetAmountKobo,
      targetDate: DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime.now(),
      contributedAmountKobo: Value(contributedAmountKobo),
    ));
    return (await db.getAllGoals()).firstWhere((g) => g.id == id);
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dio = DioClient();
    connectivity = _FakeConnectivity(online: false);
    await db.upsertWallet(WalletTableCompanion.insert(
      id: 'primary',
      accountName: 'Moses Adeyemi',
      accountNumber: '3012345678',
      ledgerBalanceKobo: 10000000, // ₦100,000
      lastSyncedAt: DateTime.now(),
    ));
    novaSaveProvider = NovaSaveProvider(dio: dio, db: db, connectivity: connectivity);
    walletProvider = WalletProvider(dio: dio, db: db);
    goal = await seedGoal();
  });

  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester, {SavingsGoalsTableData? withGoal}) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<NovaSaveProvider>.value(value: novaSaveProvider),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
          ChangeNotifierProvider<WalletProvider>.value(value: walletProvider),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: ContributePage(goal: withGoal ?? goal),
        ),
      ),
    );
  }

  testWidgets(
    'Contribute while offline: queues the action and shows the queued snackbar',
    (tester) async {
      await pumpApp(tester);

      expect(find.text('Rent Fund'), findsOneWidget);
      expect(find.textContaining("You're offline"), findsOneWidget);

      await tester.enterText(find.byType(TextField), '5000');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Contribute'));
      await tester.pump(); // let contribute() run and notifyListeners

      // The contribute page listens for success/queued and pops itself after
      // showing a SnackBar — pump through that post-frame callback.
      await tester.pump();
      expect(find.text('Contribution queued — will sync when back online.'), findsOneWidget);

      final queued = await db.getDispatchableActions();
      expect(queued.length, 1);
      expect(queued.first.actionType, 'contribute_to_goal');
      expect(queued.first.debitAmountKobo, 500000);

      // Ledger must stay untouched until the queue actually dispatches.
      final wallet = await db.getWallet();
      expect(wallet!.ledgerBalanceKobo, 10000000);
    },
  );

  testWidgets(
    'Contribute above available balance is rejected and shown inline, never queued',
    (tester) async {
      // Target is well above the ask, so this exercises the wallet-balance
      // guard specifically, not the goal-target guard below.
      final bigGoal = await seedGoal(targetAmountKobo: 50000000); // ₦500,000
      await pumpApp(tester, withGoal: bigGoal);

      // Wallet only has ₦100,000; ask for ₦200,000.
      await tester.enterText(find.byType(TextField), '200000');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Contribute'));
      await tester.pump();

      expect(novaSaveProvider.status, NovaSaveStatus.failure);
      expect(find.textContaining('available'), findsOneWidget);

      final queued = await db.getDispatchableActions();
      expect(queued, isEmpty);
    },
  );

  testWidgets(
    'Contribute above what\'s left on the goal is blocked before it can be submitted',
    (tester) async {
      // Goal target ₦30,000, nothing contributed yet — ₦40,000 is over
      // target even though the wallet could easily afford it.
      await pumpApp(tester);

      await tester.enterText(find.byType(TextField), '40000');
      await tester.pump();

      expect(find.textContaining("exceeds what's left"), findsOneWidget);
      final button = find.widgetWithText(FilledButton, 'Contribute');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);

      await tester.tap(button, warnIfMissed: false);
      await tester.pump();

      // Never reached the provider — button was disabled.
      expect(novaSaveProvider.status, NovaSaveStatus.initial);
      final queued = await db.getDispatchableActions();
      expect(queued, isEmpty);
    },
  );

  testWidgets(
    'Contribute button is disabled until a positive amount is entered',
    (tester) async {
      await pumpApp(tester);

      final button = find.widgetWithText(FilledButton, 'Contribute');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '100');
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    },
  );
}
