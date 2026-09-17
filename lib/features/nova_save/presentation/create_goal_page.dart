import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/money/thousands_separator_formatter.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/nova_save_provider.dart';

class CreateGoalPage extends StatefulWidget {
  const CreateGoalPage({super.key});

  @override
  State<CreateGoalPage> createState() => _CreateGoalPageState();
}

class _CreateGoalPageState extends State<CreateGoalPage> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  DateTime _targetDate = DateTime.now().add(const Duration(days: 90));

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NovaSaveProvider>();
    final targetKobo = MoneyFormatter.parseToKobo(_targetController.text);

    return Scaffold(
      appBar: AppBar(title: const Text('New Savings Goal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Goal name'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _targetController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [ThousandsSeparatorFormatter()],
              decoration: const InputDecoration(
                labelText: 'Target amount',
                prefixText: '₦ ',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Target date'),
              subtitle: Text(
                '${_targetDate.day}/${_targetDate.month}/${_targetDate.year}',
              ),
              trailing: const Icon(Icons.calendar_today, size: 18),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _targetDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                );
                if (picked != null) setState(() => _targetDate = picked);
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: (_nameController.text.trim().isEmpty ||
                      targetKobo <= 0 ||
                      provider.isSubmitting)
                  ? null
                  : () async {
                      await provider.createGoal(
                        name: _nameController.text.trim(),
                        targetAmountKobo: targetKobo,
                        targetDate: _targetDate,
                      );
                      if (provider.status == NovaSaveStatus.success) {
                        provider.resetStatus();
                      }
                      if (context.mounted) Navigator.pop(context);
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
                  : const Text('Create Goal'),
            ),
          ],
        ),
      ),
    );
  }
}
