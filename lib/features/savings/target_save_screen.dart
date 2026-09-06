import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/models/platform_settings.dart';
import '../../data/api/api_exception.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/pin_sheet.dart';
import '../../widgets/primitives.dart';
import '../../widgets/result_screen.dart';
import 'new_plan_sheet.dart';

/// Target Savings: name a total and a term, and the app works out what has
/// to go in each day or week. The bonus rate rises with the term.
class TargetSaveScreen extends StatefulWidget {
  const TargetSaveScreen({super.key});

  @override
  State<TargetSaveScreen> createState() => _TargetSaveScreenState();
}

class _TargetSaveScreenState extends State<TargetSaveScreen> {
  final _title = TextEditingController(text: 'My savings target');
  final _goal = TextEditingController();
  AutoFrequency _frequency = AutoFrequency.daily;
  late int _months = settings.minTargetMonths;
  String _emoji = '🎯';
  bool _busy = false;

  static const _frequencies = [AutoFrequency.daily, AutoFrequency.weekly];

  double get _goalAmount => parseAmount(_goal.text);
  int get _days => Finance.targetDays(_months);
  int get _runs => Finance.targetRuns(_frequency, _months);
  double get _perDeposit =>
      Finance.targetPerDeposit(_goalAmount, _frequency, _months);
  double get _rate => Finance.targetRateFor(_months);
  double get _bonus => _goalAmount * _rate;

  bool get _canSubmit =>
      _goalAmount >= settings.minSavingsAmount &&
      _title.text.trim().isNotEmpty &&
      !_busy;

  @override
  void dispose() {
    _title.dispose();
    _goal.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    // Opening a target plan commits the customer to a contribution every cycle,
    // and the first is taken now. Gated like every other movement of money.
    final pin = await confirmWithPin(
      context,
      title: 'Start ${_title.text.trim()}',
      amountLabel: 'Saving towards ${_goalAmount.asNaira}',
      amount: _perDeposit,
      details: [
        ('Goal', _goalAmount.asNaira),
        ('Every', _frequency.label),
        ('For', '$_months months'),
      ],
    );
    if (pin == null || !mounted) return;

    setState(() => _busy = true);

    final SavingsPlan plan;
    try {
      plan = await context.read<AppState>().createTargetPlan(
        title: _title.text.trim(),
        emoji: _emoji,
        goal: _goalAmount,
        frequency: _frequency,
        months: _months,
        pin: pin,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, e.message, error: true);
      return;
    }
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          title: '$_emoji  ${plan.title}',
          message:
              'To reach ${_goalAmount.asNaira} in $_months months, we will move ${_perDeposit.asNaira} ${_frequency.adverb}. Finish it and you collect ${_bonus.asNaira}.',
          details: [
            ('Your target', _goalAmount.asNaira),
            ('Term', '$_months months ($_days days)'),
            (
              _frequency == AutoFrequency.daily ? 'Every day' : 'Every week',
              _perDeposit.asNaira,
            ),
            ('Number of deposits', '$_runs'),
            (
              'Bonus at ${(_rate * 100).toStringAsFixed(1)}%',
              _bonus.asNaira,
            ),
            ('Total at maturity', (_goalAmount + _bonus).asNaira),
          ],
          primaryLabel: 'Done',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Target Savings')),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'How much do you want to save?',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AmountField(
                            controller: _goal,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          QuickAmounts(
                            amounts: const [
                              50000,
                              100000,
                              250000,
                              500000,
                              1000000,
                            ],
                            onPick: (a) => setState(
                              () => _goal.text = a.toInt().asPlain,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _Label('OVER HOW LONG'),
                        Text(
                          '$_months months • $_days days',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _months.toDouble().clamp(
                        settings.minTargetMonths.toDouble(),
                        60,
                      ),
                      min: settings.minTargetMonths.toDouble(),
                      max: 60,
                      divisions: 60 - settings.minTargetMonths,
                      onChanged: (v) => setState(() => _months = v.round()),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${settings.minTargetMonths} months minimum',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        Text(
                          '5 years',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _TierStrip(months: _months),

                    const SizedBox(height: AppSpacing.xl),
                    const _Label('HOW OFTEN'),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        for (final f in _frequencies)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.sm,
                              ),
                              child: _Chip(
                                label: f.label,
                                selected: _frequency == f,
                                onTap: () => setState(() => _frequency = f),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xxl),
                    if (_goalAmount > 0)
                      _Breakdown(
                        goal: _goalAmount,
                        perDeposit: _perDeposit,
                        frequency: _frequency,
                        months: _months,
                        days: _days,
                        runs: _runs,
                        rate: _rate,
                        bonus: _bonus,
                      ),

                    const SizedBox(height: AppSpacing.xl),
                    KField(
                      label: 'Name this plan',
                      hint: 'School fees, rent, my shop...',
                      controller: _title,
                      prefixIcon: Icons.label_outline_rounded,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 32,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    EmojiPicker(
                      selected: _emoji,
                      onPick: (e) => setState(() => _emoji = e),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _Rules(),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                decoration: BoxDecoration(
                  color: AppColors.black,
                  border: Border(top: BorderSide(color: AppColors.stroke)),
                ),
                child: GoldButton(
                  label: _goalAmount > 0
                      ? 'Save ${_perDeposit.asNairaFlat} ${_frequency.adverb}'
                      : 'Start Target Savings',
                  icon: Icons.calendar_month_rounded,
                  loading: _busy,
                  onPressed: _canSubmit ? _submit : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the three bonus tiers with the active one highlighted, so the
/// reward for committing longer is visible while the slider moves.
class _TierStrip extends StatelessWidget {
  const _TierStrip({required this.months});
  final int months;

  @override
  Widget build(BuildContext context) {
    final tiers = <(String, double, bool)>[
      (
        '3-5 mo',
        settings.targetRateShort,
        months < settings.targetTierMedium,
      ),
      (
        '6-11 mo',
        settings.targetRateMedium,
        months >= settings.targetTierMedium &&
            months < settings.targetTierLong,
      ),
      (
        '1 yr +',
        settings.targetRateLong,
        months >= settings.targetTierLong,
      ),
    ];

    return Row(
      children: [
        for (final (label, rate, active) in tiers)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: active ? AppColors.successWash : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: active ? AppColors.success : AppColors.stroke,
                    width: active ? 1.4 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${(rate * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: active
                            ? AppColors.success
                            : AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? AppColors.textSecondary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.goal,
    required this.perDeposit,
    required this.frequency,
    required this.months,
    required this.days,
    required this.runs,
    required this.rate,
    required this.bonus,
  });

  final double goal;
  final double perDeposit;
  final AutoFrequency frequency;
  final int months;
  final int days;
  final int runs;
  final double rate;
  final double bonus;

  @override
  Widget build(BuildContext context) => KCard(
    gradient: AppColors.cardGradient,
    borderColor: AppColors.success.withValues(alpha: 0.3),
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'That means saving',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Row(
            key: ValueKey(perDeposit),
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    perDeposit.asNaira,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.4,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5, left: 6),
                child: Text(
                  frequency == AutoFrequency.daily ? 'a day' : 'a week',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const HairLine(),
        const SizedBox(height: AppSpacing.md),
        _Row('Your target', goal.asNaira),
        _Row('Term', '$months months ($days days)'),
        _Row(
          'Deposits',
          '$runs ${frequency == AutoFrequency.daily ? 'daily' : 'weekly'}',
        ),
        _Row(
          'Bonus rate for this term',
          '${(rate * 100).toStringAsFixed(1)}%',
          color: AppColors.success,
        ),
        _Row(
          'Bonus on the final day',
          '+${bonus.asNaira}',
          color: AppColors.success,
        ),
        _Row('Total at maturity', (goal + bonus).asNaira, bold: true),
      ],
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.6,
      color: AppColors.textTertiary,
    ),
  );
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
      duration: const Duration(milliseconds: 180),
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.goldWash : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.stroke,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.gold : AppColors.textSecondary,
        ),
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.color, this.bold = false});
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: bold ? 14.5 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Rules extends StatelessWidget {
  const _Rules();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.stroke),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HOW TARGET SAVINGS WORKS',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final line in [
          'You name the total and the term. We divide it into equal deposits and move them from your wallet automatically.',
          'The longer you commit, the bigger the bonus: ${settings.targetShortPct.toStringAsFixed(1)}% for 3-5 months, ${settings.targetMediumPct.toStringAsFixed(1)}% for 6-11 months, ${settings.targetLongPct.toStringAsFixed(1)}% from a year upward.',
          'Nothing is paid along the way. The bonus lands as one payment on the final day.',
          'You can break the plan at any time and every naira you saved comes straight back to your wallet.',
          'But breaking it forfeits the entire bonus — there is no partial payout.',
          'If your wallet is short on a due date we skip that deposit rather than overdraw you, and try again next cycle.',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 5, right: 9),
                  child: SizedBox(
                    width: 4,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    line,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
