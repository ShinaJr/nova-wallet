import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../providers/send_money_provider.dart';

class ResultPage extends StatefulWidget {
  const ResultPage({super.key});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  late final SendMoneyStatus _status;
  late final int _amountKobo;
  late final String _transactionRef;
  late final String _errorMessage;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SendMoneyProvider>();
    _status = provider.status;
    _amountKobo = provider.amountKobo;
    _transactionRef = provider.transactionRef;
    _errorMessage = provider.errorMessage;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (icon, color, title, subtitle) = switch (_status) {
      SendMoneyStatus.success => (
          Icons.check_circle,
          AppColors.success,
          l10n.transferSuccessful,
          l10n.referenceLabel(_transactionRef),
        ),
      SendMoneyStatus.queued => (
          Icons.schedule_send,
          AppColors.warning,
          l10n.pendingTitle,
          l10n.pendingSubtitle,
        ),
      _ => (
          Icons.error,
          AppColors.danger,
          l10n.transferFailed,
          _errorMessage,
        ),
    };

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 64),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                MoneyFormatter.formatKobo(_amountKobo),
                style: const TextStyle(fontSize: 15, color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () {
                  final provider = context.read<SendMoneyProvider>();
                  final walletProvider = context.read<WalletProvider>();
                  Navigator.popUntil(context, (r) => r.isFirst);
                  provider.reset();
                  walletProvider.refreshLocalOnly();
                },
                child: Text(l10n.done),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
