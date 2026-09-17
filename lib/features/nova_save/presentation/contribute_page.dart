import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/money/thousands_separator_formatter.dart';
import '../../../core/theme/app_theme.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../providers/nova_save_provider.dart';

class ContributePage extends StatefulWidget {
  final SavingsGoalsTableData goal;
  const ContributePage({super.key, required this.goal});

  @override
  State<ContributePage> createState() => _ContributePageState();
}

class _ContributePageState extends State<ContributePage> {
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NovaSaveProvider>();
    final isOnline = context.watch<ConnectivityService>().isOnline;
    final amountKobo = MoneyFormatter.parseToKobo(_amountController.text);
    final ratio = MoneyFormatter.progressRatio(
      widget.goal.contributedAmountKobo,
      widget.goal.targetAmountKobo,
    );
    final remainingKobo =
        widget.goal.targetAmountKobo - widget.goal.contributedAmountKobo;
    final overTarget = amountKobo > remainingKobo;

    if (provider.status == NovaSaveStatus.success ||
        provider.status == NovaSaveStatus.queued) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<WalletProvider>().refreshLocalOnly();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.successMessage)),
        );
        provider.resetStatus();
        Navigator.pop(context);
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.goal.name)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: AppColors.hairline,
                valueColor: const AlwaysStoppedAnimation(AppColors.gold),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${MoneyFormatter.formatKobo(widget.goal.contributedAmountKobo)} of '
              '${MoneyFormatter.formatKobo(widget.goal.targetAmountKobo)}',
              style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [ThousandsSeparatorFormatter()],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Contribution amount',
                prefixText: '₦ ',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${MoneyFormatter.formatKobo(remainingKobo < 0 ? 0 : remainingKobo)} left to reach this goal',
              style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
            if (overTarget) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Text(
                  'This exceeds what\'s left to reach the goal.',
                  style: TextStyle(fontSize: 12, color: AppColors.danger),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (!isOnline)
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Text(
                  "You're offline. This contribution will be queued and "
                  'sent automatically when you reconnect.',
                  style: TextStyle(fontSize: 12, color: AppColors.warning),
                ),
              ),
            if (provider.status == NovaSaveStatus.failure) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                provider.error,
                style: const TextStyle(fontSize: 12, color: AppColors.danger),
              ),
            ],
            const Spacer(),
            FilledButton(
              onPressed:
                  (amountKobo <= 0 || overTarget || provider.isSubmitting)
                      ? null
                      : () => provider.contribute(
                            goal: widget.goal,
                            amountKobo: amountKobo,
                          ),
              child: provider.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Contribute'),
            ),
          ],
        ),
      ),
    );
  }
}
