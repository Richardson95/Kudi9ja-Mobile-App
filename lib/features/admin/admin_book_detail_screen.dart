import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/lending_admin.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';
import 'admin_offline_loans_screen.dart';
import 'admin_shell.dart';
import 'admin_users_screen.dart';

/// The Overview figures, each opened into the list it was added up from.
enum BookView {
  overdue('Overdue', 'Every running loan with an instalment past its day and unpaid, longest behind first.'),
  outstanding('Still owed', 'What customers still owe on the loans running now: loan, interest and fees, less repayments.'),
  lent('Lent', 'Every loan paid out, running or closed, newest first.'),
  interest('Interest charged', 'The interest charged on every loan paid out, running or closed, largest first.'),
  fees('Fees charged', 'Management fees and transaction fees on every loan paid out, largest first.'),
  held('Customer money held', 'Every wallet holding money, largest balance first.');

  const BookView(this.label, this.subtitle);
  final String label;
  final String subtitle;
}

class AdminBookDetailScreen extends StatefulWidget {
  const AdminBookDetailScreen({super.key, required this.view});
  final BookView view;

  @override
  State<AdminBookDetailScreen> createState() => _AdminBookDetailScreenState();
}

class _AdminBookDetailScreenState extends State<AdminBookDetailScreen> {
  late BookView _view = widget.view;
  final _search = TextEditingController();
  BookDetail? _book;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final admin = context.read<AppState>().adminApi;
    if (admin == null) {
      setState(() {
        _loading = false;
        _error = 'Sign in to the server to see this list.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final book = await admin.bookDetail();
      if (!mounted) return;
      setState(() {
        _book = book;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  bool _matches(String name, String ref, String? phone, [List<String> officers = const []]) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [name, ref, phone ?? '', ...officers].any((v) => v.toLowerCase().contains(q));
  }

  List<BookDetailLoan> get _loans {
    final all = [...?_book?.loans];
    int byDate(BookDetailLoan a, BookDetailLoan b) =>
        (b.disbursedAt ?? DateTime(2000)).compareTo(a.disbursedAt ?? DateTime(2000));
    final rows = switch (_view) {
      BookView.overdue => all.where((r) => r.open && r.pastDue > 0).toList()
        ..sort((a, b) {
          final d = b.daysBehind.compareTo(a.daysBehind);
          return d != 0 ? d : b.pastDue.compareTo(a.pastDue);
        }),
      BookView.outstanding => all.where((r) => r.open).toList()
        ..sort((a, b) => b.outstanding.compareTo(a.outstanding)),
      BookView.interest => all..sort((a, b) => b.interest.compareTo(a.interest)),
      BookView.fees => all..sort((a, b) => b.fees.compareTo(a.fees)),
      _ => all..sort(byDate),
    };
    return rows.where((r) => _matches(r.customerName, r.customerRef, r.phone, r.officers)).toList();
  }

  List<WalletHolder> get _wallets => [...?_book?.wallets]
      .where((w) => _matches(w.customerName, w.customerRef, w.phone))
      .toList()
    ..sort((a, b) => b.balance.compareTo(a.balance));

  Future<void> _openBorrower(BookDetailLoan r) async {
    if (r.offline || r.customerId == null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AdminOfflineLoanScreen(importId: r.id)),
      );
      return;
    }
    await _openCustomer(r.customerId!);
  }

  Future<void> _openCustomer(String id) async {
    final app = context.read<AppState>();
    final customer = await app.loadCustomer(id);
    if (!mounted || customer == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdminCustomerDetailScreen(customer: customer)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loans = _view == BookView.held ? const <BookDetailLoan>[] : _loans;
    final wallets = _view == BookView.held ? _wallets : const <WalletHolder>[];
    return Scaffold(
      appBar: AppBar(title: Text(_view.label)),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Text(
                  _view.subtitle,
                  style: TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final v in BookView.values)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: ChoiceChip(
                            label: Text(v.label),
                            selected: _view == v,
                            onSelected: (_) => setState(() => _view = v),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_loading && _book == null)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xxl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null && _book == null)
                  EmptyState(
                    icon: Icons.account_balance_outlined,
                    title: 'Couldn’t load this list',
                    message: _error!,
                    action: GhostButton(label: 'Try again', expand: false, onPressed: _load),
                  )
                else ...[
                  if (_view == BookView.held) _HeldTotals(rows: wallets) else _Totals(view: _view, rows: loans),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'Search name, number, phone or officer',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_view == BookView.held)
                    if (wallets.isEmpty)
                      const EmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'No wallet is holding money',
                        message: 'Balances show here once customers add money.',
                      )
                    else
                      for (final w in wallets) ...[
                        _WalletTile(w: w, onTap: () => _openCustomer(w.customerId)),
                        const SizedBox(height: AppSpacing.md),
                      ]
                  else if (loans.isEmpty)
                    EmptyState(
                      icon: Icons.account_balance_outlined,
                      title: _view == BookView.overdue ? 'Nobody is behind' : 'No loans here',
                      message: 'Nothing matches.',
                    )
                  else
                    for (final r in loans) ...[
                      _LoanTile(view: _view, r: r, onTap: () => _openBorrower(r)),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  if (_book?.generatedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Text(
                        'Updated ${_book!.generatedAt!.relative}. Pull down to refresh.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

double _sum(Iterable<BookDetailLoan> rows, double Function(BookDetailLoan) f) =>
    rows.fold(0.0, (t, r) => t + f(r));

class _Totals extends StatelessWidget {
  const _Totals({required this.view, required this.rows});
  final BookView view;
  final List<BookDetailLoan> rows;

  @override
  Widget build(BuildContext context) {
    final n = '${rows.length} loan${rows.length == 1 ? '' : 's'}';
    final open = rows.where((r) => r.open);
    final closed = rows.where((r) => !r.open);
    final tiles = <MetricTile>[
      ...switch (view) {
        BookView.overdue => [
          MetricTile(label: 'Overdue', value: _sum(rows, (r) => r.pastDue).asNaira, icon: Icons.warning_amber_rounded, tint: AppColors.danger, footnote: '$n with missed payments'),
          MetricTile(label: 'Missed instalments', value: '${rows.fold(0, (t, r) => t + r.missedInstalments)}', icon: Icons.event_busy_rounded, tint: AppColors.danger),
          MetricTile(label: 'Still owed on these', value: _sum(rows, (r) => r.outstanding).asNaira, icon: Icons.account_balance_outlined, tint: AppColors.gold),
          MetricTile(label: 'Repaid on these', value: _sum(rows, (r) => r.amountRepaid).asNaira, icon: Icons.payments_outlined, tint: AppColors.success),
        ],
        BookView.outstanding => [
          MetricTile(label: 'Still owed', value: _sum(rows, (r) => r.outstanding).asNaira, icon: Icons.account_balance_outlined, tint: AppColors.gold, footnote: '$n running'),
          MetricTile(label: 'Of which overdue', value: _sum(rows, (r) => r.pastDue).asNaira, icon: Icons.warning_amber_rounded, tint: AppColors.danger),
          MetricTile(label: 'Repaid so far', value: _sum(rows, (r) => r.amountRepaid).asNaira, icon: Icons.payments_outlined, tint: AppColors.success),
          MetricTile(label: 'Lent on these', value: _sum(rows, (r) => r.principal).asNaira, icon: Icons.request_quote_outlined, tint: AppColors.gold),
        ],
        BookView.lent => [
          MetricTile(label: 'Lent', value: _sum(rows, (r) => r.principal).asNaira, icon: Icons.request_quote_outlined, tint: AppColors.gold, footnote: n),
          MetricTile(label: 'Paid out, after fees', value: _sum(rows, (r) => r.paidOut).asNaira, icon: Icons.account_balance_wallet_outlined, tint: AppColors.info),
          MetricTile(label: 'Repaid', value: _sum(rows, (r) => r.amountRepaid).asNaira, icon: Icons.payments_outlined, tint: AppColors.success),
          MetricTile(label: 'Still owed', value: _sum(rows, (r) => r.outstanding).asNaira, icon: Icons.account_balance_outlined, tint: AppColors.gold),
        ],
        BookView.interest => [
          MetricTile(label: 'Interest charged', value: _sum(rows, (r) => r.interest).asNaira, icon: Icons.percent_rounded, tint: AppColors.success, footnote: n),
          MetricTile(label: 'On running loans', value: _sum(open, (r) => r.interest).asNaira, icon: Icons.percent_rounded, tint: AppColors.gold),
          MetricTile(label: 'On closed loans', value: _sum(closed, (r) => r.interest).asNaira, icon: Icons.percent_rounded, tint: AppColors.textSecondary),
          MetricTile(label: 'Lent on these', value: _sum(rows, (r) => r.principal).asNaira, icon: Icons.request_quote_outlined, tint: AppColors.gold),
        ],
        _ => [
          MetricTile(label: 'Fees charged', value: _sum(rows, (r) => r.fees).asNaira, icon: Icons.receipt_long_outlined, tint: AppColors.success, footnote: n),
          MetricTile(label: 'Management fees', value: _sum(rows, (r) => r.managementFee).asNaira, icon: Icons.receipt_long_outlined, tint: AppColors.gold, footnote: 'Taken off the payout'),
          MetricTile(label: 'Transaction fees', value: _sum(rows, (r) => r.repaymentFees).asNaira, icon: Icons.receipt_long_outlined, tint: AppColors.gold, footnote: 'Added to each instalment'),
          MetricTile(label: 'Older flat fees', value: _sum(rows, (r) => r.transactionFee).asNaira, icon: Icons.receipt_long_outlined, tint: AppColors.textSecondary),
        ],
      },
    ];
    return Column(
      children: [
        Row(children: [Expanded(child: tiles[0]), const SizedBox(width: AppSpacing.md), Expanded(child: tiles[1])]),
        const SizedBox(height: AppSpacing.md),
        Row(children: [Expanded(child: tiles[2]), const SizedBox(width: AppSpacing.md), Expanded(child: tiles[3])]),
      ],
    );
  }
}

class _HeldTotals extends StatelessWidget {
  const _HeldTotals({required this.rows});
  final List<WalletHolder> rows;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: MetricTile(
          label: 'Customer money held',
          value: rows.fold(0.0, (t, w) => t + w.balance).asNaira,
          icon: Icons.account_balance_wallet_outlined,
          tint: AppColors.gold,
          footnote: 'Wallet balances',
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: MetricTile(
          label: 'Wallets holding money',
          value: '${rows.length}',
          icon: Icons.people_alt_outlined,
          tint: AppColors.info,
        ),
      ),
    ],
  );
}

Color _statusColor(String status) => switch (status) {
  'OVERDUE' || 'WRITTEN_OFF' => AppColors.danger,
  'REPAID' => AppColors.success,
  'ACTIVE' => AppColors.gold,
  _ => AppColors.textSecondary,
};

class _LoanTile extends StatelessWidget {
  const _LoanTile({required this.view, required this.r, required this.onTap});
  final BookView view;
  final BookDetailLoan r;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final term = r.weekly
        ? '${r.installmentCount} weeks'
        : '${r.tenureMonths} month${r.tenureMonths == 1 ? '' : 's'}';
    final lines = <(String, String, Color?)>[
      ...switch (view) {
        BookView.overdue => [
          ('Overdue', r.pastDue.asNaira, AppColors.danger),
          ('Missed', '${r.missedInstalments} of ${r.installmentCount} · ${r.installmentsPaid} paid', null),
          ('Behind since', '${r.oldestMissedDue?.asDay ?? '—'} · ${r.daysBehind} day${r.daysBehind == 1 ? '' : 's'}', AppColors.danger),
          ('Still owed', r.outstanding.asNaira, null),
          ('Next due', r.nextDue == null ? '—' : '${r.nextDue!.asDay} · ${(r.nextDueAmount ?? 0).asNaira}', null),
        ],
        BookView.outstanding => [
          ('Total to repay', r.totalRepayable.asNaira, null),
          ('Repaid', r.amountRepaid.asNaira, AppColors.success),
          ('Still owed', r.outstanding.asNaira, AppColors.gold),
          ('Overdue', r.pastDue.asNaira, r.pastDue > 0 ? AppColors.danger : null),
          ('Next due', r.nextDue == null ? '—' : '${r.nextDue!.asDay} · ${(r.nextDueAmount ?? 0).asNaira}', null),
        ],
        BookView.lent => [
          ('Lent', r.principal.asNaira, AppColors.gold),
          ('Paid out', r.paidOut.asNaira, null),
          ('Total to repay', r.totalRepayable.asNaira, null),
          ('Repaid', r.amountRepaid.asNaira, AppColors.success),
          ('Still owed', r.outstanding.asNaira, null),
        ],
        BookView.interest => [
          ('Rate', '${(r.flatRate * 100).toStringAsFixed((r.flatRate * 100) % 1 == 0 ? 0 : 1)}%', null),
          ('Interest', r.interest.asNaira, AppColors.success),
          ('Total to repay', r.totalRepayable.asNaira, null),
          ('Repaid', r.amountRepaid.asNaira, null),
        ],
        _ => [
          ('Management fee', r.managementFee.asNaira, null),
          ('Transaction fees', r.repaymentFees.asNaira, null),
          ('Older flat fee', r.transactionFee.asNaira, null),
          ('All fees', r.fees.asNaira, AppColors.success),
        ],
      },
    ];
    final color = _statusColor(r.status);
    return KCard(
      onTap: onTap,
      borderColor: color.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.customerName, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        r.customerRef.isEmpty ? 'Not signed up yet' : r.customerRef,
                        if (r.phone != null && r.phone!.isNotEmpty) r.phone!,
                      ].join(' · '),
                      style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                    ),
                    if (r.officers.isNotEmpty)
                      Text(
                        'Officer: ${r.officers.join(', ')}',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                      ),
                  ],
                ),
              ),
              StatusPill(label: r.statusLabel, color: color, dense: true),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${r.principal.asNaira} · $term${r.purpose.isEmpty ? '' : ' · ${r.purpose}'}\n'
            'Paid out ${r.disbursedAt?.asDay ?? '—'} · last due ${r.dueDate?.asDay ?? '—'}',
            style: TextStyle(fontSize: 11.5, height: 1.45, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          const HairLine(),
          const SizedBox(height: AppSpacing.sm),
          for (final (label, value, tint) in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                  ),
                  Text(
                    value,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tint),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WalletTile extends StatelessWidget {
  const _WalletTile({required this.w, required this.onTap});
  final WalletHolder w;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => KCard(
    onTap: onTap,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(w.customerName, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                [
                  w.customerRef,
                  if (w.phone != null && w.phone!.isNotEmpty) w.phone!,
                  if (w.updatedAt != null) 'last movement ${w.updatedAt!.asDay}',
                ].join(' · '),
                style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
        Text(w.balance.asNaira, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}
