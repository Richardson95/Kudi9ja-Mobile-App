import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/admin.dart';
import '../../data/models/models.dart';
import '../../data/services/security_service.dart';
import '../../state/app_state.dart';
import '../../widgets/company_account.dart';
import '../../widgets/primitives.dart';
import '../shell/home_shell.dart';
import '../admin/admin_shell.dart';
import '../insights/insights_screen.dart';
import '../legal/legal_screen.dart';
import '../loans/credit_score_screen.dart';
import '../notifications/notifications_screen.dart';
import 'security_screen.dart';
import '../../data/models/platform_settings.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.user;
    if (user == null) return const SizedBox.shrink();

    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const TabHeader(title: 'Profile'),
          _ProfileCard(user: user).animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: AppSpacing.xl),
          _Group(
            title: 'SECURITY',
            children: [
              _Row(
                icon: Icons.lock_outline_rounded,
                label: 'Security & passcodes',
                sublabel: 'Passcode, PIN, biometrics',
                onTap: () => Navigator.of(
                  context,
                ).push(slideRoute(const SecurityScreen())),
              ),
              _SwitchRow(
                icon: Icons.visibility_off_outlined,
                label: 'Hide balances by default',
                value: app.hideBalance,
                onChanged: (_) => app.toggleHideBalance(),
              ),
            ],
          ),
          if (app.isAdmin)
            _Group(
              title: 'ADMINISTRATION',
              children: [
                _Row(
                  icon: Icons.admin_panel_settings_rounded,
                  label: 'Admin panel',
                  sublabel: 'Signed in as ${app.adminRole.label}',
                  trailing: StatusPill(
                    label: app.adminRole.label.toUpperCase(),
                    color: AppColors.gold,
                    dense: true,
                  ),
                  onTap: () => Navigator.of(
                    context,
                  ).push(slideRoute(const AdminShell())),
                ),
              ],
            ),
          _Group(
            title: 'YOUR MONEY',
            children: [
              _Row(
                icon: Icons.insights_rounded,
                label: 'Insights',
                sublabel: 'Where your money goes',
                onTap: () => Navigator.of(
                  context,
                ).push(slideRoute(const InsightsScreen())),
              ),
              _Row(
                icon: Icons.speed_rounded,
                label: 'Credit score',
                sublabel: '${app.creditScore} - ${app.creditBand}',
                onTap: () => Navigator.of(
                  context,
                ).push(slideRoute(const CreditScoreScreen())),
              ),
              _Row(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                sublabel: app.unreadCount > 0
                    ? '${app.unreadCount} unread'
                    : 'All caught up',
                trailing: app.unreadCount > 0
                    ? StatusPill(
                        label: '${app.unreadCount}',
                        color: AppColors.gold,
                        dense: true,
                      )
                    : null,
                onTap: () => Navigator.of(
                  context,
                ).push(slideRoute(const NotificationsScreen())),
              ),
            ],
          ),
          _Group(
            title: 'ACCOUNT',
            children: [
              _Row(
                icon: Icons.badge_outlined,
                label: 'Personal details',
                sublabel: user.email,
                onTap: () => _showDetails(context, user),
              ),
              _Row(
                icon: Icons.verified_user_outlined,
                label: 'Verification status',
                sublabel: user.kycTier.label,
                trailing: const StatusPill(
                  label: 'TIER 2',
                  color: AppColors.success,
                  dense: true,
                ),
                onTap: () => _showDetails(context, user),
              ),
              _Row(
                icon: Icons.account_balance_outlined,
                label: 'Account number',
                sublabel: user.accountNumber,
                onTap: () => _showDetails(context, user),
              ),
            ],
          ),
          _Group(
            title: 'SUPPORT',
            children: [
              _Row(
                icon: Icons.headset_mic_outlined,
                label: 'Contact support',
                sublabel: AppConfig.supportPhone,
                onTap: () => showToast(
                  context,
                  'Our team is reachable at ${AppConfig.supportEmail}',
                ),
              ),
              _Row(
                icon: Icons.account_balance_outlined,
                label: 'Where to pay in',
                sublabel:
                    '${settings.companyBank} • ${settings.companyAccountNumber}',
                onTap: () => _showPayIn(context, app),
              ),
              _Row(
                icon: Icons.help_outline_rounded,
                label: 'How Kudi9ja works',
                sublabel: 'Rates, limits and rules',
                onTap: () => _showRates(context),
              ),
              _Row(
                icon: Icons.description_outlined,
                label: 'Legal',
                sublabel: 'Terms, privacy, lending agreement',
                onTap: () =>
                    Navigator.of(context).push(slideRoute(const LegalScreen())),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: GhostButton(
              label: 'Sign out',
              icon: Icons.logout_rounded,
              danger: true,
              onPressed: () => _confirmSignOut(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Column(
              children: [
                const BrandMark(size: 28),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${AppConfig.appName} • v1.0.0',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  AppConfig.tagline,
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your savings and history stay safe. You will need your email and password to sign back in.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AppState>().signOut();
            },
            child: const Text(
              'Sign out',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, AppUser user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              KCard(
                child: Column(
                  children: [
                    _Detail('Full name', user.fullName),
                    _Detail('Email', user.email),
                    _Detail('Phone', user.phone),
                    _Detail('Date of birth', user.dateOfBirth.asDay),
                    _Detail('Gender', user.gender),
                    _Detail('Address', user.address),
                    _Detail('State', user.state),
                    _Detail('BVN', maskTail(user.bvn)),
                    _Detail('NIN', maskTail(user.nin)),
                    _Detail('Account number', user.accountNumber),
                    _Detail('Member since', user.createdAt.asDay, last: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPayIn(BuildContext context, AppState app) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Where to pay in',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Funding your wallet, opening savings or repaying a loan — it all goes to this account.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              CompanyAccountCard(reference: app.paymentReference),
            ],
          ),
        ),
      ),
    );
  }

  void _showRates(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rates and limits',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              KCard(
                child: Column(
                  children: [
                    _Detail(
                      'Fixed Savings',
                      '${settings.savingsRatePct.toStringAsFixed(0)}% per annum, paid upfront',
                    ),
                    _Detail('Fixed lock period', '1 month to 5 years'),
                    _Detail('Fixed plans', 'Cannot be broken before maturity'),
                    _Detail(
                      'Target Savings',
                      'Bonus paid on the final day',
                    ),
                    _Detail(
                      '  3 - 5 months',
                      '${settings.targetShortPct.toStringAsFixed(1)}%',
                    ),
                    _Detail(
                      '  6 - 11 months',
                      '${settings.targetMediumPct.toStringAsFixed(1)}%',
                    ),
                    _Detail(
                      '  1 year and above',
                      '${settings.targetLongPct.toStringAsFixed(1)}%',
                    ),
                    _Detail(
                      'Target minimum term',
                      '${settings.minTargetMonths} months',
                    ),
                    _Detail(
                      'Breaking Target Savings',
                      'Principal returned in full, bonus forfeited',
                    ),
                    _Detail(
                      'Minimum savings',
                      settings.minSavingsAmount.asNairaFlat,
                    ),
                    _Detail(
                      'Maximum loan',
                      settings.maxLoanAmount.asNairaFlat,
                    ),
                    _Detail(
                      'Loan rate',
                      'Flat, and set by the tenure you choose',
                    ),
                    // Anchors only — every month in between is priced too,
                    // and the request screen shows the exact rate.
                    for (final months in const [1, 3, 6, 12, 24])
                      if (months <= settings.maxLoanTenureMonths)
                        _Detail(
                          months == 1 ? '  1 month' : '  $months months',
                          settings.loanRateLabelFor(months),
                        ),
                    _Detail(
                      'Loan tenure',
                      'Any month from 1 to ${settings.maxLoanTenureMonths}',
                    ),
                    _Detail(
                      'Minimum loan',
                      settings.minLoanAmount.asNairaFlat,
                    ),
                    _Detail(
                      'Processing fee',
                      'Also called the management fee',
                    ),
                    _Detail(
                      '  Up to ${settings.processingFeeThreshold.asNairaFlat}',
                      'Flat ${settings.flatProcessingFee.asNairaFlat}',
                    ),
                    _Detail(
                      '  Above that',
                      '${settings.feeRatePct.toStringAsFixed(0)}% of the whole amount',
                    ),
                    _Detail(
                      'Fee is',
                      'Deducted from the loan before it reaches you',
                      last: true,
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    child: KCard(
      gradient: AppColors.cardGradient,
      borderColor: AppColors.gold.withValues(alpha: 0.22),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.goldGradient,
            ),
            alignment: Alignment.center,
            child: Text(
              initialsOf(user.fullName),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textOnGold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 3),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const StatusPill(
                  label: 'FULLY VERIFIED',
                  color: AppColors.success,
                  icon: Icons.verified_rounded,
                  dense: true,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      0,
      AppSpacing.xl,
      AppSpacing.xl,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md, left: 2),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const HairLine(indent: 44),
                children[i],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.sublabel,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? sublabel;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.gold),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sublabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sublabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textTertiary,
            ),
        ],
      ),
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Row(
      children: [
        Icon(icon, size: 20, color: AppColors.gold),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value, {this.last = false});
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      if (!last)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: HairLine(),
        ),
    ],
  );
}

/// Kept for the security screen's biometric availability probe.
Future<bool> biometricsAvailable() => SecurityService.isBiometricAvailable;
