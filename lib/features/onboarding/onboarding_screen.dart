import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';

class _Slide {
  const _Slide(this.icon, this.eyebrow, this.title, this.body, this.stat, this.statLabel);
  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final String stat;
  final String statLabel;
}

const _slides = <_Slide>[
  _Slide(
    Icons.savings_outlined,
    'SAVE',
    'Earn 17%.\nPaid upfront.',
    'Lock any amount from one month to five years and we credit your full return the same second the plan starts. No waiting for maturity.',
    '17%',
    'per annum, paid instantly',
  ),
  _Slide(
    Icons.account_balance_wallet_outlined,
    'BORROW',
    'Credit that moves\nat your speed.',
    'Access up to ₦500,000 with a transparent flat rate, a clear repayment plan and money in your wallet in minutes — not days.',
    '₦500k',
    'maximum credit line',
  ),
  _Slide(
    Icons.verified_user_outlined,
    'PROTECT',
    'Locked behind\nyour passcode.',
    'BVN and NIN verification at signup, a six-digit passcode every time you open the app, and a separate PIN for every naira that moves.',
    '2 keys',
    'sign-in passcode + transaction PIN',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pager = PageController();
  int _index = 0;

  bool get _isLast => _index == _slides.length - 1;

  void _next() {
    if (_isLast) {
      context.read<AppState>().completeOnboarding();
    } else {
      _pager.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                child: Row(
                  children: [
                    const BrandWordmark(width: 116),
                    const Spacer(),
                    if (!_isLast)
                      TextButton(
                        onPressed: () =>
                            context.read<AppState>().completeOnboarding(),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pager,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (i) {
                        final on = i == _index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 5,
                          width: on ? 26 : 8,
                          decoration: BoxDecoration(
                            color: on ? AppColors.gold : AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(9),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    GoldButton(
                      label: _isLast ? 'Get started' : 'Continue',
                      icon: _isLast ? Icons.arrow_forward_rounded : null,
                      onPressed: _next,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Licensed lender • Funds secured • CBN compliant',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.gold.withValues(alpha: 0.22),
                  AppColors.gold.withValues(alpha: 0.04),
                ],
              ),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Icon(slide.icon, size: 30, color: AppColors.gold),
          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8)),
          const SizedBox(height: AppSpacing.xl),
          Text(
            slide.eyebrow,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
              color: AppColors.gold,
            ),
          ).animate(delay: 80.ms).fadeIn().slideX(begin: -0.1),
          const SizedBox(height: AppSpacing.md),
          Text(
            slide.title,
            style: Theme.of(context).textTheme.displayMedium,
          ).animate(delay: 140.ms).fadeIn().slideY(begin: 0.18),
          const SizedBox(height: AppSpacing.lg),
          Text(
            slide.body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ).animate(delay: 220.ms).fadeIn().slideY(begin: 0.18),
          const SizedBox(height: AppSpacing.xxl),
          KCard(
            gradient: AppColors.cardGradient,
            borderColor: AppColors.gold.withValues(alpha: 0.18),
            child: Row(
              children: [
                Text(
                  slide.stat,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    slide.statLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
