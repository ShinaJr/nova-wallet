import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/dio_client.dart';

class WalletProvider extends ChangeNotifier {
  final DioClient _dio;
  final AppDatabase _db;

  int _ledgerBalanceKobo = 0;
  int _pendingDebitsKobo = 0;
  String _accountName = '';
  String _accountNumber = '';
  List<TransactionsTableData> _transactions = const [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;

  int get ledgerBalanceKobo => _ledgerBalanceKobo;
  int get pendingDebitsKobo => _pendingDebitsKobo;
  int get availableBalanceKobo => _ledgerBalanceKobo - _pendingDebitsKobo;
  String get accountName => _accountName;
  String get accountNumber => _accountNumber;
  List<TransactionsTableData> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get error => _error;

  WalletProvider({required DioClient dio, required AppDatabase db})
      : _dio = dio,
        _db = db;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    await _loadLocalFirst();
    await _refreshFromNetwork();
    _isLoading = false;
    _isRefreshing = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    _isRefreshing = true;
    notifyListeners();
    await _refreshFromNetwork();
    _isRefreshing = false;
    notifyListeners();
  }

  Future<void> refreshLocalOnly() async {
    await _loadLocalFirst();
    notifyListeners();
  }

  Future<void> _loadLocalFirst() async {
    final wallet = await _db.getWallet();
    if (wallet != null) {
      _ledgerBalanceKobo = wallet.ledgerBalanceKobo;
      _accountName = wallet.accountName;
      _accountNumber = wallet.accountNumber;
    }
    _pendingDebitsKobo = await _db.getPendingDebitsKobo();
    _transactions = await _db.getRecentTransactions();
  }

  Future<void> _refreshFromNetwork() async {
    try {
      final balanceRes =
          await _dio.dio.get<Map<String, dynamic>>('/wallet/balance');
      final balanceData = balanceRes.data!;
      await _db.upsertWallet(WalletTableCompanion.insert(
        id: 'primary',
        accountName: balanceData['accountName'] as String,
        accountNumber: balanceData['accountNumber'] as String,
        ledgerBalanceKobo: balanceData['balanceKobo'] as int,
        lastSyncedAt: DateTime.now(),
      ));

      final txnRes =
          await _dio.dio.get<Map<String, dynamic>>('/wallet/transactions');
      final txns = txnRes.data!['transactions'] as List;
      for (final t in txns) {
        final map = t as Map<String, dynamic>;
        await _db.into(_db.transactionsTable).insertOnConflictUpdate(
              TransactionsTableCompanion.insert(
                id: map['id'] as String,
                description: map['description'] as String,
                amountKobo: map['amountKobo'] as int,
                type: map['type'] as String,
                timestamp: DateTime.parse(map['timestamp'] as String),
                referenceNumber: Value(map['referenceNumber'] as String?),
              ),
            );
      }
      await _loadLocalFirst();
    } catch (_) {
      _error = 'Could not refresh — showing your last saved data.';
    }
  }
}
