import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/queue/queue_sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../nova_save/providers/nova_save_provider.dart';
import '../../wallet/providers/wallet_provider.dart';
import 'package:provider/provider.dart';

class PendingQueuePage extends StatelessWidget {
  const PendingQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = GetIt.instance<AppDatabase>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync now',
            onPressed: () async {
              final walletProvider = context.read<WalletProvider>();
              final novaSaveProvider = context.read<NovaSaveProvider>();
              final isOnline =
                  await GetIt.instance<ConnectivityService>().checkOnline();
              if (!isOnline) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "You're still offline — this will sync automatically once you're back online.",
                      ),
                    ),
                  );
                }
                return;
              }
              await GetIt.instance<QueueSyncService>().sync();
              await walletProvider.refreshLocalOnly();
              await novaSaveProvider.loadGoals();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<OfflineActionsTableData>>(
        stream: db.watchVisibleQueue(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'Nothing queued.\nEverything is synced.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkMuted),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: items.length,
            itemBuilder: (context, index) =>
                _QueueTile(action: items[index], db: db),
          );
        },
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final OfflineActionsTableData action;
  final AppDatabase db;
  const _QueueTile({required this.action, required this.db});

  @override
  Widget build(BuildContext context) {
    final payload = jsonDecode(action.payloadJson) as Map<String, dynamic>;
    final amountKobo = payload['amountKobo'] as int? ?? 0;
    final title = action.actionType == 'send_money'
        ? 'Send to ${payload['recipientName']}'
        : 'Contribute to "${payload['goalName']}"';

    final (label, color) = switch (action.status) {
      'pending' => ('Pending', AppColors.inkMuted),
      'processing' => ('Sending…', AppColors.navy),
      'failedRetryable' => (
          'Retrying (${action.attempts}/5)',
          AppColors.warning
        ),
      'failedFinal' => ('Failed', AppColors.danger),
      'blockedInsufficientFunds' => (
          'On hold — insufficient balance',
          AppColors.danger
        ),
      'rejected' => ('Rejected', AppColors.danger),
      _ => (action.status, AppColors.inkMuted),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(
                MoneyFormatter.formatKobo(amountKobo),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          if (action.status == 'blockedInsufficientFunds') ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                TextButton(
                  onPressed: () async {
                    final walletProvider = context.read<WalletProvider>();
                    final novaSaveProvider = context.read<NovaSaveProvider>();
                    await db.unblockInsufficientFunds();
                    await GetIt.instance<QueueSyncService>().sync();
                    await walletProvider.refreshLocalOnly();
                    await novaSaveProvider.loadGoals();
                  },
                  child: const Text('Retry now'),
                ),
                TextButton(
                  onPressed: () => db.cancelAction(action.id),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
