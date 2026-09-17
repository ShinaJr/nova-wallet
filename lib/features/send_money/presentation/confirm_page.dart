import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/send_money_provider.dart';
import 'result_page.dart';

class ConfirmPage extends StatelessWidget {
  const ConfirmPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SendMoneyProvider>();
    final isOnline = context.watch<ConnectivityService>().isOnline;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.confirmTransfer)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row(l10n.to, provider.recipientName),
                    _row(l10n.bankName, provider.bankName),
                    _row(l10n.account, provider.toAccount),
                    const Divider(height: AppSpacing.lg),
                    _row(
                      l10n.amount,
                      MoneyFormatter.formatKobo(provider.amountKobo),
                      emphasize: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.idempotencyKeyLabel(provider.idempotencyKey),
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (!isOnline)
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off,
                        size: 16, color: AppColors.warning),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        l10n.offlineConfirmNotice,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            FilledButton(
              onPressed: provider.isSubmitting
                  ? null
                  : () async {
                      await provider.confirmSend();
                      if (!context.mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const ResultPage()),
                      );
                    },
              child: provider.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.confirmAndSend),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 18 : 14,
              fontWeight: emphasize ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
