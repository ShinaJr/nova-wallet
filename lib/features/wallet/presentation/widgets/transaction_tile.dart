import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/theme/app_theme.dart';

class TransactionTile extends StatelessWidget {
  final TransactionsTableData transaction;
  const TransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.type == 'credit';
    final isPending = transaction.settlementState == 'pending';
    final isSavings = transaction.description.startsWith('NovaSave');
    final amount = MoneyFormatter.formatKobo(transaction.amountKobo);
    final pendingVerb = isSavings ? 'save' : 'send';

    return Semantics(
      label: '${transaction.description}, '
          '${isCredit ? 'credit' : 'debit'} $amount'
          '${isPending ? ', pending, will $pendingVerb when back online' : ''}',
      excludeSemantics: true,
      child: Container(
        height: 76,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isPending
                ? AppColors.warning.withOpacity(0.4)
                : AppColors.hairline,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isCredit
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.danger.withOpacity(0.1),
              child: Icon(
                isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                color: isCredit ? AppColors.success : AppColors.danger,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  if (isPending)
                    Text(
                      'Pending — will $pendingVerb when back online',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.warning),
                    )
                  else
                    Text(
                      _formatDate(transaction.timestamp),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.inkMuted),
                    ),
                ],
              ),
            ),
            Text(
              '${isCredit ? '+' : '-'}$amount',
              style: TextStyle(
                color: isCredit ? AppColors.success : AppColors.danger,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
