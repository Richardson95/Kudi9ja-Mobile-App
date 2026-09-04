import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
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
        KCard(
          child: Column(
            children: [
              for (var i = 0; i < AdminRole.values.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: HairLine(),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        AdminRole.values[i].label,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        AdminRole.values[i].blurb,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
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
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  AdminRole _role = AdminRole.support;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);

    final result = await context.read<AppState>().addAdmin(
      name: _name.text,
      email: _email.text,
      phone: _phone.text,
      role: _role,
    );
    if (!mounted) return;

    setState(() => _busy = false);
    if (result.ok) Navigator.pop(context);
    showToast(context, result.message, error: !result.ok);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: AppSpacing.xl,
      right: AppSpacing.xl,
      top: AppSpacing.sm,
      bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
    ),
    child: Form(
      key: _form,
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
              'They get access the moment they sign in with this email address.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            KField(
              label: 'Full name',
              hint: 'Adaeze Okonkwo',
              controller: _name,
              prefixIcon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              validator: Validators.fullName,
            ),
            const SizedBox(height: AppSpacing.lg),
            KField(
              label: 'Email address',
              hint: 'them@example.com',
              controller: _email,
              prefixIcon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            const SizedBox(height: AppSpacing.lg),
            KField(
              label: 'Phone number (optional)',
              hint: '08031234567',
              controller: _phone,
              prefixIcon: Icons.phone_iphone_rounded,
              keyboardType: TextInputType.phone,
              maxLength: 11,
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
              label: 'Grant access',
              loading: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    ),
  );
}
