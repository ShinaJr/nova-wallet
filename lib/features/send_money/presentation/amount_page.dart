import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/money/thousands_separator_formatter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/send_money_provider.dart';
import 'confirm_page.dart';

class AmountPage extends StatefulWidget {
  const AmountPage({super.key});

  @override
  State<AmountPage> createState() => _AmountPageState();
}

class _AmountPageState extends State<AmountPage> {
  final _amountController = TextEditingController();
  final _narrationController = TextEditingController();
  int? _availableKobo;
  int _enteredKobo = 0;
  bool _navigated = false;

  static const _quickAmountsKobo = [100000, 500000, 1000000, 2000000];

  @override
  void initState() {
    super.initState();
    context.read<SendMoneyProvider>().availableBalanceKobo().then((v) {
      if (mounted) setState(() => _availableKobo = v);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _narrationController.dispose();
    super.dispose();
  }

  bool get _overAvailable =>
      _availableKobo != null && _enteredKobo > _availableKobo!;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SendMoneyProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sendTo(provider.recipientName))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: l10n.amountToSendLabel,
              textField: true,
              child: TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [ThousandsSeparatorFormatter()],
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: l10n.amount,
                  prefixText: '₦ ',
                ),
                onChanged: (v) {
                  setState(() => _enteredKobo = MoneyFormatter.parseToKobo(v));
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (_availableKobo != null)
              Text(
                l10n.availableAmount(
                    MoneyFormatter.formatKobo(_availableKobo!)),
                style: TextStyle(
                  fontSize: 12,
                  color: _overAvailable ? AppColors.danger : AppColors.inkMuted,
                  fontWeight:
                      _overAvailable ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              children: _quickAmountsKobo.map((kobo) {
                return ActionChip(
                  label: Text(MoneyFormatter.formatKobo(kobo)),
                  onPressed: () {
                    _amountController.text =
                        ThousandsSeparatorFormatter.formatKoboForField(kobo);
                    setState(() => _enteredKobo = kobo);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _narrationController,
              decoration: InputDecoration(labelText: l10n.narration),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_overAvailable)
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  l10n.exceedsAvailableBalance,
                  style: const TextStyle(fontSize: 12, color: AppColors.danger),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: (_enteredKobo <= 0 || _overAvailable)
                  ? null
                  : () {
                      if (_navigated) return;
                      _navigated = true;
                      provider.enterAmount(
                        amountKobo: _enteredKobo,
                        narration: _narrationController.text.trim(),
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ConfirmPage()),
                      );
                    },
              child: Text(l10n.continueLabel),
            ),
          ],
        ),
      ),
    );
  }
}
