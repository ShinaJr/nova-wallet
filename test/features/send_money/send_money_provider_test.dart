import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_wallet/core/biometrics/biometric_service.dart';
import 'package:nova_wallet/core/connectivity/connectivity_service.dart';
import 'package:nova_wallet/core/database/app_database.dart';
import 'package:nova_wallet/core/network/dio_client.dart';
import 'package:nova_wallet/features/send_money/providers/send_money_provider.dart';

/// Fake connectivity that reports offline on demand, without touching a
/// real platform channel — keeps this test fast and deterministic.
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
    dio = DioClient(); // uses MockInterceptor — see core/network
    await db.upsertWallet(WalletTableCompanion.insert(
      id: 'primary',
      accountName: 'Moses Adeyemi',
      accountNumber: '3012345678',
      ledgerBalanceKobo: 40000, // ₦400.00
      lastSyncedAt: DateTime.now(),
    ));
  });

  tearDown(() => db.close());

  test('Send Money queues offline and shows queued status', () async {
    final provider = SendMoneyProvider(
      dio: dio,
      db: db,
      connectivity: _FakeConnectivity(online: false),
      biometrics: BiometricService(),
    );

    provider.selectRecipient(
      account: '0123456789',
      name: 'Adaobi Okafor',
      bank: 'GTBank',
    );
    provider.enterAmount(amountKobo: 20000); // ₦200

    await provider.confirmSend();

    expect(provider.status, SendMoneyStatus.queued);

    final queued = await db.getDispatchableActions();
    expect(queued.length, 1);
    expect(queued.first.debitAmountKobo, 20000);
  });

  test(
    'Send Money rejects an amount above AVAILABLE balance — '
    'the ₦400/₦200/₦300 scenario reproduced through the provider',
    () async {
      final connectivity = _FakeConnectivity(online: false);
      final provider = SendMoneyProvider(
        dio: dio,
        db: db,
        connectivity: connectivity,
        biometrics: BiometricService(),
      );

      // First send: ₦200 — allowed, queues successfully.
      provider.selectRecipient(
        account: '0123456789',
        name: 'Adaobi Okafor',
        bank: 'GTBank',
      );
      provider.enterAmount(amountKobo: 20000);
      await provider.confirmSend();
      expect(provider.status, SendMoneyStatus.queued);

      // Second send: ₦300 — must be rejected, NOT queued, because
      // available balance is now only ₦200.
      provider.selectRecipient(
        account: '0987654321',
        name: 'Emeka Nwosu',
        bank: 'Zenith Bank',
      );
      provider.enterAmount(amountKobo: 30000);
      await provider.confirmSend();

      expect(provider.status, SendMoneyStatus.failure);
      expect(provider.errorMessage, contains('available'));

      final queued = await db.getDispatchableActions();
      expect(
        queued.length,
        1,
        reason: 'Only the first ₦200 send should ever have been enqueued',
      );
    },
  );
}
