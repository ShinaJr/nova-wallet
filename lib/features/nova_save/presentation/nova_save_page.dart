import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/nova_save_provider.dart';
import 'contribute_page.dart';
import 'create_goal_page.dart';

class NovaSavePage extends StatelessWidget {
  const NovaSavePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NovaSave')),
      body: Consumer<NovaSaveProvider>(
        builder: (context, provider, _) {
          if (provider.status == NovaSaveStatus.loading &&
              provider.goals.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.goals.isEmpty) {
            return const Center(
              child: Text(
                'No savings goals yet.\nTap + to create one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkMuted),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: provider.goals.length,
            itemExtent: 128,
            itemBuilder: (context, index) {
              final goal = provider.goals[index];
              final ratio = MoneyFormatter.progressRatio(
                goal.contributedAmountKobo,
                goal.targetAmountKobo,
              );
              return Semantics(
                button: true,
                label: '${goal.name}, '
                    '${MoneyFormatter.formatKobo(goal.contributedAmountKobo)} of '
                    '${MoneyFormatter.formatKobo(goal.targetAmountKobo)}, '
                    '${MoneyFormatter.progressPercent(goal.contributedAmountKobo, goal.targetAmountKobo)} complete',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ContributePage(goal: goal)),
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              goal.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              MoneyFormatter.progressPercent(
                                goal.contributedAmountKobo,
                                goal.targetAmountKobo,
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.navy,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 8,
                            backgroundColor: AppColors.hairline,
                            valueColor:
                                const AlwaysStoppedAnimation(AppColors.gold),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${MoneyFormatter.formatKobo(goal.contributedAmountKobo)} '
                          'of ${MoneyFormatter.formatKobo(goal.targetAmountKobo)}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateGoalPage()),
        ),
        backgroundColor: AppColors.navy,
        child: const Icon(Icons.add),
      ),
    );
  }
}
