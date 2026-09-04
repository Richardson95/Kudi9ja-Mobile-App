import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';

/// The hero wallet card: balance, account number, net worth and the
/// hide-balance toggle.
class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.user;
    if (user == null) return const SizedBox.shrink();

    final hidden = app.hideBalance;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: AppColors.cardGradient,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.10),
            blurRadius: 40,
            offset: const Offset(0, 16),
            spreadRadius: -14,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Soft gold bloom in the top-right corner.
          Positioned(
            right: -50,
            top: -60,
            child: Container(
              width: 190,
              height: 190,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x26F1A83B), Colors.transparent],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Wallet balance',
                      style: TextStyle(
                        fontSize: 12.5,
                        letterSpacing: 0.3,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        app.toggleHideBalance();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          hidden
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const BrandMark(size: 26),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: Text(
                    hidden ? '••••••••' : app.balance.asNaira,
                    key: ValueKey(hidden ? 'hidden' : app.balance),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _Sub(
                        label: 'Net worth',
                        value: hidden ? '••••' : app.netWorth.asShortNaira,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: AppColors.strokeSoft,
                    ),
                    // What the money has actually made. A credit score sat
                    // here before, but it says nothing about the wallet this
                    // card is for — it belongs with borrowing, and lives on
                    // the Loans tab and in Profile.
                    Expanded(
                      child: _Sub(
                        label: 'Earned so far',
                        value: hidden
                            ? '••••'
                            : app.totalInterestEarned.asShortNaira,
                        valueColor: app.totalInterestEarned > 0
                            ? AppColors.success
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const HairLine(),
                const SizedBox(height: AppSpacing.md),
                // Kudi9ja issues no account number. What matters here is
                // where money leaves to, so that is what we show.
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_outlined,
                      size: 15,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        user.hasPayoutAccount
                            ? 'Pays out to ${user.payoutBank} • '
                                  '${user.payoutAccountNumber}'
                            : 'No payout account set',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: user.hasPayoutAccount
                              ? AppColors.textSecondary
                              : AppColors.gold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sub extends StatelessWidget {
  const _Sub({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;

  /// Tints the figure — used to mark money gained.
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: valueColor ?? AppColors.textPrimary,
        ),
      ),
    ],
  );
}
