import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/admin.dart';
import '../../data/models/models.dart';
import '../../data/models/platform_settings.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';
import 'admin_loan_applications_section.dart';
import 'admin_users_screen.dart';
import 'admin_shell.dart';

/// The lending book: exposure, performance and every live loan.
class AdminLoansScreen extends StatefulWidget {
  const AdminLoansScreen({super.key});

  @override
  State<AdminLoansScreen> createState() => _AdminLoansScreenState();
}

class _AdminLoansScreenState extends State<AdminLoansScreen> {
  String _filter = 'All';
  static const _filters = ['All', 'Active', 'Overdue', 'Repaid'];

  bool _matches(BookLoan l) => switch (_filter) {
    'Active' => l.status == LoanStatus.active,
    'Overdue' => l.status == LoanStatus.overdue,
    'Repaid' => l.status == LoanStatus.repaid,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    // The whole lending book from the server, not this device's own loans.
    // Reading `app.loans` here meant the panel showed the admin their own
    // borrowing and called it the book: empty for an admin who has never
    // borrowed, however much the company had lent.
    final all = app.bookLoans;
    final loans = all.where(_matches).toList();

    final disbursed = all.fold(0.0, (s, l) => s + l.principal);
    final outstanding = all.fold(0.0, (s, l) => s + l.outstanding);
    final collected = all.fold(0.0, (s, l) => s + l.amountRepaid);
    final fees = all.fold(0.0, (s, l) => s + l.processingFee);
    final overdueCount =
        all.where((l) => l.status == LoanStatus.overdue).length;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        // Above the book, deliberately: this is the part with somebody waiting
        // on it. The book below is a record, and records can wait.
        const AdminLoanApplicationsSection(),
        if (!settings.lendingEnabled) ...[
          KCard(
            borderColor: AppColors.danger.withValues(alpha: 0.4),
            child: Row(
              children: [
                Icon(Icons.block_rounded, size: 18, color: AppColors.danger),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Lending is switched off. No new loans can be requested.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        const AdminSectionLabel('LENDING BOOK'),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Total disbursed',
                value: disbursed.asShortNaira,
                icon: Icons.upload_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MetricTile(
                label: 'Outstanding',
                value: outstanding.asShortNaira,
                icon: Icons.hourglass_bottom_rounded,
                tint: AppColors.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Collected',
                value: collected.asShortNaira,
                icon: Icons.download_rounded,
                tint: AppColors.success,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MetricTile(
                label: 'Fee income',
                value: fees.asShortNaira,
                icon: Icons.percent_rounded,
                tint: AppColors.gold,
              ),
            ),
          ],
        ),
        if (overdueCount > 0) ...[
          const SizedBox(height: AppSpacing.md),
          KCard(
            borderColor: AppColors.danger.withValues(alpha: 0.4),
            child: Row(
              children: [
                IconBadge(
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.danger,
                  size: 42,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    '$overdueCount ${overdueCount == 1 ? 'loan is' : 'loans are'} overdue',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.xxl),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, i) {
              final f = _filters[i];
              final on = _filter == f;
              return GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? AppColors.goldWash : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: on ? AppColors.gold : AppColors.stroke,
                    ),
                  ),
                  child: Text(
                    f,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: on ? AppColors.gold : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        if (loans.isEmpty)
          EmptyState(
            icon: Icons.request_quote_outlined,
            title: _filter == 'All' ? 'Nothing lent yet' : 'None $_filter here',
            message: _filter == 'All'
                ? 'Every loan the company writes appears here, with what is owed on it.'
                : 'No loan in the book has that status right now.',
          )
        else
          for (var i = 0; i < loans.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _AdminLoanTile(loan: loans[i])
                  .animate(delay: (40 * i).ms)
                  .fadeIn()
                  .slideY(begin: 0.08),
            ),

        const SizedBox(height: AppSpacing.xl),
        Text(
          app.isOnline
              ? 'The whole lending book, every customer included. Tap a loan to open the borrower.'
              : 'No server: this lists the loans held on this device.',
          style: TextStyle(
            fontSize: 11.5,
            height: 1.5,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.huge),
      ],
    );
  }
}

class _AdminLoanTile extends StatelessWidget {
  const _AdminLoanTile({required this.loan});
  final BookLoan loan;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final overdue = loan.status == LoanStatus.overdue;
    final settled = !loan.isOpen;
    final tint = settled
        ? AppColors.success
        : (overdue ? AppColors.danger : AppColors.gold);

    // What has come back against what was ever owed. The book row carries no
    // schedule, so this is the progress it can honestly show.
    final owed = loan.amountRepaid + loan.outstanding;
    final progress = owed <= 0 ? 0.0 : (loan.amountRepaid / owed).clamp(0.0, 1.0);

    // The borrower's own record, if the panel has loaded them.
    final borrower =
        app.customers.where((c) => c.id == loan.customerId).firstOrNull;

    return KCard(
      borderColor: tint.withValues(alpha: 0.28),
      onTap: borrower == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminCustomerDetailScreen(customer: borrower),
                ),
              ),
      child: Column(
        children: [
          Row(
            children: [
              IconBadge(icon: Icons.bolt_rounded, color: tint, size: 42),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Whose loan it is, first. A book that leads with the
                    // amount makes an admin open every row to find a person.
                    Text(
                      loan.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${loan.customerRef} • ${loan.purpose} • '
                      '${loan.principal.asShortNaira} over ${loan.tenureMonths} '
                      '${loan.tenureMonths == 1 ? 'month' : 'months'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: loan.statusLabel.toUpperCase(),
                color: tint,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _Cell(
                  label: 'Outstanding',
                  value: loan.outstanding.asShortNaira,
                ),
              ),
              Expanded(
                child: _Cell(
                  label: 'Collected',
                  value: loan.amountRepaid.asShortNaira,
                ),
              ),
              Expanded(
                child: _Cell(
                  label: 'Fee taken',
                  value: loan.processingFee.asShortNaira,
                ),
              ),
              Expanded(
                child: _Cell(
                  label: overdue ? 'Overdue by' : 'Due',
                  value: overdue
                      ? '${loan.daysOverdue}d'
                      : (loan.dueDate?.asDay ?? '—'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(tint),
            ),
          ),
          if (overdue && app.adminRole.canActOnLoans) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: 'Send reminder',
                    onPressed: () async {
                      // The server sends it and logs it, and refuses outside
                      // 8am-8pm Lagos time. Whatever it answers is what the
                      // admin is told.
                      final sent = await app.remindBorrower(loan.id);
                      if (!context.mounted) return;
                      showToast(
                        context,
                        sent
                            ? 'Reminder sent to ${loan.customerName}'
                            : (app.lastError ?? 'That reminder could not be sent'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
      ),
      const SizedBox(height: 2),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
    ],
  );
}
