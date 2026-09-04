import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/admin.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';

/// An append-only record of everything admins have done.
class AdminAuditScreen extends StatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  State<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends State<AdminAuditScreen> {
  AuditCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final all = context.watch<AppState>().auditLog;
    final entries = _filter == null
        ? all
        : all.where((e) => e.category == _filter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Audit log')),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _Chip(
                        label: 'Everything',
                        selected: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                      for (final c in AuditCategory.values) ...[
                        const SizedBox(width: AppSpacing.sm),
                        _Chip(
                          label: c.label,
                          selected: _filter == c,
                          onTap: () => setState(() => _filter = c),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? const EmptyState(
                        icon: Icons.history_rounded,
                        title: 'Nothing logged yet',
                        message:
                            'Rate changes, team changes and customer actions are all recorded here.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          0,
                          AppSpacing.xl,
                          AppSpacing.huge,
                        ),
                        itemCount: entries.length,
                        itemBuilder: (_, i) => _Entry(
                          entry: entries[i],
                          isLast: i == entries.length - 1,
                        ).animate(delay: (30 * i).ms).fadeIn(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.goldWash : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.stroke,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.gold : AppColors.textSecondary,
        ),
      ),
    ),
  );
}

/// One log line, drawn as a timeline node.
class _Entry extends StatelessWidget {
  const _Entry({required this.entry, required this.isLast});
  final AuditEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = switch (entry.category) {
      AuditCategory.settings => (Icons.tune_rounded, AppColors.gold),
      AuditCategory.team => (
        Icons.admin_panel_settings_rounded,
        AppColors.info,
      ),
      AuditCategory.customer => (Icons.person_rounded, AppColors.success),
      AuditCategory.loan => (Icons.bolt_rounded, AppColors.gold),
      AuditCategory.general => (
        Icons.info_outline_rounded,
        AppColors.textSecondary,
      ),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                  border: Border.all(color: tint.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, size: 15, color: tint),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1.5, color: AppColors.stroke),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: KCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.action,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          entry.date.relative,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.detail,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 12,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          entry.actor,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          entry.date.asDayTime,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
