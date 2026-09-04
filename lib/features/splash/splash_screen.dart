import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/primitives.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          // A slow gold bloom behind the mark.
          Positioned.fill(
            child:
                DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(0, -0.15),
                          radius: 0.9,
                          colors: [Color(0x22F1A83B), Colors.transparent],
                        ),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fadeIn(duration: 1400.ms)
                    .then()
                    .scaleXY(begin: 1, end: 1.12, duration: 2600.ms),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 96)
                    .animate()
                    .fadeIn(duration: 700.ms)
                    .scale(
                      begin: const Offset(0.7, 0.7),
                      duration: 900.ms,
                      curve: Curves.easeOutBack,
                    )
                    .then()
                    .rotate(begin: 0, end: 1, duration: 1200.ms, curve: Curves.easeInOutCubic),
                const SizedBox(height: AppSpacing.xl),
                const BrandWordmark(width: 180)
                    .animate(delay: 500.ms)
                    .fadeIn(duration: 700.ms)
                    .slideY(begin: 0.2, curve: Curves.easeOutCubic),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 56,
            child: Column(
              children: [
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: AppColors.surfaceAlt,
                      valueColor: AlwaysStoppedAnimation(AppColors.gold),
                    ),
                  ),
                ).animate(delay: 900.ms).fadeIn(),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Secured by ${AppConfig.appName}',
                  style: TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 1.2,
                    color: AppColors.textTertiary,
                  ),
                ).animate(delay: 1100.ms).fadeIn(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
