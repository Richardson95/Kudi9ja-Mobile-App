import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/platform_settings.dart';
import '../../widgets/primitives.dart';

/// Picks a repayment period anywhere from one month to the platform maximum.
///
/// Every tenure is priced separately, so the rate for the tenure under the
/// thumb is shown as it moves: choosing a period is choosing a price, and a
/// borrower should never make that choice blind. Chips would not fit two
/// years of options on a phone, which is why this is a slider.
class TenureSlider extends StatelessWidget {
  const TenureSlider({
    super.key,
    required this.tenure,
    required this.onChanged,
  });

  final int tenure;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final max = settings.maxLoanTenureMonths;
    final months = tenure.clamp(1, max);
    final perMonth = settings.loanRatePctFor(months) / months;

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '$months ${months == 1 ? 'month' : 'months'}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              StatusPill(
                label: '${settings.loanRateLabelFor(months)} FLAT',
                color: AppColors.gold,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${perMonth.toStringAsFixed(2)}% a month',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppColors.gold,
              inactiveTrackColor: AppColors.surfaceHigh,
              thumbColor: AppColors.gold,
              overlayColor: AppColors.goldWash,
            ),
            child: Slider(
              value: months.toDouble(),
              min: 1,
              max: max.toDouble(),
              divisions: max > 1 ? max - 1 : null,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1 month',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
              Text(
                max % 12 == 0
                    ? '${max ~/ 12} ${max == 12 ? 'year' : 'years'}'
                    : '$max months',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
