import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/pin_sheet.dart';
import '../../widgets/primitives.dart';
import '../../widgets/result_screen.dart';
import '../../data/models/platform_settings.dart';

/// Create a locked savings plan. The 17% is calculated live and paid the
/// instant the plan starts.
class CreatePlanScreen extends StatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final _amount = TextEditingController();
  final _title = TextEditingController(text: 'My savings goal');
  int _months = 12;
  bool _busy = false;

  double get _principal => parseAmount(_amount.text);
  double get _interest => Finance.savingsInterest(_principal, _months);
  double get _total => _principal + _interest;

  String? get _amountError {
    if (_principal == 0) return null;
    if (_principal < settings.minSavingsAmount) {
      return 'Minimum is ${settings.minSavingsAmount.asNairaFlat}';
    }
    final balance = context.read<AppState>().balance;
    if (_principal > balance) {
      return 'You only have ${balance.asNairaFlat} in your wallet';
    }
    return null;
  }

  bool get _canSubmit =>
      _principal >= settings.minSavingsAmount &&
      _amountError == null &&
      _title.text.trim().isNotEmpty;

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final confirmed = await confirmWithPin(
      context,
      title: 'Lock this away',
      amountLabel: 'You are locking',
      amount: _principal,
      details: [
        ('Lock period', _labelFor(_months)),
        ('Interest paid now', _interest.asNaira),
        ('Matures', Finance.addMonths(DateTime.now(), _months).asDay),
      ],
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final app = context.read<AppState>();
    final plan = await app.createFixedPlan(
      title: _title.text.trim(),
      principal: _principal,
      months: _months,
    );
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          title: '${plan.interestPaid.asNaira} is yours',
          message:
              'Your 17% return has been paid into your wallet right now. Your principal stays locked until ${plan.maturityDate.asDay}.',
          details: [
            ('Plan', plan.title),
            ('Principal locked', plan.principal.asNaira),
            ('Interest paid upfront', plan.interestPaid.asNaira),
            ('Lock period', _labelFor(plan.lockMonths)),
            ('Matures on', plan.maturityDate.asDay),
          ],
          primaryLabel: 'Back to dashboard',
        ),
      ),
    );
  }

  static String _labelFor(int months) {
    if (months % 12 == 0 && months >= 12) {
      final y = months ~/ 12;
      return '$y ${y == 1 ? 'year' : 'years'}';
    }
    return '$months ${months == 1 ? 'month' : 'months'}';
  }

  @override
  Widget build(BuildContext context) {
    final balance = context.select<AppState, double>((s) => s.balance);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fixed Savings'),
        leading: const BackButton(),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.nightGradient),
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
                          const Text(
                            'How much are you locking?',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AmountField(
                            controller: _amount,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Wallet: ${balance.asNaira}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          if (_amountError != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _amountError!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          QuickAmounts(
                            amounts: const [
                              10000,
                              50000,
                              100000,
                              500000,
                              1000000,
                            ],
                            onPick: (a) => setState(
                              () => _amount.text = a.toInt().asPlain,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    const Text(
                      'LOCK PERIOD',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final p in kLockPresets)
                          _PeriodChip(
                            label: p.label,
                            selected: _months == p.months,
                            onTap: () => setState(() => _months = p.months),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _MonthSlider(
                      months: _months,
                      onChanged: (m) => setState(() => _months = m),
                    ),

                    const SizedBox(height: AppSpacing.xxl),
                    _ReturnPreview(
                      principal: _principal,
                      interest: _interest,
                      total: _total,
                      months: _months,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    KField(
                      label: 'Name this plan',
                      hint: 'Rent, school fees, my first car...',
                      controller: _title,
                      prefixIcon: Icons.label_outline_rounded,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 32,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _NoBreakWarning(),
                    const SizedBox(height: AppSpacing.lg),
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
                decoration: const BoxDecoration(
                  color: AppColors.black,
                  border: Border(top: BorderSide(color: AppColors.stroke)),
                ),
                child: GoldButton(
                  label: _principal == 0
                      ? 'Lock and get paid'
                      : 'Lock and receive ${_interest.asNairaFlat} now',
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

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.goldWash : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.stroke,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.gold : AppColors.textSecondary,
        ),
      ),
    ),
  );
}

class _MonthSlider extends StatelessWidget {
  const _MonthSlider({required this.months, required this.onChanged});

  final int months;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Fine-tune',
            style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
          ),
          Text(
            '$months ${months == 1 ? 'month' : 'months'}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
        ],
      ),
      Slider(
        value: months.toDouble(),
        min: settings.minLockMonths.toDouble(),
        max: settings.maxLockMonths.toDouble(),
        divisions: settings.maxLockMonths - settings.minLockMonths,
        onChanged: (v) => onChanged(v.round()),
      ),
      const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '1 month',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
          Text(
            '5 years',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    ],
  );
}

class _ReturnPreview extends StatelessWidget {
  const _ReturnPreview({
    required this.principal,
    required this.interest,
    required this.total,
    required this.months,
  });

  final double principal;
  final double interest;
  final double total;
  final int months;

  @override
  Widget build(BuildContext context) {
    final yieldPct = Finance.effectiveYieldPct(months);

    return KCard(
      gradient: AppColors.cardGradient,
      borderColor: AppColors.gold.withValues(alpha: 0.28),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 17, color: AppColors.gold),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Paid into your wallet immediately',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
              ),
              StatusPill(
                label: '${yieldPct.toStringAsFixed(1)}% total',
                color: AppColors.success,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              interest.asNaira,
              key: ValueKey(interest),
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.4,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const HairLine(),
          const SizedBox(height: AppSpacing.md),
          _Row(label: 'You lock', value: principal.asNaira),
          const SizedBox(height: 7),
          _Row(
            label: 'Interest (17% p.a.)',
            value: '+${interest.asNaira}',
            valueColor: AppColors.success,
          ),
          const SizedBox(height: 7),
          _Row(
            label: 'Value at maturity',
            value: total.asNaira,
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: bold ? 14.5 : 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
          color: valueColor ?? AppColors.textPrimary,
        ),
      ),
    ],
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
        const Text(
          'HOW IT WORKS',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final line in [
          'Your ${settings.savingsRatePct.toStringAsFixed(0)}% annual return is calculated for the full lock period and paid into your wallet the second the plan starts.',
          'You can spend that return immediately — it is yours the moment the plan opens.',
          'Your principal stays locked until maturity, then returns to your wallet in full.',
          'You can top a Fixed plan up whenever you like, and each top-up earns its own return immediately.',
          'What you cannot do is take money out. A Fixed plan cannot be broken — the principal is untouchable until the maturity date.',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
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
                    style: const TextStyle(
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
  ).animate().fadeIn();
}


/// Fixed Savings is irreversible, so the customer is told before they commit.
class _NoBreakWarning extends StatelessWidget {
  const _NoBreakWarning();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.infoWash,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.info.withValues(alpha: 0.32)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.shield_rounded, size: 19, color: AppColors.info),
        const SizedBox(width: AppSpacing.md),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This cannot be broken',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.info,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'You can always add more, but there is no early exit — not for any reason. Your principal is released only on the maturity date. If you may need the money sooner, choose Target Savings instead.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
