import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/app_notification.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the centre is what marks everything as seen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().markNotificationsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = app.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => app.clearNotifications(),
              child: const Text(
                'Clear',
                style: TextStyle(color: AppColors.gold, fontSize: 13),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: items.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'Nothing yet',
                  message:
                      'Interest payouts, maturity alerts and repayment reminders will land here.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (_, i) => _NotificationCard(item: items[i])
                      .animate(delay: (40 * i).ms)
                      .fadeIn()
                      .slideY(begin: 0.1),
                ),
        ),
      ),
    );
  }
}

(IconData, Color) styleFor(NotifyKind kind) => switch (kind) {
  NotifyKind.interest => (Icons.trending_up_rounded, AppColors.success),
  NotifyKind.maturity => (Icons.lock_open_rounded, AppColors.gold),
  NotifyKind.repaymentDue => (Icons.event_rounded, AppColors.danger),
  NotifyKind.repaymentPaid => (Icons.check_circle_rounded, AppColors.success),
  NotifyKind.autoSave => (Icons.autorenew_rounded, AppColors.info),
  NotifyKind.thrift => (Icons.groups_rounded, AppColors.gold),
  NotifyKind.security => (Icons.shield_rounded, AppColors.info),
  NotifyKind.general => (Icons.info_outline_rounded, AppColors.textSecondary),
};

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});
  final AppNotification item;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = styleFor(item.kind);

    return KCard(
      borderColor: item.read ? null : color.withValues(alpha: 0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, color: color, size: 42),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!item.read)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(left: 6, top: 4),
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.body,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Text(
                      item.date.relative,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    if (item.amount != null && item.amount! > 0) ...[
                      const Spacer(),
                      Text(
                        item.amount!.asNaira,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
