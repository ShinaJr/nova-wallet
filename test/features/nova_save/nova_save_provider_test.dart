import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_wallet/core/connectivity/connectivity_service.dart';
import 'package:nova_wallet/core/database/app_database.dart';
import 'package:nova_wallet/core/network/dio_client.dart';
import 'package:nova_wallet/features/nova_save/providers/nova_save_provider.dart';

class _FakeConnectivity extends ConnectivityService {
  bool online;
  _FakeConnectivity({this.online = true}) : super(initialize: false);

  @override
  Future<bool> checkOnline() async => online;

  @override
  bool get isOnline => online;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DioClient dio;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dio = DioClient();
    await db.upsertWallet(WalletTableCompanion.insert(
      id: 'primary',
      accountName: 'Moses Adeyemi',
      accountNumber: '3012345678',
      ledgerBalanceKobo: 100000, // ₦1,000.00
      lastSyncedAt: DateTime.now(),
    ));
  });

  tearDown(() => db.close());

  test('creating a goal persists it locally with zero contributed', () async {
    final provider = NovaSaveProvider(
      dio: dio,
      db: db,
      connectivity: _FakeConnectivity(online: true),
    );

    await provider.createGoal(
      name: 'New Laptop',
      targetAmountKobo: 50000000,
      targetDate: DateTime.now().add(const Duration(days: 180)),
    );

    final goals = await db.getAllGoals();
    expect(goals.length, 1);
    expect(goals.first.name, 'New Laptop');
    expect(goals.first.contributedAmountKobo, 0);
  });

  test('contribution while online updates the goal exactly once', () async {
    final provider = NovaSaveProvider(
      dio: dio,
      db: db,
      connectivity: _FakeConnectivity(online: true),
    );

    await provider.createGoal(
      name: 'Rent Fund',
      targetAmountKobo: 30000,
      targetDate: DateTime.now().add(const Duration(days: 30)),
    );
    final goal = (await db.getAllGoals()).first;

    await provider.contribute(goal: goal, amountKobo: 10000);

    final updated = (await db.getAllGoals()).first;
    expect(updated.contributedAmountKobo, 10000);

    final wallet = await db.getWallet();
    expect(wallet!.ledgerBalanceKobo, 90000); // 100000 - 10000
  });

  test('contribution while offline is queued, not applied immediately', () async {
    final provider = NovaSaveProvider(
      dio: dio,
      db: db,
      connectivity: _FakeConnectivity(online: false),
    );

    await provider.createGoal(
      name: 'Rent Fund',
      targetAmountKobo: 30000,
      targetDate: DateTime.now().add(const Duration(days: 30)),
    );
    final goal = (await db.getAllGoals()).first;

    await provider.contribute(goal: goal, amountKobo: 10000);

    expect(provider.status, NovaSaveStatus.queued);

    // Ledger untouched until sync actually dispatches the queued action.
    final wallet = await db.getWallet();
    expect(wallet!.ledgerBalanceKobo, 100000);

    final queued = await db.getDispatchableActions();
    expect(queued.length, 1);
    expect(queued.first.actionType, 'contribute_to_goal');
  });

  test('contribution above available balance is rejected before queueing', () async {
    final provider = NovaSaveProvider(
      dio: dio,
      db: db,
      connectivity: _FakeConnectivity(online: false),
    );

    await provider.createGoal(
      name: 'Big Goal',
      targetAmountKobo: 500000,
      targetDate: DateTime.now().add(const Duration(days: 30)),
    );
    final goal = (await db.getAllGoals()).first;

    // Wallet only has ₦1,000 (100000 kobo); ask for ₦2,000.
    await provider.contribute(goal: goal, amountKobo: 200000);

    expect(provider.status, NovaSaveStatus.failure);
    final queued = await db.getDispatchableActions();
    expect(queued, isEmpty);
  });
}
