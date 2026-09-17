import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class WalletTable extends Table {
  TextColumn get id => text()();
  TextColumn get accountName => text()();
  TextColumn get accountNumber => text()();
  IntColumn get ledgerBalanceKobo => integer()();
  DateTimeColumn get lastSyncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class TransactionsTable extends Table {
  TextColumn get id => text()();
  TextColumn get description => text()();
  IntColumn get amountKobo => integer()();
  TextColumn get type => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get referenceNumber => text().nullable()();
  TextColumn get settlementState =>
      text().withDefault(const Constant('settled'))();

  @override
  Set<Column> get primaryKey => {id};
}

class SavingsGoalsTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get targetAmountKobo => integer()();
  IntColumn get contributedAmountKobo =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get targetDate => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class OfflineActionsTable extends Table {
  TextColumn get id => text()();
  TextColumn get actionType => text()();
  TextColumn get payloadJson => text()();
  TextColumn get status => text()();
  IntColumn get debitAmountKobo => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get errorMessage => text().nullable()();
  TextColumn get failureClass => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  WalletTable,
  TransactionsTable,
  SavingsGoalsTable,
  OfflineActionsTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'nova_wallet_db'));

  @override
  int get schemaVersion => 1;

  Future<void> seedIfEmpty() async {
    final existing = await getWallet();
    if (existing != null) return;
    await upsertWallet(WalletTableCompanion.insert(
      id: 'primary',
      accountName: 'Moses Adeyemi',
      accountNumber: '3012345678',
      ledgerBalanceKobo: 45750000,
      lastSyncedAt: DateTime.now(),
    ));
  }

  Future<WalletTableData?> getWallet() => select(walletTable).getSingleOrNull();

  Stream<WalletTableData?> watchWallet() =>
      select(walletTable).watchSingleOrNull();

  Future<void> upsertWallet(WalletTableCompanion wallet) =>
      into(walletTable).insertOnConflictUpdate(wallet);

  Future<int> getPendingDebitsKobo() async {
    final sumExpr = offlineActionsTable.debitAmountKobo.sum();
    final query = selectOnly(offlineActionsTable)
      ..addColumns([sumExpr])
      ..where(offlineActionsTable.status.isIn(const [
        'pending',
        'processing',
        'failedRetryable',
        'blockedInsufficientFunds',
      ]));
    final row = await query.getSingleOrNull();
    return row?.read(sumExpr) ?? 0;
  }

  Future<int> getAvailableBalanceKobo() async {
    final wallet = await getWallet();
    if (wallet == null) return 0;
    final pending = await getPendingDebitsKobo();
    return wallet.ledgerBalanceKobo - pending;
  }

  Future<List<OfflineActionsTableData>> getDispatchableActions() {
    final now = DateTime.now();
    return (select(offlineActionsTable)
          ..where((a) =>
              a.status.equals('pending') |
              (a.status.equals('failedRetryable') &
                  a.nextAttemptAt.isSmallerOrEqualValue(now)))
          ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
        .get();
  }

  Stream<List<OfflineActionsTableData>> watchVisibleQueue() {
    return (select(offlineActionsTable)
          ..where((a) => a.status.equals('completed').not())
          ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
        .watch();
  }

  Future<void> enqueue(OfflineActionsTableCompanion action) =>
      into(offlineActionsTable).insert(action);

  Future<void> setStatus(
    String id,
    String status, {
    String? error,
    String? failureClass,
    int? attempts,
    DateTime? nextAttemptAt,
  }) {
    return (update(offlineActionsTable)..where((a) => a.id.equals(id))).write(
      OfflineActionsTableCompanion(
        status: Value(status),
        errorMessage: Value(error),
        failureClass: Value(failureClass),
        attempts: attempts != null ? Value(attempts) : const Value.absent(),
        nextAttemptAt: Value(nextAttemptAt),
      ),
    );
  }

  Future<void> recoverOrphanedProcessing() =>
      (update(offlineActionsTable)..where((a) => a.status.equals('processing')))
          .write(const OfflineActionsTableCompanion(status: Value('pending')));

  Future<void> unblockInsufficientFunds() => (update(offlineActionsTable)
            ..where((a) => a.status.equals('blockedInsufficientFunds')))
          .write(const OfflineActionsTableCompanion(
        status: Value('pending'),
        errorMessage: Value(null),
      ));

  Future<void> cancelAction(String id) =>
      (delete(offlineActionsTable)..where((a) => a.id.equals(id))).go();

  Future<void> applySendOnce({
    required String idempotencyKey,
    required String description,
    required int amountKobo,
    String? reference,
  }) {
    return transaction(() async {
      final existing = await (select(transactionsTable)
            ..where((t) => t.id.equals(idempotencyKey)))
          .getSingleOrNull();
      if (existing != null && existing.settlementState == 'settled') {
        return;
      }

      await into(transactionsTable).insertOnConflictUpdate(
        TransactionsTableCompanion.insert(
          id: idempotencyKey,
          description: description,
          amountKobo: amountKobo,
          type: 'debit',
          timestamp: DateTime.now(),
          referenceNumber: Value(reference),
          settlementState: const Value('settled'),
        ),
      );

      final wallet = await getWallet();
      if (wallet != null) {
        await upsertWallet(WalletTableCompanion(
          id: Value(wallet.id),
          accountName: Value(wallet.accountName),
          accountNumber: Value(wallet.accountNumber),
          ledgerBalanceKobo: Value(wallet.ledgerBalanceKobo - amountKobo),
          lastSyncedAt: Value(DateTime.now()),
        ));
      }
    });
  }

  Future<void> applyContributionOnce({
    required String idempotencyKey,
    required String goalId,
    required int amountKobo,
  }) {
    return transaction(() async {
      final marker = await (select(transactionsTable)
            ..where((t) => t.id.equals(idempotencyKey)))
          .getSingleOrNull();
      if (marker != null && marker.settlementState == 'settled') return;

      await (update(savingsGoalsTable)..where((g) => g.id.equals(goalId)))
          .write(SavingsGoalsTableCompanion.custom(
        contributedAmountKobo:
            savingsGoalsTable.contributedAmountKobo + Variable(amountKobo),
      ));

      await into(transactionsTable).insertOnConflictUpdate(
        TransactionsTableCompanion.insert(
          id: idempotencyKey,
          description: 'NovaSave contribution',
          amountKobo: amountKobo,
          type: 'debit',
          timestamp: DateTime.now(),
          settlementState: const Value('settled'),
        ),
      );

      final wallet = await getWallet();
      if (wallet != null) {
        await upsertWallet(WalletTableCompanion(
          id: Value(wallet.id),
          accountName: Value(wallet.accountName),
          accountNumber: Value(wallet.accountNumber),
          ledgerBalanceKobo: Value(wallet.ledgerBalanceKobo - amountKobo),
          lastSyncedAt: Value(DateTime.now()),
        ));
      }
    });
  }

  Future<List<TransactionsTableData>> getRecentTransactions({int limit = 50}) {
    return (select(transactionsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(limit))
        .get();
  }

  Future<List<SavingsGoalsTableData>> getAllGoals() {
    return (select(savingsGoalsTable)
          ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]))
        .get();
  }

  Future<void> insertGoal(SavingsGoalsTableCompanion goal) =>
      into(savingsGoalsTable).insert(goal);

  Future<void> pruneCompletedOlderThan(Duration age) {
    final cutoff = DateTime.now().subtract(age);
    return (delete(offlineActionsTable)
          ..where((a) =>
              a.status.equals('completed') &
              a.createdAt.isSmallerThanValue(cutoff)))
        .go();
  }

  Future<void> capTransactionHistory({int keep = 200}) async {
    final all = await (select(transactionsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();
    if (all.length <= keep) return;
    final toDelete = all.sublist(keep).map((t) => t.id).toList();
    await (delete(transactionsTable)..where((t) => t.id.isIn(toDelete))).go();
  }
}
