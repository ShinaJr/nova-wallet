import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/locale/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../nova_save/presentation/nova_save_page.dart';
import '../../queue/presentation/pending_queue_page.dart';
import '../../send_money/presentation/recipient_page.dart';
import '../providers/wallet_provider.dart';
import 'widgets/balance_header.dart';
import 'widgets/transaction_tile.dart';

class WalletHomePage extends StatelessWidget {
  const WalletHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NovaWallet'),
        actions: [
          Consumer<LocaleController>(
            builder: (context, localeController, _) => Semantics(
              button: true,
              label: localeController.isYoruba
                  ? 'Switch to English'
                  : 'Yipada si Yoruba',
              child: TextButton(
                onPressed: localeController.toggle,
                child: Text(
                  localeController.isYoruba ? 'EN' : 'YO',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Consumer2<WalletProvider, ConnectivityService>(
        builder: (context, wallet, connectivity, _) {
          return RefreshIndicator(
            onRefresh: wallet.refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: BalanceHeader(
                    accountName: wallet.accountName,
                    accountNumber: wallet.accountNumber,
                    ledgerKobo: wallet.ledgerBalanceKobo,
                    pendingKobo: wallet.pendingDebitsKobo,
                  ),
                ),
                if (!connectivity.isOnline)
                  const SliverToBoxAdapter(child: _OfflineBanner()),
                SliverToBoxAdapter(child: _QuickActions()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == 0) {
                          return const Padding(
                            padding:
                                EdgeInsets.symmetric(vertical: AppSpacing.sm),
                            child: Text(
                              'Recent Transactions',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          );
                        }
                        if (wallet.isLoading && wallet.transactions.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (wallet.transactions.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'No transactions yet',
                                style: TextStyle(color: AppColors.inkMuted),
                              ),
                            ),
                          );
                        }
                        final txn = wallet.transactions[index - 1];
                        return TransactionTile(transaction: txn);
                      },
                      childCount: wallet.transactions.isEmpty
                          ? 2
                          : wallet.transactions.length + 1,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.warning.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Semantics(
        liveRegion: true,
        label: "You're offline. Sends and contributions will be queued "
            'and sent automatically when you reconnect.',
        excludeSemantics: true,
        child: Row(
          children: const [
            Icon(Icons.wifi_off, size: 16, color: AppColors.warning),
            SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                "You're offline — actions will be queued and sent automatically",
                style: TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Action(
            icon: Icons.send,
            label: 'Send',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecipientPage()),
            ),
          ),
          _Action(
            icon: Icons.savings,
            label: 'Save',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NovaSavePage()),
            ),
          ),
          _Action(
            icon: Icons.schedule_send,
            label: 'Pending',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PendingQueuePage()),
            ),
          ),
          _Action(icon: Icons.receipt_long, label: 'History', onTap: () {}),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Action({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.navy.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.navy, size: 22),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
