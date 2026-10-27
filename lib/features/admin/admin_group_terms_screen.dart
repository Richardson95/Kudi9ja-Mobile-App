import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../widgets/primitives.dart';
import 'admin_number_field.dart';
import 'admin_shell.dart';

/// What changes between two sets of loan-group terms, one line each, for the
/// save dialog and the audit log.
List<String> groupTermsChanges(LendingTerms before, LendingTerms after) {
  final out = <String>[];
  void cmp(String label, Object a, Object b) {
    if (a != b) out.add('Group loans — $label: $a → $b');
  }

  String pct(double r) => '${(r * 100).toStringAsFixed(2)}%';
  for (final m in {...before.rates.keys, ...after.rates.keys}.toList()..sort()) {
    cmp('rate ${m}m', pct(before.rateFor(m)), pct(after.rateFor(m)));
  }
  cmp('longest term', '${before.maxTenureMonths}m', '${after.maxTenureMonths}m');
  cmp('smallest loan', before.minAmount.asNairaFlat, after.minAmount.asNairaFlat);
  cmp('largest loan', before.maxAmount.asNairaFlat, after.maxAmount.asNairaFlat);
  cmp('flat management fee', before.flatProcessingFee.asNairaFlat, after.flatProcessingFee.asNairaFlat);
  cmp('fee threshold', before.processingFeeThreshold.asNairaFlat, after.processingFeeThreshold.asNairaFlat);
  cmp('fee rate above it', pct(before.processingFeeRate), pct(after.processingFeeRate));
  cmp('transaction fee', pct(before.repaymentFeeRate), pct(after.repaymentFeeRate));
  cmp('weekly repayment', before.weeklyAllowed, after.weeklyAllowed);
  cmp('monthly repayment', before.monthlyAllowed, after.monthlyAllowed);
  return out;
}

/// The loan-group terms, edited on their own.
///
/// Members of a loan group borrow on their own copy of everything that prices
/// a loan. It started as an exact copy of the standard terms and is changed
/// here; nothing is saved until the settings screen's own save, so the change
/// goes through the same confirmation and audit as every other rate.
class AdminGroupTermsScreen extends StatefulWidget {
  const AdminGroupTermsScreen({
    super.key,
    required this.terms,
    required this.standard,
    required this.canEdit,
  });

  final LendingTerms terms;
  final LendingTerms standard;
  final bool canEdit;

  @override
  State<AdminGroupTermsScreen> createState() => _AdminGroupTermsScreenState();
}

class _AdminGroupTermsScreenState extends State<AdminGroupTermsScreen> {
  late LendingTerms _t = widget.terms;

  void _set(LendingTerms next) => setState(() => _t = next);

  /// The longest term set to [months], with a rate for every month it adds.
  void _setTenure(int months) => _set(_t.copyWith(
    maxTenureMonths: months,
    rates: ratesUpTo(_t.rates, months),
  ));

  @override
  Widget build(BuildContext context) {
    final edit = widget.canEdit;
    final changed = !_t.sameAs(widget.terms);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan group terms'),
        actions: [
          if (edit)
            TextButton(
              onPressed: () => Navigator.pop(context, _t),
              child: Text(
                'Done',
                style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Text(
                'Members of a loan group borrow on these instead of the '
                'standard terms. Changes are saved with the rest of the '
                'settings, and apply to loans priced from then on.',
                style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textTertiary),
              ),
              if (edit) ...[
                const SizedBox(height: AppSpacing.md),
                GhostButton(
                  label: 'Copy the standard terms',
                  icon: Icons.content_copy_rounded,
                  onPressed: () => _set(LendingTerms(
                    group: true,
                    rates: widget.standard.rates,
                    maxTenureMonths: widget.standard.maxTenureMonths,
                    minAmount: widget.standard.minAmount,
                    maxAmount: widget.standard.maxAmount,
                    flatProcessingFee: widget.standard.flatProcessingFee,
                    processingFeeThreshold: widget.standard.processingFeeThreshold,
                    processingFeeRate: widget.standard.processingFeeRate,
                    repaymentFeeRate: widget.standard.repaymentFeeRate,
                    weeklyAllowed: widget.standard.weeklyAllowed,
                    monthlyAllowed: widget.standard.monthlyAllowed,
                  )),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              const AdminSectionLabel('INTEREST BY TENURE'),
              KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Group rate card · ${_t.rateRange}',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    RateByTermGrid(
                      rates: _t.rates,
                      maxTenureMonths: _t.maxTenureMonths,
                      enabled: edit,
                      onChanged: (m, r) => _set(_t.copyWith(rates: {..._t.rates, m: r})),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _Stepper(
                label: 'Longest term',
                value: _t.maxTenureMonths,
                enabled: edit,
                onChanged: (v) => _setTenure(v),
                onMinus: edit && _t.maxTenureMonths > 1
                    ? () => _setTenure(_t.maxTenureMonths - 1)
                    : null,
                onPlus: edit ? () => _setTenure(_t.maxTenureMonths + 1) : null,
              ),
              const SizedBox(height: AppSpacing.xl),
              const AdminSectionLabel('LIMITS AND FEES'),
              _Amount(
                label: 'Smallest group loan',
                value: _t.minAmount,
                enabled: edit,
                onChanged: (v) => _set(_t.copyWith(minAmount: v)),
              ),
              _Amount(
                label: 'Largest group loan',
                value: _t.maxAmount,
                enabled: edit,
                onChanged: (v) => _set(_t.copyWith(maxAmount: v)),
              ),
              _Amount(
                label: 'Flat management fee',
                value: _t.flatProcessingFee,
                enabled: edit,
                onChanged: (v) => _set(_t.copyWith(flatProcessingFee: v)),
              ),
              _Amount(
                label: 'Flat fee up to',
                value: _t.processingFeeThreshold,
                enabled: edit,
                onChanged: (v) => _set(_t.copyWith(processingFeeThreshold: v)),
              ),
              const SizedBox(height: AppSpacing.md),
              _Percent(
                label: 'Management fee above the threshold',
                value: _t.processingFeeRate,
                max: 0.05,
                divisions: 50,
                enabled: edit,
                onChanged: (v) => _set(_t.copyWith(processingFeeRate: v)),
              ),
              const SizedBox(height: AppSpacing.md),
              _Percent(
                label: 'Transaction fee on each repayment',
                value: _t.repaymentFeeRate,
                max: 0.2,
                divisions: 80,
                enabled: edit,
                onChanged: (v) => _set(_t.copyWith(repaymentFeeRate: v)),
              ),
              const SizedBox(height: AppSpacing.xl),
              const AdminSectionLabel('REPAYMENT'),
              KCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Weekly'),
                      value: _t.weeklyAllowed,
                      onChanged: edit ? (v) => _set(_t.copyWith(weeklyAllowed: v)) : null,
                    ),
                    const HairLine(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Monthly'),
                      value: _t.monthlyAllowed,
                      onChanged: edit ? (v) => _set(_t.copyWith(monthlyAllowed: v)) : null,
                    ),
                  ],
                ),
              ),
              if (!_t.weeklyAllowed && !_t.monthlyAllowed) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Offer weekly, monthly, or both.',
                  style: TextStyle(fontSize: 12, color: AppColors.danger),
                ),
              ],
              if (changed) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Tap Done, then save the settings, for these to take effect.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.gold),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.onMinus,
    this.onPlus,
  });
  final String label;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) => KCard(
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        ),
        AdminNumberField(
          value: value.toDouble(),
          suffix: 'months',
          width: 120,
          min: 1,
          enabled: enabled,
          onChanged: (v) => onChanged(v.round()),
        ),
        IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_rounded)),
        IconButton(onPressed: onPlus, icon: const Icon(Icons.add_rounded)),
      ],
    ),
  );
}

class _Amount extends StatelessWidget {
  const _Amount({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: KCard(
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: AppSpacing.md),
          AdminNumberField(
            value: value,
            kind: AdminNumberKind.money,
            width: 150,
            enabled: enabled,
            onChanged: onChanged,
          ),
        ],
      ),
    ),
  );
}

class _Percent extends StatelessWidget {
  const _Percent({
    required this.label,
    required this.value,
    required this.max,
    required this.divisions,
    required this.enabled,
    required this.onChanged,
  });

  final String label;

  /// A fraction: 0.02 for 2%.
  final double value;
  final double max;
  final int divisions;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => KCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: AppSpacing.md),
            AdminNumberField(
              value: value,
              kind: AdminNumberKind.percent,
              width: 104,
              enabled: enabled,
              onChanged: onChanged,
            ),
          ],
        ),
        Slider(
          value: value.clamp(0, max),
          min: 0,
          max: max,
          divisions: divisions,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    ),
  );
}
