import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/send_money_provider.dart';
import 'amount_page.dart';

class RecipientPage extends StatefulWidget {
  const RecipientPage({super.key});

  @override
  State<RecipientPage> createState() => _RecipientPageState();
}

class _RecipientPageState extends State<RecipientPage> {
  final _accountController = TextEditingController();
  String _bankName = 'GTBank';
  String? _resolvedName;
  bool _isResolving = false;
  bool _navigated = false;

  static const _banks = [
    'GTBank',
    'Zenith Bank',
    'Access Bank',
    'UBA',
    'First Bank',
  ];

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _resolveRecipient() async {
    final account = _accountController.text.trim();
    if (account.length != 10) return;
    setState(() => _isResolving = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _resolvedName = account.endsWith('0') ? 'Adaobi Okafor' : 'Emeka Nwosu';
      _isResolving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sendMoney)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.recipient,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              label: l10n.recipientAccountHint,
              textField: true,
              child: TextField(
                controller: _accountController,
                keyboardType: TextInputType.number,
                maxLength: 10,
                decoration: InputDecoration(
                  labelText: l10n.accountNumber,
                  counterText: '',
                ),
                onChanged: (_) => _resolveRecipient(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              value: _bankName,
              decoration: InputDecoration(labelText: l10n.bankName),
              items: _banks
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) => setState(() => _bankName = v ?? _bankName),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_isResolving)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(l10n.lookingUpAccount),
                  ],
                ),
              )
            else if (_resolvedName != null)
              Semantics(
                label: l10n.recipientFound(_resolvedName!),
                excludeSemantics: true,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppColors.success, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        _resolvedName!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _resolvedName == null
                  ? null
                  : () {
                      if (_navigated) return;
                      _navigated = true;
                      context.read<SendMoneyProvider>().selectRecipient(
                            account: _accountController.text.trim(),
                            name: _resolvedName!,
                            bank: _bankName,
                          );
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AmountPage()),
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
