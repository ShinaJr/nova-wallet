import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nova_wallet/core/connectivity/connectivity_service.dart';
import 'package:nova_wallet/core/database/app_database.dart';
import 'package:nova_wallet/core/network/dio_client.dart';
import 'package:nova_wallet/core/theme/app_theme.dart';
import 'package:nova_wallet/features/nova_save/presentation/create_goal_page.dart';
import 'package:nova_wallet/features/nova_save/providers/nova_save_provider.dart';

class _FakeConnectivity extends ConnectivityService {
  _FakeConnectivity() : super(initialize: false);

  @override
  Future<bool> checkOnline() async => true;

  @override
  bool get isOnline => true;
}

void main() {
  late AppDatabase db;
  late NovaSaveProvider provider;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.upsertWallet(WalletTableCompanion.insert(
      id: 'primary',
      accountName: 'Moses Adeyemi',
      accountNumber: '3012345678',
      ledgerBalanceKobo: 10000000,
      lastSyncedAt: DateTime.now(),
    ));
    provider = NovaSaveProvider(dio: DioClient(), db: db, connectivity: _FakeConnectivity());
  });

  tearDown(() => db.close());

  testWidgets(
    'Creating a goal does not leave a stale success status for the next screen to misread '
    '(regression: ContributePage watches the same NovaSaveStatus.success and would '
    'immediately snackbar-and-pop on open if this leaked)',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<NovaSaveProvider>.value(
          value: provider,
          child: MaterialApp(theme: buildAppTheme(), home: const CreateGoalPage()),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Goal name'), 'Rent Fund');
      await tester.enterText(find.widgetWithText(TextField, 'Target amount'), '30000');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Create Goal'));
      await tester.pumpAndSettle();

      expect(provider.status, isNot(NovaSaveStatus.success));
      expect(provider.successMessage, isEmpty);
    },
  );
}
