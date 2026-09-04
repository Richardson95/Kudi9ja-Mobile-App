import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import 'dart:io';

import '../../data/models/admin.dart';
import '../../data/models/deposit.dart';
import '../../data/models/models.dart';
import '../wallet/transaction_list.dart';
import '../../state/app_state.dart';
import '../../widgets/company_account.dart';
import '../../widgets/primitives.dart';
import 'admin_shell.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _search = TextEditingController();
  String _query = '';
  String _filter = 'All';

  static const _filters = ['All', 'Savers', 'Borrowers', 'Overdue risk'];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(CustomerRecord c) {
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      final hit =
          c.fullName.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q) ||
          c.phone.contains(q) ||
          c.accountNumber.contains(q);
      if (!hit) return false;
    }
    return switch (_filter) {
      'Savers' => c.totalSaved > 0,
      'Borrowers' => c.totalOwed > 0,
      'Overdue risk' => c.totalOwed > c.netWorth,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final all = app.customers;
    final list = all.where(_matches).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(fontSize: 14.5),
          decoration: InputDecoration(
            hintText: 'Search name, email, phone or account',
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 19,
              color: AppColors.textTertiary,
            ),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close_rounded, size: 17),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
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
        Text(
          '${list.length} of ${all.length} customers',
          style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.md),

        if (list.isEmpty)
          const EmptyState(
            icon: Icons.person_search_rounded,
            title: 'No match',
            message: 'Nobody matches that search or filter.',
          )
        else
          for (var i = 0; i < list.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _CustomerTile(customer: list[i])
                  .animate(delay: (40 * i).ms)
                  .fadeIn()
                  .slideY(begin: 0.08),
            ),
        const SizedBox(height: AppSpacing.huge),
      ],
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer});
  final CustomerRecord customer;

  @override
  Widget build(BuildContext context) => KCard(
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminCustomerDetailScreen(customer: customer),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: customer.isThisDevice ? AppColors.goldGradient : null,
            color: customer.isThisDevice ? null : AppColors.surfaceHigh,
          ),
          alignment: Alignment.center,
          child: Text(
            initialsOf(customer.fullName),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: customer.isThisDevice
                  ? AppColors.textOnGold
                  : AppColors.textSecondary,
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
                      customer.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SourcePill(
                    isSample: customer.isSample,
                    isThisDevice: customer.isThisDevice,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${customer.accountNumber} • ${customer.state.isEmpty ? 'Nigeria' : customer.state}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              customer.netWorth.asShortNaira,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              customer.totalOwed > 0
                  ? 'owes ${customer.totalOwed.asShortNaira}'
                  : 'no debt',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: customer.totalOwed > 0
                    ? AppColors.gold
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Everything the panel knows about one customer.
class AdminCustomerDetailScreen extends StatefulWidget {
  const AdminCustomerDetailScreen({super.key, required this.customer});
  final CustomerRecord customer;

  @override
  State<AdminCustomerDetailScreen> createState() =>
      _AdminCustomerDetailScreenState();
}

class _AdminCustomerDetailScreenState
    extends State<AdminCustomerDetailScreen> {
  TxFilter _txFilter = TxFilter.all;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = widget.customer;
    final ledger = app.transactionsFor(c);
    final filtered = ledger.where(_txFilter.matches).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Customer')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              _Header(customer: c),
              const SizedBox(height: AppSpacing.xl),

              const AdminSectionLabel('POSITION'),
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'Wallet',
                      value: c.balance.asShortNaira,
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: MetricTile(
                      label: 'Locked away',
                      value: c.totalSaved.asShortNaira,
                      icon: Icons.lock_outline_rounded,
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
                      label: 'Owed on loans',
                      value: c.totalOwed.asShortNaira,
                      icon: Icons.request_quote_outlined,
                      tint: c.totalOwed > 0
                          ? AppColors.gold
                          : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: MetricTile(
                      label: 'Interest paid to them',
                      value: c.interestPaid.asShortNaira,
                      icon: Icons.trending_up_rounded,
                      tint: AppColors.success,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xxl),
              const AdminSectionLabel('IDENTITY & KYC'),
              KCard(
                child: Column(
                  children: [
                    _Detail('Full name', c.fullName),
                    _Detail('Email', c.email),
                    _Detail('Phone', c.phone),
                    _Detail('Customer reference', c.accountNumber),
                    _Detail(
                      'Date of birth',
                      c.dateOfBirth?.asDay ?? 'Not on file',
                    ),
                    _Detail('Gender', c.gender.isEmpty ? '-' : c.gender),
                    _Detail('Address', c.address.isEmpty ? '-' : c.address),
                    _Detail('State', c.state.isEmpty ? '-' : c.state),
                    _Detail('BVN', c.bvn.isEmpty ? '-' : maskTail(c.bvn)),
                    _Detail('NIN', c.nin.isEmpty ? '-' : maskTail(c.nin)),
                    _Detail('Joined', c.joinedAt.asDay),
                    _Detail(
                      'KYC',
                      c.verified ? 'Tier 2 — fully verified' : 'Incomplete',
                      last: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              const AdminSectionLabel('ACTIVITY'),
              KCard(
                child: Column(
                  children: [
                    _Detail('Savings plans', '${c.plansCount}'),
                    _Detail('Loans taken', '${c.loansCount}'),
                    _Detail(
                      'Credit score',
                      '${c.creditScore} out of 850',
                      last: true,
                    ),
                  ],
                ),
              ),

              if (c.isThisDevice) ...[
                const SizedBox(height: AppSpacing.xl),
                const AdminSectionLabel('PAY-INS'),
                _PayIns(claims: app.depositsFor(c)),
                const SizedBox(height: AppSpacing.xl),
                const AdminSectionLabel('PLANS AND LOANS'),
                _LiveRecords(app: app),
              ],

              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  const Expanded(
                    child: AdminSectionLabel('TRANSACTION HISTORY'),
                  ),
                  Text(
                    '${filtered.length} of ${ledger.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: TxFilter.values.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final f = TxFilter.values[i];
                    final on = _txFilter == f;
                    return GestureDetector(
                      onTap: () => setState(() => _txFilter = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: on ? AppColors.goldWash : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: on ? AppColors.gold : AppColors.stroke,
                          ),
                        ),
                        child: Text(
                          f.label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: on
                                ? AppColors.gold
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (filtered.isEmpty)
                KCard(
                  child: Text(
                    'No ${_txFilter == TxFilter.all ? '' : '${_txFilter.label.toLowerCase()} '}transactions on this record.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                )
              else
                KCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < filtered.length; i++) ...[
                        if (i > 0) const HairLine(indent: 52),
                        TransactionRow(tx: filtered[i]),
                      ],
                    ],
                  ),
                ),
              if (c.isSample)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    'This is illustrative history for a sample customer. A live deployment reads the real ledger from the API.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),

              const SizedBox(height: AppSpacing.xl),
              const AdminSectionLabel('ACTIONS'),
              _Actions(customer: c),
              const SizedBox(height: AppSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.customer});
  final CustomerRecord customer;

  @override
  Widget build(BuildContext context) => KCard(
    gradient: AppColors.cardGradient,
    borderColor: AppColors.gold.withValues(alpha: 0.22),
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.goldGradient,
              ),
              alignment: Alignment.center,
              child: Text(
                initialsOf(customer.fullName),
                style: const TextStyle(
                  fontSize: 19,
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
                    customer.fullName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    customer.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      SourcePill(
                        isSample: customer.isSample,
                        isThisDevice: customer.isThisDevice,
                      ),
                      const SizedBox(width: 6),
                      StatusPill(
                        label: customer.verified ? 'VERIFIED' : 'UNVERIFIED',
                        color: customer.verified
                            ? AppColors.success
                            : AppColors.danger,
                        dense: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const HairLine(),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            const Text(
              'Net worth',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const Spacer(),
            Text(
              customer.netWorth.asNaira,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// This customer's pay-ins, newest first.
///
/// Every deposit carries its own K9 reference, so an admin reading a
/// narration off the bank statement can match it to exactly one claim — and
/// see straight away whether it is still waiting on them.
class _PayIns extends StatelessWidget {
  const _PayIns({required this.claims});

  final List<DepositClaim> claims;

  @override
  Widget build(BuildContext context) {
    if (claims.isEmpty) {
      return const KCard(
        child: Text(
          'No pay-ins yet.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
        ),
      );
    }

    return KCard(
      child: Column(
        children: [
          for (var i = 0; i < claims.length; i++) ...[
            _PayInRow(claim: claims[i]),
            if (i != claims.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: HairLine(),
              ),
          ],
        ],
      ),
    );
  }
}

class _PayInRow extends StatelessWidget {
  const _PayInRow({required this.claim});

  final DepositClaim claim;

  @override
  Widget build(BuildContext context) {
    final (label, colour) = switch (claim.status) {
      DepositStatus.pending => ('AWAITING YOU', AppColors.warning),
      DepositStatus.confirmed => ('CONFIRMED', AppColors.success),
      DepositStatus.rejected => ('REJECTED', AppColors.danger),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                claim.amount.asNaira,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            StatusPill(label: label, color: colour, dense: true),
          ],
        ),
        const SizedBox(height: 4),
        // The narration the customer was told to quote.
        Text(
          claim.reference,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          [
            claim.purpose == DepositPurpose.loanRepayment
                ? 'Loan repayment${claim.loanPurpose.isEmpty ? '' : ' — ${claim.loanPurpose}'}'
                : 'Wallet top-up',
            claim.claimedAt.asDayTime,
            if (claim.senderName.isNotEmpty) 'from ${claim.senderName}',
          ].join(' • '),
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.4,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // The receipt the customer attached. It is the evidence the whole
        // approval rests on, so it is reachable from their record too, not
        // only from the payments queue.
        if (claim.hasReceipt)
          GestureDetector(
            onTap: () => showReceipt(context, claim.receiptPath),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: Image.file(
                    File(claim.receiptPath),
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.receipt_long_rounded,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Text(
                  'View receipt',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          )
        else
          const Text(
            'No receipt attached',
            style: TextStyle(fontSize: 11.5, color: AppColors.danger),
          ),
        if (claim.note.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            claim.note,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _LiveRecords extends StatelessWidget {
  const _LiveRecords({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) => KCard(
    child: Column(
      children: [
        for (final p in app.plans.take(4)) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.savings_outlined,
                  size: 16,
                  color: AppColors.info,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    p.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  p.principal.asShortNaira,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusPill(
                  label: p.status.label.toUpperCase(),
                  color: p.isOpen ? AppColors.gold : AppColors.textTertiary,
                  dense: true,
                ),
              ],
            ),
          ),
        ],
        for (final l in app.loans.take(4)) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  size: 16,
                  color: AppColors.gold,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    '${l.purpose} loan',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  l.outstanding.asShortNaira,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusPill(
                  label: l.status.label.toUpperCase(),
                  color: l.status.name == 'overdue'
                      ? AppColors.danger
                      : AppColors.success,
                  dense: true,
                ),
              ],
            ),
          ),
        ],
        if (app.plans.isEmpty && app.loans.isEmpty)
          const Text(
            'No plans or loans on this account yet.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
          ),
      ],
    ),
  );
}

class _Actions extends StatelessWidget {
  const _Actions({required this.customer});
  final CustomerRecord customer;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final canAct = app.adminRole.canManageCustomers;

    return Column(
      children: [
        _ActionRow(
          icon: Icons.mail_outline_rounded,
          label: 'Copy contact details',
          onTap: () {
            Clipboard.setData(
              ClipboardData(
                text: '${customer.fullName}\n${customer.email}\n${customer.phone}',
              ),
            );
            showToast(context, 'Contact details copied');
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _ActionRow(
          icon: Icons.flag_outlined,
          label: 'Flag for compliance review',
          tint: AppColors.gold,
          onTap: !canAct
              ? null
              : () async {
                  await app.logAdminAction(
                    AuditCategory.customer,
                    'Customer flagged',
                    '${customer.fullName} (${customer.accountNumber}) flagged for compliance review.',
                  );
                  if (!context.mounted) return;
                  showToast(context, 'Flagged and written to the audit log');
                },
        ),
        const SizedBox(height: AppSpacing.md),
        _ActionRow(
          icon: Icons.ac_unit_rounded,
          label: 'Freeze account',
          tint: AppColors.danger,
          onTap: !canAct
              ? null
              : () => _confirmFreeze(context, app, customer),
        ),
        if (!canAct) ...[
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Your role is read-only, so account actions are disabled.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
          ),
        ],
      ],
    );
  }

  void _confirmFreeze(
    BuildContext context,
    AppState app,
    CustomerRecord c,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Freeze this account?'),
        content: Text(
          '${c.fullName} will not be able to move money until an admin unfreezes them. The action is recorded in the audit log.',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
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
            onPressed: () async {
              Navigator.pop(dialogContext);
              await app.logAdminAction(
                AuditCategory.customer,
                'Account frozen',
                '${c.fullName} (${c.accountNumber}) was frozen.',
              );
              if (!context.mounted) return;
              showToast(context, '${c.fullName} frozen', error: true);
            },
            child: const Text(
              'Freeze',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint = AppColors.textPrimary,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color tint;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? 0.45 : 1,
    child: KCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 19, color: tint),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: tint,
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.textTertiary,
          ),
        ],
      ),
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
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
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
