import 'dart:convert';

import 'package:dio/dio.dart';
import '../database/app_database.dart';
import '../money/money_formatter.dart';
import '../network/dio_client.dart';
import '../notifications/notification_service.dart';
import 'failure_policy.dart';

enum SyncOutcome {
  idle,
  completed,
  haltedInsufficientFunds,
  partialRetryPending
}

class SyncReport {
  final SyncOutcome outcome;
  final int succeeded;
  final int blocked;
  final int stillQueued;
  const SyncReport({
    required this.outcome,
    this.succeeded = 0,
    this.blocked = 0,
    this.stillQueued = 0,
  });
}

class QueueSyncService {
  final AppDatabase _db;
  final DioClient _dio;
  final NotificationService _notifications;

  bool _isSyncing = false;

  QueueSyncService({
    required AppDatabase db,
    required DioClient dio,
    required NotificationService notifications,
  })  : _db = db,
        _dio = dio,
        _notifications = notifications;

  Future<SyncReport> sync() async {
    if (_isSyncing) return const SyncReport(outcome: SyncOutcome.idle);
    _isSyncing = true;

    try {
      await _refreshLedgerBalance();
      await _preflightValidateQueue();
      final report = await _dispatchLoop();
      await _refreshLedgerBalance();
      await _db.pruneCompletedOlderThan(const Duration(days: 7));
      await _db.capTransactionHistory(keep: 200);
      return report;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _refreshLedgerBalance() async {
    try {
      final res = await _dio.dio.get<Map<String, dynamic>>('/wallet/balance');
      final data = res.data!;
      final wallet = await _db.getWallet();
      await _db.upsertWallet(WalletTableCompanion.insert(
        id: wallet?.id ?? 'primary',
        accountName: data['accountName'] as String,
        accountNumber: data['accountNumber'] as String,
        ledgerBalanceKobo: data['balanceKobo'] as int,
        lastSyncedAt: DateTime.now(),
      ));
    } catch (_) {}
  }

  Future<void> _preflightValidateQueue() async {
    final wallet = await _db.getWallet();
    if (wallet == null) return;

    var runningBalance = wallet.ledgerBalanceKobo;
    final queue = await _db.getDispatchableActions();

    for (final action in queue) {
      if (action.debitAmountKobo > runningBalance) {
        await _db.setStatus(
          action.id,
          'blockedInsufficientFunds',
          error: 'Insufficient balance at sync time',
          failureClass: 'insufficientFunds',
        );
        break;
      }
      runningBalance -= action.debitAmountKobo;
    }
  }

  Future<SyncReport> _dispatchLoop() async {
    final queue = await _db.getDispatchableActions();
    var succeeded = 0;

    for (final action in queue) {
      await _db.setStatus(action.id, 'processing');

      try {
        await _send(action);
        await _applyLocally(action);
        await _db.setStatus(action.id, 'completed');
        succeeded++;
        await _notifyCompleted(action);
      } catch (e) {
        final klass = FailurePolicy.classify(e);

        switch (klass) {
          case FailureClass.insufficientFunds:
            await _db.setStatus(
              action.id,
              'blockedInsufficientFunds',
              error: 'Insufficient balance',
              failureClass: 'insufficientFunds',
            );
            final remaining = (await _db.getDispatchableActions()).length;
            await _notifications.show(
              'Queued transfers on hold',
              'Not enough balance to complete a queued transfer. '
                  'Fund your wallet and retry from the Pending screen.',
            );
            return SyncReport(
              outcome: SyncOutcome.haltedInsufficientFunds,
              succeeded: succeeded,
              blocked: 1,
              stillQueued: remaining,
            );

          case FailureClass.permanent:
            await _db.setStatus(
              action.id,
              'rejected',
              error: _messageOf(e),
              failureClass: 'permanent',
            );
            continue;

          case FailureClass.retryable:
            final attempts = action.attempts + 1;
            if (attempts >= FailurePolicy.maxAttempts) {
              await _db.setStatus(
                action.id,
                'failedFinal',
                error: _messageOf(e),
                failureClass: 'retryable',
                attempts: attempts,
              );
            } else {
              await _db.setStatus(
                action.id,
                'failedRetryable',
                error: _messageOf(e),
                failureClass: 'retryable',
                attempts: attempts,
                nextAttemptAt:
                    DateTime.now().add(FailurePolicy.backoffFor(attempts)),
              );
            }
            continue;
        }
      }
    }

    final remaining = await _db.getDispatchableActions();
    return SyncReport(
      outcome: remaining.isNotEmpty
          ? SyncOutcome.partialRetryPending
          : SyncOutcome.completed,
      succeeded: succeeded,
      stillQueued: remaining.length,
    );
  }

  Future<void> _send(OfflineActionsTableData action) async {
    final payload = action.payloadJson;
    final map = _decode(payload);

    switch (action.actionType) {
      case 'send_money':
        await _dio.dio.post<Map<String, dynamic>>(
          '/transfers',
          data: {
            'idempotencyKey': action.id,
            'toAccount': map['toAccount'],
            'recipientName': map['recipientName'],
            'bankName': map['bankName'],
            'amountKobo': map['amountKobo'],
            'narration': map['narration'] ?? '',
          },
          options: Options(headers: {'Idempotency-Key': action.id}),
        );
        break;

      case 'contribute_to_goal':
        await _dio.dio.post<Map<String, dynamic>>(
          '/savings/goals/${map['goalId']}/contribute',
          data: {
            'idempotencyKey': action.id,
            'amountKobo': map['amountKobo'],
          },
          options: Options(headers: {'Idempotency-Key': action.id}),
        );
        break;
    }
  }

  Future<void> _applyLocally(OfflineActionsTableData action) async {
    final map = _decode(action.payloadJson);
    if (action.actionType == 'send_money') {
      await _db.applySendOnce(
        idempotencyKey: action.id,
        description: 'Transfer to ${map['recipientName']}',
        amountKobo: map['amountKobo'] as int,
      );
    } else {
      await _db.applyContributionOnce(
        idempotencyKey: action.id,
        goalId: map['goalId'] as String,
        amountKobo: map['amountKobo'] as int,
      );
    }
  }

  Future<void> _notifyCompleted(OfflineActionsTableData action) async {
    final map = _decode(action.payloadJson);
    final amount = MoneyFormatter.formatKobo(map['amountKobo'] as int);
    if (action.actionType == 'send_money') {
      await _notifications.show(
        'Transfer sent',
        '$amount to ${map['recipientName']} has been sent.',
      );
    } else {
      await _notifications.show(
        'Savings contribution sent',
        '$amount added to "${map['goalName']}".',
      );
    }
  }

  Map<String, dynamic> _decode(String json) =>
      jsonDecode(json) as Map<String, dynamic>;

  String _messageOf(Object e) =>
      e is DioException ? (e.message ?? e.toString()) : e.toString();
}
