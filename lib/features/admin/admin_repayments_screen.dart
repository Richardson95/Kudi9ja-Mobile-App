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
import 'admin_shell.dart';

/// Every repayment customers have made — through Paystack, from the wallet,
/// by a transfer claimed against a loan, or recorded by hand — newest first,
/// with totals for everything the filters match.
class AdminRepaymentsScreen extends StatefulWidget {
  const AdminRepaymentsScreen({super.key});

  @override
  State<AdminRepaymentsScreen> createState() => _AdminRepaymentsScreenState();
}

class _AdminRepaymentsScreenState extends State<AdminRepaymentsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  RepaymentSource? _source;
  DateTimeRange? _range;

  final List<RepaymentRow> _rows = [];
  RepaymentSummary _summary = const RepaymentSummary();
  int _page = 0;
  bool _hasMore = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    final admin = context.read<AppState>().adminApi;
    if (admin == null) return;
    if (reset) {
      _page = 0;
      _rows.clear();
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final history = await admin.repayments(
        query: _search.text,
        source: _source,
        from: _range?.start,
        to: _range?.end,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _rows.addAll(history.rows);
        _summary = history.summary;
        _hasMore = history.hasMore;
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

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() => _range = picked);
    unawaited(_load(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    return Scaffold(
      appBar: AppBar(title: const Text('Repayments')),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MetricTile(
                        label: _range == null ? 'Repaid in all' : 'Repaid in range',
                        value: s.total.asNaira,
                        icon: Icons.payments_outlined,
                        tint: AppColors.success,
                        footnote: '${s.count} repayments',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: MetricTile(
                        label: 'This month',
                        value: s.thisMonth.asNaira,
                        icon: Icons.calendar_month_outlined,
                        tint: AppColors.gold,
                        footnote: '${s.today.asNaira} today',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                KCard(
                  child: Column(
                    children: [
                      _Split('Paystack', s.viaPaystack),
                      _Split('From wallets', s.fromWallet),
                      _Split('Bank transfer claims', s.bankTransfer),
                      _Split('Recorded by hand', s.recordedByHand),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search name, reference or loan',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'Dates',
                      icon: Icon(
                        Icons.date_range_rounded,
                        color: _range == null ? null : AppColors.gold,
                      ),
                      onPressed: _pickRange,
                    ),
                  ),
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 450),
                      () => _load(reset: true),
                    );
                  },
                ),
                if (_range != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  InputChip(
                    label: Text('${_range!.start.asDay} – ${_range!.end.asDay}'),
                    onDeleted: () {
                      setState(() => _range = null);
                      unawaited(_load(reset: true));
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _source == null,
                      onSelected: (_) {
                        setState(() => _source = null);
                        unawaited(_load(reset: true));
                      },
                    ),
                    for (final src in RepaymentSource.values)
                      ChoiceChip(
                        label: Text(src.label),
                        selected: _source == src,
                        onSelected: (_) {
                          setState(() => _source = src);
                          unawaited(_load(reset: true));
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: AppColors.danger))
                else if (_rows.isEmpty && !_loading)
                  const EmptyState(
                    icon: Icons.payments_outlined,
                    title: 'No repayments',
                    message: 'Nothing matches these filters.',
                  )
                else
                  KCard(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
                    child: Column(
                      children: [
                        for (var i = 0; i < _rows.length; i++) ...[
                          if (i > 0) const HairLine(),
                          _RepaymentTile(row: _rows[i]),
                        ],
                      ],
                    ),
                  ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_hasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: GhostButton(
                      label: 'Load more',
                      onPressed: () {
                        _page++;
                        unawaited(_load());
                      },
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

class _Split extends StatelessWidget {
  const _Split(this.label, this.value);
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        ),
        Text(value.asNaira, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _RepaymentTile extends StatelessWidget {
  const _RepaymentTile({required this.row});
  final RepaymentRow row;

  @override
  Widget build(BuildContext context) {
    final r = row;
    final color = switch (r.source) {
      RepaymentSource.paystack => AppColors.gold,
      RepaymentSource.wallet => AppColors.info,
      RepaymentSource.bankTransfer => AppColors.success,
      RepaymentSource.recorded => AppColors.textSecondary,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.customerName,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                Text(
                  [
                    if (r.customerRef.isNotEmpty) r.customerRef,
                    if (r.loanPurpose.isNotEmpty) '${r.loanPurpose} loan',
                    r.paidAt.asDayTime,
                  ].join(' · '),
                  style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                ),
                if (r.reference.isNotEmpty || r.recordedBy.isNotEmpty)
                  Text(
                    [
                      if (r.reference.isNotEmpty) r.reference,
                      if (r.recordedBy.isNotEmpty) 'by ${r.recordedBy}',
                    ].join(' · '),
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                r.amount.asNaira,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 4),
              StatusPill(
                label: r.sourceLabel.isEmpty ? r.source.label : r.sourceLabel,
                color: color,
                dense: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
