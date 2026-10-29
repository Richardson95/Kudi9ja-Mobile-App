import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../data/models/loan_application.dart';
import 'primitives.dart';

/// What became of an application, on the screen where they asked for it.
///
/// Three states worth showing. One waiting says so plainly and repeats that
/// nothing has moved — a customer who thinks the money is coming today and
/// finds it is not has been misled by silence. One declined leads with the
/// reason, because the reason is the thing they can act on; everything else
/// about a refusal is noise. One with changed terms says where to answer
/// them, since nothing moves until they do.
class ApplicationBanner extends StatelessWidget {
  const ApplicationBanner({super.key, required this.application});

  final LoanApplication application;

  @override
  Widget build(BuildContext context) {
    final pending = application.isPending;
    final offered = application.isOffered;
    final accent = offered
        ? AppColors.info
        : pending
            ? AppColors.gold
            : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: KCard(
        borderColor: accent.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  offered
                      ? Icons.tune_rounded
                      : pending
                          ? Icons.hourglass_top_rounded
                          : Icons.info_outline_rounded,
                  size: 16,
                  color: accent,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    offered
                        ? 'New terms for your ${application.amount.asNaira} application'
                        : pending
                            ? 'Your ${application.amount.asNaira} application is with our team'
                            : 'Your ${application.amount.asNaira} application was declined',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              offered
                  ? 'Our team can offer it on changed terms. Open Borrow to '
                      'agree to them or turn them down. Nothing is lent until '
                      'you agree.'
                  : pending
                      ? 'We read the statement, the pictures and your guarantor '
                          'before deciding. Nothing has been added to your wallet yet.'
                      : application.rejectionReason,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            if (!pending && !offered) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Sort that out and you are welcome to apply again.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
