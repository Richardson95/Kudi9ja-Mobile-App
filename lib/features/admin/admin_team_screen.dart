import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/admin.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import 'admin_shell.dart';

/// Who has access to this panel, and at what level.
class AdminTeamScreen extends StatelessWidget {
  const AdminTeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final team = app.admins;
    final canManage = app.adminRole.canManageTeam;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        KCard(
          gradient: AppColors.cardGradient,
          borderColor: AppColors.gold.withValues(alpha: 0.24),
          child: Row(
            children: [
              const IconBadge(
                icon: Icons.admin_panel_settings_rounded,
                size: 46,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${team.length} ${team.length == 1 ? 'person has' : 'people have'} panel access',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Access is by email. Whoever signs in with a listed address sees the "Go to admin" button on their dashboard.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        if (canManage) ...[
          GoldButton(
            label: 'Add someone to the panel',
            icon: Icons.person_add_alt_rounded,
            onPressed: () => _showAddSheet(context),
          ),
          const SizedBox(height: AppSpacing.xl),
        ] else ...[
          KCard(
            borderColor: AppColors.info.withValues(alpha: 0.3),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: AppColors.info),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Only an owner can add or remove admins.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        const AdminSectionLabel('THE TEAM'),
        for (var i = 0; i < team.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _AdminTile(
              admin: team[i],
              isMe: team[i].id == app.currentAdmin?.id,
              canManage: canManage,
            ).animate(delay: (50 * i).ms).fadeIn().slideY(begin: 0.08),
          ),

        const SizedBox(height: AppSpacing.xl),
        const AdminSectionLabel('WHAT EACH ROLE CAN DO'),
        const _RoleMatrix(),
        const SizedBox(height: AppSpacing.huge),
      ],
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => const _AddAdminSheet(),
    );
  }
}

/// The permission matrix, read straight off the getters that gate the real
/// screens — so what this table says is what the panel actually does.
class _RoleMatrix extends StatelessWidget {
  const _RoleMatrix();

  static const _roleColumn = 42.0;

  @override
  Widget build(BuildContext context) => KCard(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(child: SizedBox()),
            for (final role in AdminRole.values)
              SizedBox(
                width: _roleColumn,
                child: Text(
                  _short(role),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: _tint(role),
                  ),
                ),
              ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: HairLine(),
        ),
        for (var i = 0; i < kAdminCapabilities.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 7),
              child: HairLine(),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  kAdminCapabilities[i].label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              for (final role in AdminRole.values)
                SizedBox(
                  width: _roleColumn,
                  child: Icon(
                    kAdminCapabilities[i].held(role)
                        ? Icons.check_rounded
                        : Icons.remove_rounded,
                    size: 15,
                    color: kAdminCapabilities[i].held(role)
                        ? AppColors.success
                        : AppColors.textTertiary,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        const HairLine(),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Nobody can change their own role, suspend themselves or remove '
          'their own access — each of those would revoke the permission '
          'needed to undo it.',
          style: TextStyle(
            fontSize: 11,
            height: 1.45,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    ),
  );

  static String _short(AdminRole role) => switch (role) {
    AdminRole.owner => 'OWNER',
    AdminRole.admin => 'ADMIN',
    AdminRole.support => 'SUPP',
    AdminRole.viewer => 'VIEW',
  };

  static Color _tint(AdminRole role) => switch (role) {
    AdminRole.owner => AppColors.gold,
    AdminRole.admin => AppColors.info,
    AdminRole.support => AppColors.success,
    AdminRole.viewer => AppColors.textTertiary,
  };
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.admin,
    required this.isMe,
    required this.canManage,
  });

  final AdminUser admin;
  final bool isMe;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final tint = switch (admin.role) {
      AdminRole.owner => AppColors.gold,
      AdminRole.admin => AppColors.info,
      AdminRole.support => AppColors.success,
      AdminRole.viewer => AppColors.textTertiary,
    };

    return KCard(
      borderColor: admin.active ? null : AppColors.danger.withValues(alpha: 0.3),
      onTap: canManage && !isMe ? () => _showActions(context) : null,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tint.withValues(alpha: 0.14),
              border: Border.all(color: tint.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: Text(
              initialsOf(admin.name),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: tint,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        admin.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      const StatusPill(
                        label: 'YOU',
                        color: AppColors.success,
                        dense: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  admin.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Added ${admin.addedAt.asDay}${admin.addedBy.isEmpty ? '' : ' by ${admin.addedBy}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill(
                label: admin.role.label.toUpperCase(),
                color: tint,
                dense: true,
              ),
              if (!admin.active) ...[
                const SizedBox(height: 4),
                const StatusPill(
                  label: 'SUSPENDED',
                  color: AppColors.danger,
                  dense: true,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showActions(BuildContext context) {
    final app = context.read<AppState>();

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Text(
                    admin.name,
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  Text(
                    admin.email,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const HairLine(),
            for (final role in AdminRole.values)
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.shield_outlined,
                  size: 19,
                  color: admin.role == role
                      ? AppColors.gold
                      : AppColors.textTertiary,
                ),
                title: Text(
                  'Make ${role.label}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: admin.role == role
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: admin.role == role
                        ? AppColors.gold
                        : AppColors.textPrimary,
                  ),
                ),
                trailing: admin.role == role
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: AppColors.gold,
                      )
                    : null,
                onTap: admin.role == role
                    ? null
                    : () async {
                        Navigator.pop(sheetContext);
                        await app.changeAdminRole(admin.id, role);
                        if (!context.mounted) return;
                        showToast(
                          context,
                          '${admin.name} is now ${role.label}',
                        );
                      },
              ),
            const HairLine(),
            ListTile(
              leading: Icon(
                admin.active
                    ? Icons.pause_circle_outline_rounded
                    : Icons.play_circle_outline_rounded,
                size: 19,
                color: AppColors.gold,
              ),
              title: Text(
                admin.active ? 'Suspend access' : 'Restore access',
                style: const TextStyle(fontSize: 14),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                await app.setAdminActive(admin.id, !admin.active);
                if (!context.mounted) return;
                showToast(
                  context,
                  admin.active
                      ? '${admin.name} suspended'
                      : '${admin.name} reinstated',
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.person_remove_alt_1_rounded,
                size: 19,
                color: AppColors.danger,
              ),
              title: const Text(
                'Remove from panel',
                style: TextStyle(fontSize: 14, color: AppColors.danger),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                final result = await app.removeAdmin(admin.id);
                if (!context.mounted) return;
                showToast(context, result.message, error: !result.ok);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _AddAdminSheet extends StatefulWidget {
  const _AddAdminSheet();

  @override
  State<_AddAdminSheet> createState() => _AddAdminSheetState();
}

class _AddAdminSheetState extends State<_AddAdminSheet> {
  final _search = TextEditingController();
  CustomerRecord? _picked;
  AdminRole _role = AdminRole.support;
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Accounts that could be granted access: everyone signed up, minus the
  /// ones already on the team, matched on whatever has been typed.
  List<CustomerRecord> _matches(AppState app) {
    final taken = app.admins.map((a) => a.email.toLowerCase()).toSet();
    final q = _search.text.trim().toLowerCase();

    return app.customers.where((c) {
      if (c.email.isEmpty || taken.contains(c.email.toLowerCase())) {
        return false;
      }
      if (q.isEmpty) return true;
      return c.email.toLowerCase().contains(q) ||
          c.fullName.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _submit() async {
    final picked = _picked;
    if (picked == null) return;
    setState(() => _busy = true);

    final result = await context.read<AppState>().addAdmin(
      customer: picked,
      role: _role,
    );
    if (!mounted) return;

    setState(() => _busy = false);
    if (result.ok) Navigator.pop(context);
    showToast(context, result.message, error: !result.ok);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final matches = _matches(app);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add to the admin panel',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Search someone who has already signed up and pick them. Access '
              'is granted to their email address, and starts the next time '
              'they sign in.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            KField(
              label: 'Search by email or name',
              hint: 'them@example.com',
              controller: _search,
              prefixIcon: Icons.search_rounded,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() => _picked = null),
            ),
            const SizedBox(height: AppSpacing.lg),

            if (matches.isEmpty)
              KCard(
                child: Text(
                  app.customers.isEmpty
                      ? 'Nobody has signed up yet.'
                      : 'No account matches that. They have to sign up first '
                            '— access cannot be granted to an address that '
                            'belongs to nobody.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final c in matches)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _CandidateTile(
                            customer: c,
                            selected: _picked?.id == c.id,
                            onTap: () => setState(() => _picked = c),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.xl),
            const Text(
              'ROLE',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final role in AdminRole.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: KOptionTile(
                  title: role.label,
                  subtitle: role.blurb,
                  selected: _role == role,
                  onTap: () => setState(() => _role = role),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            GoldButton(
              label: _picked == null
                  ? 'Pick someone first'
                  : 'Grant access to ${_picked!.email}',
              loading: _busy,
              onPressed: _picked == null ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// One searchable account. The email is the identity — it is what access is
/// matched on at sign-in — so it leads, with the name under it to confirm who
/// is being granted the panel.
class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.customer,
    required this.selected,
    required this.onTap,
  });

  final CustomerRecord customer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => KCard(
    onTap: onTap,
    borderColor: selected ? AppColors.gold : null,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.gold : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      customer.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  if (customer.isSample) ...[
                    const SizedBox(width: AppSpacing.sm),
                    const StatusPill(
                      label: 'SAMPLE',
                      color: AppColors.textTertiary,
                      dense: true,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (selected)
          const Icon(
            Icons.check_circle_rounded,
            size: 19,
            color: AppColors.gold,
          ),
      ],
    ),
  );
}
