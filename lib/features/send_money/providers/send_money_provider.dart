import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/biometrics/biometric_service.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/network/dio_client.dart';

enum SendMoneyStatus {
  initial,
  recipientSelected,
  amountEntered,
  processing,
  queued,
  success,
  failure,
}

class SendMoneyProvider extends ChangeNotifier {
  final DioClient _dio;
  final AppDatabase _db;
  final ConnectivityService _connectivity;
  final BiometricService _biometrics;

  SendMoneyStatus _status = SendMoneyStatus.initial;
  String _toAccount = '';
  String _recipientName = '';
  String _bankName = '';
  int _amountKobo = 0;
  String _narration = '';
  late String _idempotencyKey;
  String _transactionRef = '';
  String _errorMessage = '';
  bool _isSubmitting = false;

  SendMoneyStatus get status => _status;
  bool get isSubmitting => _isSubmitting;
  String get toAccount => _toAccount;
  String get recipientName => _recipientName;
  String get bankName => _bankName;
  int get amountKobo => _amountKobo;
  String get transactionRef => _transactionRef;
  String get errorMessage => _errorMessage;
  String get idempotencyKey => _idempotencyKey;

  SendMoneyProvider({
    required DioClient dio,
    required AppDatabase db,
    required ConnectivityService connectivity,
    required BiometricService biometrics,
  })  : _dio = dio,
        _db = db,
        _connectivity = connectivity,
        _biometrics = biometrics;

  void selectRecipient({
    required String account,
    required String name,
    required String bank,
  }) {
    _toAccount = account;
    _recipientName = name;
    _bankName = bank;
    _status = SendMoneyStatus.recipientSelected;
    notifyListeners();
  }

  void enterAmount({required int amountKobo, String narration = ''}) {
    _amountKobo = amountKobo;
    _narration = narration;
    _idempotencyKey = const Uuid().v4();
    if (kDebugMode) {
      debugPrint('SendMoney idempotency key: $_idempotencyKey');
    }
    _status = SendMoneyStatus.amountEntered;
    notifyListeners();
  }

  Future<int> availableBalanceKobo() => _db.getAvailableBalanceKobo();

  Future<void> confirmSend() async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    notifyListeners();

    try {
      final available = await _db.getAvailableBalanceKobo();
      if (_amountKobo > available) {
        final pending = await _db.getPendingDebitsKobo();
        _status = SendMoneyStatus.failure;
        _errorMessage = pending > 0
            ? 'You have ${MoneyFormatter.formatKobo(available)} available. '
                '${MoneyFormatter.formatKobo(pending)} is pending sync from an '
                'earlier offline transaction.'
            : 'Insufficient balance.';
        notifyListeners();
        return;
      }

      if (_amountKobo >= kBiometricThresholdKobo) {
        final ok = await _biometrics.authenticate(
          reason: 'Confirm your identity to send '
              '${MoneyFormatter.formatKobo(_amountKobo)}',
        );
        if (!ok) {
          _status = SendMoneyStatus.failure;
          _errorMessage = 'Authentication cancelled. Transfer not sent.';
          notifyListeners();
          return;
        }
      }

      final online = await _connectivity.checkOnline();

      if (!online) {
        await _queueOffline();
        return;
      }

      await _sendOnline();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> _queueOffline() async {
    await _db.enqueue(OfflineActionsTableCompanion.insert(
      id: _idempotencyKey,
      actionType: 'send_money',
      payloadJson: jsonEncode({
        'toAccount': _toAccount,
        'recipientName': _recipientName,
        'bankName': _bankName,
        'amountKobo': _amountKobo,
        'narration': _narration,
      }),
      status: 'pending',
      debitAmountKobo: Value(_amountKobo),
      createdAt: DateTime.now(),
    ));

    await _db.into(_db.transactionsTable).insertOnConflictUpdate(
          TransactionsTableCompanion.insert(
            id: _idempotencyKey,
            description: 'Transfer to $_recipientName',
            amountKobo: _amountKobo,
            type: 'debit',
            timestamp: DateTime.now(),
            settlementState: const Value('pending'),
          ),
        );

    _status = SendMoneyStatus.queued;
    notifyListeners();
  }

  Future<void> _sendOnline() async {
    _status = SendMoneyStatus.processing;
    notifyListeners();

    try {
      final response = await _dio.dio.post<Map<String, dynamic>>(
        '/transfers',
        data: {
          'idempotencyKey': _idempotencyKey,
          'toAccount': _toAccount,
          'recipientName': _recipientName,
          'bankName': _bankName,
          'amountKobo': _amountKobo,
          'narration': _narration,
        },
        options: Options(headers: {'Idempotency-Key': _idempotencyKey}),
      );

      final data = response.data!;
      _transactionRef = data['transactionRef'] as String;

      await _db.applySendOnce(
        idempotencyKey: _idempotencyKey,
        description: 'Transfer to $_recipientName',
        amountKobo: _amountKobo,
        reference: _transactionRef,
      );

      _status = SendMoneyStatus.success;
    } on DioException catch (e) {
      if (e.response != null) {
        _errorMessage = e.response?.statusCode == 402
            ? 'Insufficient balance.'
            : 'Transfer failed. Please try again.';
        _status = SendMoneyStatus.failure;
        notifyListeners();
        return;
      }
      await _queueOffline();
      return;
    } catch (_) {
      _errorMessage = 'Transfer failed. Please try again.';
      _status = SendMoneyStatus.failure;
    }

    notifyListeners();
  }

  void reset() {
    _status = SendMoneyStatus.initial;
    _toAccount = '';
    _recipientName = '';
    _bankName = '';
    _amountKobo = 0;
    _narration = '';
    _transactionRef = '';
    _errorMessage = '';
    notifyListeners();
  }
}
