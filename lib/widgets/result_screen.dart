import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import 'primitives.dart';

/// Full-screen confirmation shown after a successful money action.
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.title,
    required this.message,
    this.details = const [],
    this.primaryLabel = 'Done',
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.success = true,
  });

  final String title;
  final String message;
  final List<(String, String)> details;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final accent = success ? AppColors.success : AppColors.danger;
    HapticFeedback.heavyImpact();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accent.withValues(alpha: 0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: success
                              ? AppColors.successGradient
                              : LinearGradient(
                                  colors: [
                                    AppColors.danger,
                                    Color(0xFFCF4545),
                                  ],
                                ),
                        ),
                        child: Icon(
                          success
                              ? Icons.check_rounded
                              : Icons.priority_high_rounded,
                          size: 38,
                          color: Colors.white,
                        ),
                      ),
                    )
                    .animate()
                    .scale(
                      duration: 420.ms,
                      curve: Curves.elasticOut,
                      begin: const Offset(0.4, 0.4),
                    )
                    .fadeIn(duration: 220.ms),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ).animate(delay: 160.ms).fadeIn().slideY(begin: 0.25),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ).animate(delay: 240.ms).fadeIn().slideY(begin: 0.25),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  KCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < details.length; i++) ...[
                          if (i > 0)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: HairLine(),
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                details[i].$1,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  details[i].$2,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ).animate(delay: 320.ms).fadeIn().slideY(begin: 0.2),
                ],
                const Spacer(flex: 3),
                GoldButton(
                  label: primaryLabel,
                  onPressed:
                      onPrimary ??
                      () => Navigator.of(context).popUntil((r) => r.isFirst),
                ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.3),
                if (secondaryLabel != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  GhostButton(label: secondaryLabel!, onPressed: onSecondary)
                      .animate(delay: 460.ms)
                      .fadeIn(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
