import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';

/// Who at Kudi9ja looks after this customer's loan: names only, as on the
/// web. The officers' email and phone stay with the team.
///
/// Nothing at all when nobody is assigned: a card saying "no officer" tells a
/// borrower nothing they can act on.
class LoanOfficersCard extends StatelessWidget {
  const LoanOfficersCard({super.key, this.bottomGap = AppSpacing.xl});

  final double bottomGap;

  @override
  Widget build(BuildContext context) {
    final officers = context.watch<AppState>().officers;
    if (officers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              officers.length > 1 ? 'YOUR LOAN OFFICERS' : 'YOUR LOAN OFFICER',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < officers.length; i++) ...[
              if (i > 0) const HairLine(indent: 52),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    IconBadge(icon: Icons.support_agent_rounded, size: 40),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  officers[i].name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (officers[i].lead) ...[
                                const SizedBox(width: AppSpacing.sm),
                                StatusPill(
                                  label: 'LEAD',
                                  color: AppColors.gold,
                                  dense: true,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'Looks after your loans',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
