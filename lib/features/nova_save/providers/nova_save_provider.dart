import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/network/dio_client.dart';

enum NovaSaveStatus {
  initial,
  loading,
  loaded,
  processing,
  queued,
  success,
  failure
}

class NovaSaveProvider extends ChangeNotifier {
  final DioClient _dio;
  final AppDatabase _db;
  final ConnectivityService _connectivity;

  List<SavingsGoalsTableData> _goals = const [];
  NovaSaveStatus _status = NovaSaveStatus.initial;
  String _error = '';
  String _successMessage = '';
  bool _isSubmitting = false;

  List<SavingsGoalsTableData> get goals => _goals;
  NovaSaveStatus get status => _status;
  String get error => _error;
  String get successMessage => _successMessage;
  bool get isSubmitting => _isSubmitting;

  NovaSaveProvider({
    required DioClient dio,
    required AppDatabase db,
    required ConnectivityService connectivity,
  })  : _dio = dio,
        _db = db,
        _connectivity = connectivity;

  Future<void> loadGoals() async {
    _status = NovaSaveStatus.loading;
    notifyListeners();
    _goals = await _db.getAllGoals();
    _status = NovaSaveStatus.loaded;
    notifyListeners();
  }

  Future<void> createGoal({
    required String name,
    required int targetAmountKobo,
    required DateTime targetDate,
  }) async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    _status = NovaSaveStatus.processing;
    notifyListeners();

    try {
      final goalId = const Uuid().v4();
      await _db.insertGoal(SavingsGoalsTableCompanion.insert(
        id: goalId,
        name: name,
        targetAmountKobo: targetAmountKobo,
        targetDate: targetDate,
        createdAt: DateTime.now(),
      ));

      if (await _connectivity.checkOnline()) {
        await _dio.dio.post<Map<String, dynamic>>('/savings/goals', data: {
          'id': goalId,
          'name': name,
          'targetAmountKobo': targetAmountKobo,
          'targetDate': targetDate.toIso8601String(),
        });
      }

      await loadGoals();
      _successMessage = 'Goal "$name" created!';
      _status = NovaSaveStatus.success;
    } catch (_) {
      _error = 'Could not create goal. Try again.';
      _status = NovaSaveStatus.failure;
    } finally {
      _isSubmitting = false;
    }
    notifyListeners();
  }

  Future<void> contribute({
    required SavingsGoalsTableData goal,
    required int amountKobo,
  }) async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    notifyListeners();

    try {
      final available = await _db.getAvailableBalanceKobo();
      if (amountKobo > available) {
        _status = NovaSaveStatus.failure;
        _error = 'You have ${MoneyFormatter.formatKobo(available)} available.';
        notifyListeners();
        return;
      }

      final idempotencyKey = const Uuid().v4();
      final isOnline = await _connectivity.checkOnline();

      if (!isOnline) {
        await _queueOffline(
            goal: goal, amountKobo: amountKobo, idempotencyKey: idempotencyKey);
        return;
      }

      _status = NovaSaveStatus.processing;
      notifyListeners();

      try {
        final key = idempotencyKey;
        await _dio.dio.post<Map<String, dynamic>>(
          '/savings/goals/${goal.id}/contribute',
          data: {'idempotencyKey': key, 'amountKobo': amountKobo},
          options: Options(headers: {'Idempotency-Key': key}),
        );
        await _db.applyContributionOnce(
          idempotencyKey: key,
          goalId: goal.id,
          amountKobo: amountKobo,
        );
        await loadGoals();
        _successMessage =
            '${MoneyFormatter.formatKobo(amountKobo)} added to "${goal.name}"!';
        _status = NovaSaveStatus.success;
      } on DioException catch (e) {
        if (e.response != null) {
          _error = e.response?.statusCode == 402
              ? 'Insufficient balance.'
              : 'Contribution failed. Please try again.';
          _status = NovaSaveStatus.failure;
          notifyListeners();
          return;
        }
        await _queueOffline(
            goal: goal, amountKobo: amountKobo, idempotencyKey: idempotencyKey);
        return;
      } catch (_) {
        _error = 'Contribution failed. Please try again.';
        _status = NovaSaveStatus.failure;
      }
      notifyListeners();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> _queueOffline({
    required SavingsGoalsTableData goal,
    required int amountKobo,
    required String idempotencyKey,
  }) async {
    await _db.enqueue(OfflineActionsTableCompanion.insert(
      id: idempotencyKey,
      actionType: 'contribute_to_goal',
      payloadJson: jsonEncode({
        'goalId': goal.id,
        'goalName': goal.name,
        'amountKobo': amountKobo,
      }),
      status: 'pending',
      debitAmountKobo: Value(amountKobo),
      createdAt: DateTime.now(),
    ));

    await _db.into(_db.transactionsTable).insertOnConflictUpdate(
          TransactionsTableCompanion.insert(
            id: idempotencyKey,
            description: 'NovaSave contribution — ${goal.name}',
            amountKobo: amountKobo,
            type: 'debit',
            timestamp: DateTime.now(),
            settlementState: const Value('pending'),
          ),
        );

    _status = NovaSaveStatus.queued;
    _successMessage = 'Contribution queued — will sync when back online.';
    notifyListeners();
  }

  void resetStatus() {
    _status = NovaSaveStatus.loaded;
    _error = '';
    _successMessage = '';
    notifyListeners();
  }
}
