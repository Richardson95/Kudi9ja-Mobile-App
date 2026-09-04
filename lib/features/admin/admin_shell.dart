import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/admin.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';
import 'admin_audit_screen.dart';
import 'admin_loans_screen.dart';
import 'admin_overview_screen.dart';
import 'admin_payouts_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_team_screen.dart';
import 'admin_users_screen.dart';

/// The admin panel. Reachable only from the dashboard button, which only
/// appears for accounts listed in the admin team.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const _tabs = [
    (Icons.dashboard_rounded, Icons.dashboard_outlined, 'Home'),
    (Icons.people_alt_rounded, Icons.people_alt_outlined, 'Users'),
    (Icons.swap_vert_rounded, Icons.swap_vert_rounded, 'Payments'),
    (Icons.request_quote_rounded, Icons.request_quote_outlined, 'Loans'),
    (Icons.tune_rounded, Icons.tune_outlined, 'Rates'),
    (Icons.admin_panel_settings_rounded, Icons.admin_panel_settings_outlined, 'Team'),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final role = app.adminRole;

    // Access is re-checked on every build, so a revoked admin is ejected
    // the moment the change lands rather than at the next cold start.
    if (!app.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: EmptyState(
          icon: Icons.lock_rounded,
          title: 'No panel access',
          message:
              'This account is not on the admin team. Ask an owner to add your email address.',
          action: SizedBox(
            width: 200,
            child: GhostButton(
              label: 'Back',
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        leading: const BackButton(),
        titleSpacing: 0,
        title: Row(
          children: [
            const BrandMark(size: 24),
            const SizedBox(width: AppSpacing.sm),
            const Text('Admin', style: TextStyle(fontSize: 17)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: StatusPill(
                label: role.label.toUpperCase(),
                color: role == AdminRole.owner
                    ? AppColors.gold
                    : AppColors.info,
                dense: true,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Audit log',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminAuditScreen()),
            ),
            icon: const Icon(Icons.history_rounded, size: 20),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: IndexedStack(
            index: _index,
            children: const [
              AdminOverviewScreen(),
              AdminUsersScreen(),
              AdminPayoutsScreen(),
              AdminLoansScreen(),
              AdminSettingsScreen(),
              AdminTeamScreen(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0B0A0A),
          border: Border(top: BorderSide(color: AppColors.stroke)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_index == i) return;
                        HapticFeedback.selectionClick();
                        setState(() => _index = i);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                _index == i ? _tabs[i].$1 : _tabs[i].$2,
                                size: 21,
                                color: _index == i
                                    ? AppColors.gold
                                    : AppColors.textTertiary,
                              ),
                              if (i == 2 && app.pendingPaymentCount > 0)
                                Positioned(
                                  right: -7,
                                  top: -5,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger,
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(
                                        color: const Color(0xFF0B0A0A),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      '${app.pendingPaymentCount}',
                                      style: const TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _tabs[i].$3,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: _index == i
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _index == i
                                  ? AppColors.gold
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared admin widgets ──────────────────────────────────────────────────

class AdminSectionLabel extends StatelessWidget {
  const AdminSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
        color: AppColors.textTertiary,
      ),
    ),
  );
}

/// A headline number for the overview grid.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tint = AppColors.gold,
    this.footnote,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  final String? footnote;

  @override
  Widget build(BuildContext context) => KCard(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: tint),
        const SizedBox(height: AppSpacing.md),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
        if (footnote != null) ...[
          const SizedBox(height: 2),
          Text(
            footnote!,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: tint,
            ),
          ),
        ],
      ],
    ),
  );
}

/// The badge that distinguishes the real device account from sample rows.
class SourcePill extends StatelessWidget {
  const SourcePill({super.key, required this.isSample, this.isThisDevice = false});
  final bool isSample;
  final bool isThisDevice;

  @override
  Widget build(BuildContext context) {
    if (isThisDevice) {
      return const StatusPill(
        label: 'THIS DEVICE',
        color: AppColors.success,
        dense: true,
      );
    }
    if (isSample) {
      return const StatusPill(
        label: 'SAMPLE',
        color: AppColors.textTertiary,
        dense: true,
      );
    }
    return const SizedBox.shrink();
  }
}
