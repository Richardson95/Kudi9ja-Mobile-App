import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../widgets/primitives.dart';
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
  int _tenure = 1;

  void _set(LendingTerms next) => setState(() => _t = next);

  Future<void> _typeAmount(String label, double current, ValueChanged<double> apply) async {
    final controller = TextEditingController(text: current.round().asPlain);
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsFormatter()],
          decoration: const InputDecoration(prefixText: '₦ '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, parseAmount(controller.text)),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value >= 0) apply(value);
  }

  @override
  Widget build(BuildContext context) {
    final edit = widget.canEdit;
    if (_tenure > _t.maxTenureMonths) _tenure = _t.maxTenureMonths;
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
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final m in _t.tenures)
                          ChoiceChip(
                            label: Text('${m}m'),
                            selected: _tenure == m,
                            onSelected: (_) => setState(() => _tenure = m),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '$_tenure ${_tenure == 1 ? 'month' : 'months'}: '
                      '${(_t.rateFor(_tenure) * 100).toStringAsFixed(1)}% flat'
                      '${widget.standard.rateFor(_tenure) != _t.rateFor(_tenure) ? '  (standard ${(widget.standard.rateFor(_tenure) * 100).toStringAsFixed(1)}%)' : ''}',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                    Slider(
                      value: (_t.rateFor(_tenure) * 100).clamp(1, 200),
                      min: 1,
                      max: 200,
                      divisions: 398,
                      onChanged: edit
                          ? (v) => _set(_t.copyWith(rates: {..._t.rates, _tenure: v / 100}))
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _Stepper(
                label: 'Longest term',
                value: '${_t.maxTenureMonths} months',
                onMinus: edit && _t.maxTenureMonths > 1
                    ? () => _set(_t.copyWith(maxTenureMonths: _t.maxTenureMonths - 1))
                    : null,
                onPlus: edit
                    ? () {
                        final next = _t.maxTenureMonths + 1;
                        // Every tenure offered must be priced: a new month
                        // starts at the rate of the one before it.
                        _set(_t.copyWith(
                          maxTenureMonths: next,
                          rates: {..._t.rates, next: _t.rates[next] ?? _t.rateFor(next)},
                        ));
                      }
                    : null,
              ),
              const SizedBox(height: AppSpacing.xl),
              const AdminSectionLabel('LIMITS AND FEES'),
              _Amount(
                label: 'Smallest group loan',
                value: _t.minAmount,
                onTap: edit
                    ? () => _typeAmount('Smallest group loan', _t.minAmount,
                        (v) => _set(_t.copyWith(minAmount: v)))
                    : null,
              ),
              _Amount(
                label: 'Largest group loan',
                value: _t.maxAmount,
                onTap: edit
                    ? () => _typeAmount('Largest group loan', _t.maxAmount,
                        (v) => _set(_t.copyWith(maxAmount: v)))
                    : null,
              ),
              _Amount(
                label: 'Flat management fee',
                value: _t.flatProcessingFee,
                onTap: edit
                    ? () => _typeAmount('Flat management fee', _t.flatProcessingFee,
                        (v) => _set(_t.copyWith(flatProcessingFee: v)))
                    : null,
              ),
              _Amount(
                label: 'Flat fee up to',
                value: _t.processingFeeThreshold,
                onTap: edit
                    ? () => _typeAmount('Flat fee up to', _t.processingFeeThreshold,
                        (v) => _set(_t.copyWith(processingFeeThreshold: v)))
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              _Percent(
                label: 'Management fee above the threshold',
                value: _t.processingFeeRate,
                max: 0.05,
                divisions: 50,
                onChanged: edit ? (v) => _set(_t.copyWith(processingFeeRate: v)) : null,
              ),
              const SizedBox(height: AppSpacing.md),
              _Percent(
                label: 'Transaction fee on each repayment',
                value: _t.repaymentFeeRate,
                max: 0.2,
                divisions: 80,
                onChanged: edit ? (v) => _set(_t.copyWith(repaymentFeeRate: v)) : null,
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
  const _Stepper({required this.label, required this.value, this.onMinus, this.onPlus});
  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) => KCard(
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        ),
        IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_rounded)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        IconButton(onPressed: onPlus, icon: const Icon(Icons.add_rounded)),
      ],
    ),
  );
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.value, this.onTap});
  final String label;
  final double value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: KCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
          Text(value.asNairaFlat, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.edit_outlined, size: 16, color: AppColors.textTertiary),
          ],
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
    this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final int divisions;
  final ValueChanged<double>? onChanged;

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
            Text(
              '${(value * 100).toStringAsFixed(2)}%',
              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.gold),
            ),
          ],
        ),
        Slider(
          value: value.clamp(0, max),
          min: 0,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}
