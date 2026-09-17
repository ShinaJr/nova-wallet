import 'package:flutter/material.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/theme/app_theme.dart';

class BalanceHeader extends StatelessWidget {
  final String accountName;
  final String accountNumber;
  final int ledgerKobo;
  final int pendingKobo;

  const BalanceHeader({
    super.key,
    required this.accountName,
    required this.accountNumber,
    required this.ledgerKobo,
    required this.pendingKobo,
  });

  int get availableKobo => ledgerKobo - pendingKobo;

  @override
  Widget build(BuildContext context) {
    final hasPending = pendingKobo > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navy, AppColors.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  child: Text(
                    accountName.isNotEmpty ? accountName[0] : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        accountName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        accountNumber,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Available to spend',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.75), fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.xs),
            Semantics(
              label: hasPending
                  ? 'Available to spend ${MoneyFormatter.formatKobo(availableKobo)}. '
                      'Total balance ${MoneyFormatter.formatKobo(ledgerKobo)}. '
                      '${MoneyFormatter.formatKobo(pendingKobo)} pending sync.'
                  : 'Available balance ${MoneyFormatter.formatKobo(availableKobo)}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      MoneyFormatter.formatKobo(availableKobo),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (hasPending) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(
                          'Balance ${MoneyFormatter.formatKobo(ledgerKobo)}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '${MoneyFormatter.formatKobo(pendingKobo)} pending',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
