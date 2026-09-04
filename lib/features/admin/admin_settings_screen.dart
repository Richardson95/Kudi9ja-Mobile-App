import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/admin.dart';
import '../../data/models/platform_settings.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import 'admin_shell.dart';

/// Every rate, limit and switch that shapes the product. Changes take effect
/// across the whole app the moment they are saved.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late PlatformSettings _draft = settings;
  bool _saving = false;

  late final _accountName = TextEditingController(
    text: settings.companyAccountName,
  );
  late final _accountNumber = TextEditingController(
    text: settings.companyAccountNumber,
  );
  late final _bank = TextEditingController(text: settings.companyBank);

  /// Which tenure's rate the slider below the picker is editing.
  int _rateTenure = 1;

  @override
  void dispose() {
    _accountName.dispose();
    _accountNumber.dispose();
    _bank.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _draft.savingsAnnualRate != settings.savingsAnnualRate ||
      _draft.minLockDays != settings.minLockDays ||
      _draft.maxLockDays != settings.maxLockDays ||
      _draft.daysPerYear != settings.daysPerYear ||
      _draft.minSavingsAmount != settings.minSavingsAmount ||
      _draft.targetRateShort != settings.targetRateShort ||
      _draft.targetRateMedium != settings.targetRateMedium ||
      _draft.targetRateLong != settings.targetRateLong ||
      _draft.minTargetMonths != settings.minTargetMonths ||
      _draft.minLoanAmount != settings.minLoanAmount ||
      _draft.maxLoanAmount != settings.maxLoanAmount ||
      !_draft.sameLoanRatesAs(settings) ||
      _draft.maxLoanTenureMonths != settings.maxLoanTenureMonths ||
      _draft.flatProcessingFee != settings.flatProcessingFee ||
      _draft.processingFeeThreshold != settings.processingFeeThreshold ||
      _draft.loanProcessingFeeRate != settings.loanProcessingFeeRate ||
      _draft.dailyTransferLimit != settings.dailyTransferLimit ||
      _draft.welcomeBonus != settings.welcomeBonus ||
      _draft.savingsEnabled != settings.savingsEnabled ||
      _draft.lendingEnabled != settings.lendingEnabled ||
      _draft.thriftEnabled != settings.thriftEnabled ||
      _draft.maintenanceMode != settings.maintenanceMode ||
      _draft.companyAccountName != settings.companyAccountName ||
      _draft.companyAccountNumber != settings.companyAccountNumber ||
      _draft.companyBank != settings.companyBank ||
      _draft.maxSavingsAmount != settings.maxSavingsAmount ||
      _draft.targetTierMedium != settings.targetTierMedium ||
      _draft.targetTierLong != settings.targetTierLong ||
      _draft.daysPerSavingsMonth != settings.daysPerSavingsMonth ||
      _draft.earlyPayoffRebateShare != settings.earlyPayoffRebateShare ||
      _draft.loanBaseCap != settings.loanBaseCap ||
      _draft.loanSavingsMultiple != settings.loanSavingsMultiple ||
      _draft.loanScoreBaseline != settings.loanScoreBaseline ||
      _draft.loanScorePerPoint != settings.loanScorePerPoint ||
      _draft.loanOfferRounding != settings.loanOfferRounding ||
      _draft.creditBaseScore != settings.creditBaseScore ||
      _draft.creditPointsPerPlan != settings.creditPointsPerPlan ||
      _draft.creditPlanPointsCap != settings.creditPlanPointsCap ||
      _draft.creditNairaPerSavingsPoint !=
          settings.creditNairaPerSavingsPoint ||
      _draft.creditSavingsPointsCap != settings.creditSavingsPointsCap ||
      _draft.creditPointsPerRepaidLoan != settings.creditPointsPerRepaidLoan ||
      _draft.creditRepaidPointsCap != settings.creditRepaidPointsCap ||
      _draft.creditOverduePenalty != settings.creditOverduePenalty ||
      _draft.creditVerifiedBonus != settings.creditVerifiedBonus ||
      _draft.creditScoreFloor != settings.creditScoreFloor ||
      _draft.creditScoreCeiling != settings.creditScoreCeiling ||
      _draft.maxPasscodeAttempts != settings.maxPasscodeAttempts ||
      _draft.lockTimeoutMinutes != settings.lockTimeoutMinutes ||
      _draft.minDepositAmount != settings.minDepositAmount ||
      _draft.minWithdrawalAmount != settings.minWithdrawalAmount ||
      _draft.minCircleContribution != settings.minCircleContribution ||
      _draft.minCircleMembers != settings.minCircleMembers ||
      _draft.maxCircleMembers != settings.maxCircleMembers ||
      _draft.otpResendSeconds != settings.otpResendSeconds;

  /// A rate for a slider label: no decimal point unless there is one.
  static String _ratePct(double pct) =>
      '${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 1)}%';

  /// Human-readable list of what this save will change — goes to the audit log.
  List<String> get _changes {
    final out = <String>[];
    void cmp(String label, Object before, Object after) {
      if (before != after) out.add('$label: $before → $after');
    }

    cmp(
      'Savings rate',
      '${settings.savingsRatePct.toStringAsFixed(2)}%',
      '${_draft.savingsRatePct.toStringAsFixed(2)}%',
    );
    cmp(
      'Min lock',
      '${settings.minLockDays}d',
      '${_draft.minLockDays}d',
    );
    cmp(
      'Max lock',
      '${settings.maxLockDays}d',
      '${_draft.maxLockDays}d',
    );
    cmp(
      'Days per year',
      '${settings.daysPerYear}',
      '${_draft.daysPerYear}',
    );
    cmp(
      'Min savings',
      settings.minSavingsAmount.asNairaFlat,
      _draft.minSavingsAmount.asNairaFlat,
    );
    cmp(
      'Target bonus 3-5m',
      '${settings.targetShortPct.toStringAsFixed(2)}%',
      '${_draft.targetShortPct.toStringAsFixed(2)}%',
    );
    cmp(
      'Target bonus 6-11m',
      '${settings.targetMediumPct.toStringAsFixed(2)}%',
      '${_draft.targetMediumPct.toStringAsFixed(2)}%',
    );
    cmp(
      'Target bonus 12m+',
      '${settings.targetLongPct.toStringAsFixed(2)}%',
      '${_draft.targetLongPct.toStringAsFixed(2)}%',
    );
    cmp(
      'Target minimum',
      '${settings.minTargetMonths}m',
      '${_draft.minTargetMonths}m',
    );
    cmp(
      'Min loan',
      settings.minLoanAmount.asNairaFlat,
      _draft.minLoanAmount.asNairaFlat,
    );
    cmp(
      'Max loan',
      settings.maxLoanAmount.asNairaFlat,
      _draft.maxLoanAmount.asNairaFlat,
    );
    for (final months in {..._draft.loanRates.keys, ...settings.loanRates.keys}
        .toList()
      ..sort()) {
      cmp(
        'Loan rate ${months}m',
        '${settings.loanRatePctFor(months).toStringAsFixed(2)}%',
        '${_draft.loanRatePctFor(months).toStringAsFixed(2)}%',
      );
    }
    cmp(
      'Max loan tenure',
      '${settings.maxLoanTenureMonths}m',
      '${_draft.maxLoanTenureMonths}m',
    );
    cmp(
      'Management fee (flat)',
      settings.flatProcessingFee.asNairaFlat,
      _draft.flatProcessingFee.asNairaFlat,
    );
    cmp(
      'Management fee threshold',
      settings.processingFeeThreshold.asNairaFlat,
      _draft.processingFeeThreshold.asNairaFlat,
    );
    cmp(
      'Management fee rate above threshold',
      '${settings.feeRatePct.toStringAsFixed(2)}%',
      '${_draft.feeRatePct.toStringAsFixed(2)}%',
    );
    cmp(
      'Transfer limit',
      settings.dailyTransferLimit.asNairaFlat,
      _draft.dailyTransferLimit.asNairaFlat,
    );
    cmp(
      'Welcome bonus',
      settings.welcomeBonus.asNairaFlat,
      _draft.welcomeBonus.asNairaFlat,
    );
    cmp('Savings', settings.savingsEnabled, _draft.savingsEnabled);
    cmp('Lending', settings.lendingEnabled, _draft.lendingEnabled);
    cmp('Ajo circles', settings.thriftEnabled, _draft.thriftEnabled);
    cmp('Maintenance', settings.maintenanceMode, _draft.maintenanceMode);
    cmp(
      'Collection account',
      settings.companyAccountNumber,
      _draft.companyAccountNumber,
    );
    cmp('Account name', settings.companyAccountName, _draft.companyAccountName);
    cmp('Collection bank', settings.companyBank, _draft.companyBank);
    cmp(
      'Max savings plan',
      settings.maxSavingsAmount.asNairaFlat,
      _draft.maxSavingsAmount.asNairaFlat,
    );
    cmp(
      'Base loan offer',
      settings.loanBaseCap.asNairaFlat,
      _draft.loanBaseCap.asNairaFlat,
    );
    cmp(
      'Per score point',
      settings.loanScorePerPoint.asNairaFlat,
      _draft.loanScorePerPoint.asNairaFlat,
    );
    cmp(
      'Offer rounding',
      settings.loanOfferRounding.asNairaFlat,
      _draft.loanOfferRounding.asNairaFlat,
    );
    cmp(
      'Naira per score point',
      settings.creditNairaPerSavingsPoint.asNairaFlat,
      _draft.creditNairaPerSavingsPoint.asNairaFlat,
    );
    cmp(
      'Target middle tier',
      '${settings.targetTierMedium}m',
      '${_draft.targetTierMedium}m',
    );
    cmp(
      'Target top tier',
      '${settings.targetTierLong}m',
      '${_draft.targetTierLong}m',
    );
    cmp(
      'Days per Target month',
      '${settings.daysPerSavingsMonth}d',
      '${_draft.daysPerSavingsMonth}d',
    );
    cmp(
      'Score baseline',
      '${settings.loanScoreBaseline} pts',
      '${_draft.loanScoreBaseline} pts',
    );
    cmp(
      'Credit base score',
      '${settings.creditBaseScore} pts',
      '${_draft.creditBaseScore} pts',
    );
    cmp(
      'Points per plan',
      '${settings.creditPointsPerPlan} pts',
      '${_draft.creditPointsPerPlan} pts',
    );
    cmp(
      'Plan points cap',
      '${settings.creditPlanPointsCap} pts',
      '${_draft.creditPlanPointsCap} pts',
    );
    cmp(
      'Savings points cap',
      '${settings.creditSavingsPointsCap} pts',
      '${_draft.creditSavingsPointsCap} pts',
    );
    cmp(
      'Points per repaid loan',
      '${settings.creditPointsPerRepaidLoan} pts',
      '${_draft.creditPointsPerRepaidLoan} pts',
    );
    cmp(
      'Repaid points cap',
      '${settings.creditRepaidPointsCap} pts',
      '${_draft.creditRepaidPointsCap} pts',
    );
    cmp(
      'Overdue penalty',
      '${settings.creditOverduePenalty} pts',
      '${_draft.creditOverduePenalty} pts',
    );
    cmp(
      'Verified bonus',
      '${settings.creditVerifiedBonus} pts',
      '${_draft.creditVerifiedBonus} pts',
    );
    cmp(
      'Score floor',
      '${settings.creditScoreFloor} pts',
      '${_draft.creditScoreFloor} pts',
    );
    cmp(
      'Score ceiling',
      '${settings.creditScoreCeiling} pts',
      '${_draft.creditScoreCeiling} pts',
    );
    cmp(
      'Passcode attempts',
      '${settings.maxPasscodeAttempts} tries',
      '${_draft.maxPasscodeAttempts} tries',
    );
    cmp(
      'Lock timeout',
      '${settings.lockTimeoutMinutes} min',
      '${_draft.lockTimeoutMinutes} min',
    );
    cmp(
      'Early settlement rebate',
      '${(settings.earlyPayoffRebateShare * 100).toStringAsFixed(0)}%',
      '${(_draft.earlyPayoffRebateShare * 100).toStringAsFixed(0)}%',
    );
    cmp(
      'Per naira saved',
      '${settings.loanSavingsMultiple.toStringAsFixed(2)}x',
      '${_draft.loanSavingsMultiple.toStringAsFixed(2)}x',
    );

    cmp(
      'Minimum pay-in',
      settings.minDepositAmount.asNairaFlat,
      _draft.minDepositAmount.asNairaFlat,
    );
    cmp(
      'Minimum withdrawal',
      settings.minWithdrawalAmount.asNairaFlat,
      _draft.minWithdrawalAmount.asNairaFlat,
    );
    cmp(
      'Minimum circle contribution',
      settings.minCircleContribution.asNairaFlat,
      _draft.minCircleContribution.asNairaFlat,
    );
    cmp(
      'Smallest circle',
      '${settings.minCircleMembers}',
      '${_draft.minCircleMembers}',
    );
    cmp(
      'Largest circle',
      '${settings.maxCircleMembers}',
      '${_draft.maxCircleMembers}',
    );
    cmp(
      'OTP resend delay',
      '${settings.otpResendSeconds}s',
      '${_draft.otpResendSeconds}s',
    );

    return out;
  }

  String? get _validationError {
    if (_draft.minLockDays >= _draft.maxLockDays) {
      return 'The minimum lock must be shorter than the maximum.';
    }
    if (_draft.minLoanAmount >= _draft.maxLoanAmount) {
      return 'The minimum loan must be below the maximum.';
    }
    if (_draft.savingsAnnualRate <= 0) {
      return 'The savings rate has to be above zero.';
    }
    return null;
  }

  Future<void> _save() async {
    final error = _validationError;
    if (error != null) {
      showToast(context, error, error: true);
      return;
    }

    final summary = _changes;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apply these changes?'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'These take effect for every customer immediately. Existing plans and loans keep the terms they were opened on.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final c in summary)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• $c',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.gold,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Apply',
              style: TextStyle(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    await context.read<AppState>().updatePlatformSettings(_draft, summary);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _draft = settings;
    });
    HapticFeedback.heavyImpact();
    showToast(context, 'Settings applied across the app');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final canEdit = app.adminRole.canEditSettings;

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            _dirty ? 110 : AppSpacing.huge,
          ),
          children: [
            if (!canEdit)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.lg),
                child: _ReadOnlyNote(),
              ),

            const AdminSectionLabel('SAVINGS'),
            _RateCard(
              label: 'Fixed Savings rate',
              helper:
                  'Paid to the customer upfront, pro-rated over the lock period',
              valueLabel:
                  '${_draft.savingsRatePct.toStringAsFixed(_draft.savingsRatePct % 1 == 0 ? 0 : 1)}%',
              value: _draft.savingsRatePct,
              min: 1,
              max: 40,
              divisions: 78,
              enabled: canEdit,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(savingsAnnualRate: v / 100),
              ),
              example:
                  '₦100,000 for a year pays ${(100000 * _draft.savingsAnnualRate).asNairaFlat} on day one',
            ),
            const SizedBox(height: AppSpacing.md),
            _RateCard(
              label: 'Target bonus — 3 to 5 months',
              helper: 'Paid on the final day, forfeited if the plan is broken',
              valueLabel: '${_draft.targetShortPct.toStringAsFixed(1)}%',
              value: _draft.targetShortPct,
              min: 0.5,
              max: 20,
              divisions: 39,
              enabled: canEdit,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(targetRateShort: v / 100),
              ),
              example:
                  '₦100,000 saved over 3 months pays ${(100000 * _draft.targetRateShort).asNairaFlat}',
            ),
            const SizedBox(height: AppSpacing.md),
            _RateCard(
              label: 'Target bonus — 6 to 11 months',
              helper: 'The middle tier',
              valueLabel: '${_draft.targetMediumPct.toStringAsFixed(1)}%',
              value: _draft.targetMediumPct,
              min: 0.5,
              max: 30,
              divisions: 59,
              enabled: canEdit,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(targetRateMedium: v / 100),
              ),
              example:
                  '₦100,000 saved over 6 months pays ${(100000 * _draft.targetRateMedium).asNairaFlat}',
            ),
            const SizedBox(height: AppSpacing.md),
            _RateCard(
              label: 'Target bonus — 1 year and above',
              helper: 'The top tier, however long the term runs',
              valueLabel: '${_draft.targetLongPct.toStringAsFixed(1)}%',
              value: _draft.targetLongPct,
              min: 0.5,
              max: 40,
              divisions: 79,
              enabled: canEdit,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(targetRateLong: v / 100),
              ),
              example:
                  '₦100,000 saved over a year pays ${(100000 * _draft.targetRateLong).asNairaFlat}',
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Target Savings minimum term',
              value:
                  '${_draft.minTargetMonths} ${_draft.minTargetMonths == 1 ? 'month' : 'months'}',
              enabled: canEdit,
              onMinus: _draft.minTargetMonths > 1
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        minTargetMonths: _draft.minTargetMonths - 1,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  minTargetMonths: _draft.minTargetMonths + 1,
                ),
              ),
              typedValue: _draft.minTargetMonths,
              unit: ' months',
              min: 0,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(minTargetMonths: v.toInt()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Minimum lock',
              value: lockPeriodLabel(_draft.minLockDays),
              enabled: canEdit,
              onMinus: _draft.minLockDays > 1
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        minLockDays: _draft.minLockDays - 1,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  minLockDays: _draft.minLockDays + 1,
                ),
              ),
              typedValue: _draft.minLockDays,
              unit: ' days',
              min: 0,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(minLockDays: v.toInt()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Maximum lock',
              value: lockPeriodLabel(_draft.maxLockDays),
              enabled: canEdit,
              onMinus: _draft.maxLockDays > _draft.minLockDays + 30
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        maxLockDays: _draft.maxLockDays - 30,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  maxLockDays: _draft.maxLockDays + 30,
                ),
              ),
              typedValue: _draft.maxLockDays,
              unit: ' days',
              min: 0,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(maxLockDays: v.toInt()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Days the annual rate spreads over',
              value: '${_draft.daysPerYear} days',
              enabled: canEdit,
              onMinus: _draft.daysPerYear > 1
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        daysPerYear: _draft.daysPerYear - 1,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  daysPerYear: _draft.daysPerYear + 1,
                ),
              ),
              typedValue: _draft.daysPerYear,
              unit: ' days',
              min: 0,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(daysPerYear: v.toInt()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _AmountCard(
              label: 'Minimum to open a plan',
              value: _draft.minSavingsAmount,
              enabled: canEdit,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(minSavingsAmount: v)),
            ),

            const SizedBox(height: AppSpacing.md),
            _AmountCard(
              label: 'Maximum for a single plan',
              value: _draft.maxSavingsAmount,
              step: 1000000,
              enabled: canEdit,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(maxSavingsAmount: v)),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Target bonus: middle tier starts at',
              value: '${_draft.targetTierMedium} months',
              enabled: canEdit,
              onMinus: _draft.targetTierMedium > _draft.minTargetMonths + 1
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        targetTierMedium: _draft.targetTierMedium - 1,
                      ),
                    )
                  : null,
              onPlus: _draft.targetTierMedium < _draft.targetTierLong - 1
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        targetTierMedium: _draft.targetTierMedium + 1,
                      ),
                    )
                  : null,
              typedValue: _draft.targetTierMedium,
              unit: ' months',
              min: 0,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(targetTierMedium: v.toInt()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Target bonus: top tier starts at',
              value: '${_draft.targetTierLong} months',
              enabled: canEdit,
              onMinus: _draft.targetTierLong > _draft.targetTierMedium + 1
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        targetTierLong: _draft.targetTierLong - 1,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  targetTierLong: _draft.targetTierLong + 1,
                ),
              ),
              typedValue: _draft.targetTierLong,
              unit: ' months',
              min: 0,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(targetTierLong: v.toInt()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Days counted as a Target month',
              value: '${_draft.daysPerSavingsMonth} days',
              enabled: canEdit,
              onMinus: _draft.daysPerSavingsMonth > 1
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        daysPerSavingsMonth: _draft.daysPerSavingsMonth - 1,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  daysPerSavingsMonth: _draft.daysPerSavingsMonth + 1,
                ),
              ),
              typedValue: _draft.daysPerSavingsMonth,
              unit: ' days',
              min: 0,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(daysPerSavingsMonth: v.toInt()),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
            const AdminSectionLabel('LENDING'),
            _TenureRatePicker(
              draft: _draft,
              selected: _rateTenure,
              onSelect: (t) => setState(() => _rateTenure = t),
            ),
            const SizedBox(height: AppSpacing.md),
            _RateCard(
              label:
                  'Loan interest — $_rateTenure '
                  '${_rateTenure == 1 ? 'month' : 'months'}',
              helper:
                  'One flat charge on the amount borrowed. Every tenure is '
                  'priced on its own — pick one above and set its rate here.',
              valueLabel: _ratePct(_draft.loanRatePctFor(_rateTenure)),
              value: _draft.loanRatePctFor(_rateTenure).clamp(1, 200),
              min: 1,
              max: 200,
              divisions: 398,
              enabled: canEdit,
              onChanged: (v) => setState(
                () => _draft = _draft.withLoanRate(_rateTenure, v / 100),
              ),
              example:
                  '₦200,000 repays '
                  '${(200000 * (1 + _draft.loanRateFor(_rateTenure))).asNairaFlat} '
                  'over $_rateTenure ${_rateTenure == 1 ? 'month' : 'months'} — '
                  '${(_draft.loanRatePctFor(_rateTenure) / _rateTenure).toStringAsFixed(2)}% a month',
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Maximum loan tenure',
              value:
                  '${_draft.maxLoanTenureMonths} ${_draft.maxLoanTenureMonths == 1 ? 'month' : 'months'}',
              enabled: canEdit,
              onMinus: _draft.maxLoanTenureMonths > 1
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        maxLoanTenureMonths: _draft.maxLoanTenureMonths - 1,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  maxLoanTenureMonths: _draft.maxLoanTenureMonths + 1,
                ),
              ),
              typedValue: _draft.maxLoanTenureMonths,
              unit: ' months',
              min: 0,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(maxLoanTenureMonths: v.toInt()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _AmountCard(
              label: 'Minimum loan',
              value: _draft.minLoanAmount,
              step: 10000,
              enabled: canEdit,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(minLoanAmount: v)),
            ),
            const SizedBox(height: AppSpacing.md),
            _AmountCard(
              label: 'Maximum loan',
              value: _draft.maxLoanAmount,
              step: 50000,
              enabled: canEdit,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(maxLoanAmount: v)),
            ),

            const SizedBox(height: AppSpacing.xl),
            const AdminSectionLabel('MANAGEMENT FEE'),
            _FeePreview(draft: _draft),
            const SizedBox(height: AppSpacing.md),
            _AmountCard(
              label: 'Flat fee up to and including the threshold',
              value: _draft.flatProcessingFee,
              step: 500,
              enabled: canEdit,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(flatProcessingFee: v),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _AmountCard(
              label: 'Threshold',
              value: _draft.processingFeeThreshold,
              step: 50000,
              enabled: canEdit,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(processingFeeThreshold: v),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _RateCard(
              label: 'Rate above the threshold',
              helper:
                  'Charged on the whole loan amount — not on the part above '
                  'the threshold — the moment a loan exceeds it',
              valueLabel: '${_draft.feeRatePct.toStringAsFixed(2)}%',
              value: _draft.feeRatePct,
              min: 0,
              max: 5,
              divisions: 50,
              enabled: canEdit,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(loanProcessingFeeRate: v / 100),
              ),
            ),

            const SizedBox(height: AppSpacing.md),
            _RateCard(
              label: 'Early settlement rebate',
              helper:
                  'The share of the interest on months that never ran, given '
                  'back when a borrower clears a loan early',
              valueLabel: _ratePct(_draft.earlyPayoffRebateShare * 100),
              value: (_draft.earlyPayoffRebateShare * 100).clamp(0, 100),
              min: 0,
              max: 100,
              divisions: 100,
              enabled: canEdit,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(earlyPayoffRebateShare: v / 100),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
            const AdminSectionLabel('WHAT A CUSTOMER IS OFFERED'),
            _OfferPreview(draft: _draft),
            const SizedBox(height: AppSpacing.md),
            _AmountCard(
              label: 'Base offer, before savings and score',
              value: _draft.loanBaseCap,
              step: 10000,
              enabled: canEdit,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(loanBaseCap: v)),
            ),
            const SizedBox(height: AppSpacing.md),
            _RateCard(
              label: 'Added per naira saved',
              helper: 'Every ₦1 a customer has saved adds this much to the offer',
              valueLabel: '${_draft.loanSavingsMultiple.toStringAsFixed(2)}x',
              value: _draft.loanSavingsMultiple.clamp(0, 5),
              min: 0,
              max: 5,
              divisions: 100,
              enabled: canEdit,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(loanSavingsMultiple: v),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _AmountCard(
              label: 'Added per credit-score point above the baseline',
              value: _draft.loanScorePerPoint,
              step: 50,
              enabled: canEdit,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(loanScorePerPoint: v),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Score baseline',
              value: '${_draft.loanScoreBaseline} points',
              enabled: canEdit,
              onMinus: () => setState(
                () => _draft = _draft.copyWith(
                  loanScoreBaseline: _draft.loanScoreBaseline - 10,
                ),
              ),
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  loanScoreBaseline: _draft.loanScoreBaseline + 10,
                ),
              ),
              typedValue: _draft.loanScoreBaseline,
              unit: ' points',
              min: 0,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(loanScoreBaseline: v.toInt()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _AmountCard(
              label: 'Offers rounded down to',
              value: _draft.loanOfferRounding,
              step: 1000,
              enabled: canEdit,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(loanOfferRounding: v),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
            const AdminSectionLabel('WALLET'),
            _AmountCard(
              label: 'Daily transfer limit',
              value: _draft.dailyTransferLimit,
              step: 100000,
              enabled: canEdit,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(dailyTransferLimit: v),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _AmountCard(
              label: 'Welcome bonus for new accounts',
              value: _draft.welcomeBonus,
              step: 500,
              enabled: canEdit,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(welcomeBonus: v)),
            ),


            const SizedBox(height: AppSpacing.xxl),
            const AdminSectionLabel('CREDIT SCORE'),
            _ScorePreview(draft: _draft),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Starting score',
              value: '${_draft.creditBaseScore} points',
              enabled: canEdit,
              onMinus: _draft.creditBaseScore > 0
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        creditBaseScore: _draft.creditBaseScore - 10,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  creditBaseScore: _draft.creditBaseScore + 10,
                ),
              ),
              typedValue: _draft.creditBaseScore,
              unit: ' points',
              min: 0,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(creditBaseScore: v.toInt()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Points per savings plan',
              value: '${_draft.creditPointsPerPlan} points',
              enabled: canEdit,
              onMinus: _draft.creditPointsPerPlan > 0
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        creditPointsPerPlan: _draft.creditPointsPerPlan - 1,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  creditPointsPerPlan: _draft.creditPointsPerPlan + 1,
                ),
              ),
              typedValue: _draft.creditPointsPerPlan,
              unit: ' points',
              min: 0,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(creditPointsPerPlan: v.toInt()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Cap on savings-plan points',
              value: '${_draft.creditPlanPointsCap} points',
              enabled: canEdit,
              onMinus: _draft.creditPlanPointsCap > 0
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        creditPlanPointsCap: _draft.creditPlanPointsCap - 10,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  creditPlanPointsCap: _draft.creditPlanPointsCap + 10,
                ),
              ),
              typedValue: _draft.creditPlanPointsCap,
              unit: ' points',
              min: 0,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(creditPlanPointsCap: v.toInt()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _AmountCard(
              label: 'Naira saved per score point',
              value: _draft.creditNairaPerSavingsPoint,
              step: 5000,
              enabled: canEdit,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(creditNairaPerSavingsPoint: v),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Cap on saved-amount points',
              value: '${_draft.creditSavingsPointsCap} points',
              enabled: canEdit,
              onMinus: _draft.creditSavingsPointsCap > 0
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        creditSavingsPointsCap: _draft.creditSavingsPointsCap - 10,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  creditSavingsPointsCap: _draft.creditSavingsPointsCap + 10,
                ),
              ),
              typedValue: _draft.creditSavingsPointsCap,
              unit: ' points',
              min: 0,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(creditSavingsPointsCap: v.toInt()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Points per loan repaid',
              value: '${_draft.creditPointsPerRepaidLoan} points',
              enabled: canEdit,
              onMinus: _draft.creditPointsPerRepaidLoan > 0
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        creditPointsPerRepaidLoan: _draft.creditPointsPerRepaidLoan - 5,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  creditPointsPerRepaidLoan: _draft.creditPointsPerRepaidLoan + 5,
                ),
              ),
              typedValue: _draft.creditPointsPerRepaidLoan,
              unit: ' points',
              min: 0,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(creditPointsPerRepaidLoan: v.toInt()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Cap on repayment points',
              value: '${_draft.creditRepaidPointsCap} points',
              enabled: canEdit,
              onMinus: _draft.creditRepaidPointsCap > 0
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        creditRepaidPointsCap: _draft.creditRepaidPointsCap - 10,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  creditRepaidPointsCap: _draft.creditRepaidPointsCap + 10,
                ),
              ),
              typedValue: _draft.creditRepaidPointsCap,
              unit: ' points',
              min: 0,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(creditRepaidPointsCap: v.toInt()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Penalty for an overdue loan',
              value: '-${_draft.creditOverduePenalty} points',
              enabled: canEdit,
              onMinus: _draft.creditOverduePenalty > 0
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        creditOverduePenalty: _draft.creditOverduePenalty - 10,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  creditOverduePenalty: _draft.creditOverduePenalty + 10,
                ),
              ),
              typedValue: _draft.creditOverduePenalty,
              unit: ' points',
              min: 0,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(creditOverduePenalty: v.toInt()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Bonus for full verification',
              value: '${_draft.creditVerifiedBonus} points',
              enabled: canEdit,
              onMinus: _draft.creditVerifiedBonus > 0
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        creditVerifiedBonus: _draft.creditVerifiedBonus - 5,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  creditVerifiedBonus: _draft.creditVerifiedBonus + 5,
                ),
              ),
              typedValue: _draft.creditVerifiedBonus,
              unit: ' points',
              min: 0,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(creditVerifiedBonus: v.toInt()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Lowest possible score',
              value: '${_draft.creditScoreFloor} points',
              enabled: canEdit,
              onMinus: _draft.creditScoreFloor > 0
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        creditScoreFloor: _draft.creditScoreFloor - 10,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  creditScoreFloor: _draft.creditScoreFloor + 10,
                ),
              ),
              typedValue: _draft.creditScoreFloor,
              unit: ' points',
              min: 0,
              max: _draft.creditScoreCeiling - 1,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(creditScoreFloor: v.toInt()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Highest possible score',
              value: '${_draft.creditScoreCeiling} points',
              enabled: canEdit,
              onMinus: _draft.creditScoreCeiling > 0
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        creditScoreCeiling: _draft.creditScoreCeiling - 10,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  creditScoreCeiling: _draft.creditScoreCeiling + 10,
                ),
              ),
              typedValue: _draft.creditScoreCeiling,
              unit: ' points',
              min: _draft.creditScoreFloor + 1,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(creditScoreCeiling: v.toInt()),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
            const AdminSectionLabel('SECURITY'),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Passcode attempts before lockout',
              value: '${_draft.maxPasscodeAttempts} tries',
              enabled: canEdit,
              onMinus: _draft.maxPasscodeAttempts > 1
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        maxPasscodeAttempts: _draft.maxPasscodeAttempts - 1,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  maxPasscodeAttempts: _draft.maxPasscodeAttempts + 1,
                ),
              ),
              typedValue: _draft.maxPasscodeAttempts,
              unit: ' tries',
              min: 0,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(maxPasscodeAttempts: v.toInt()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Lock the app after',
              value: '${_draft.lockTimeoutMinutes} min idle',
              enabled: canEdit,
              onMinus: _draft.lockTimeoutMinutes > 1
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        lockTimeoutMinutes: _draft.lockTimeoutMinutes - 1,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  lockTimeoutMinutes: _draft.lockTimeoutMinutes + 1,
                ),
              ),
              typedValue: _draft.lockTimeoutMinutes,
              unit: ' min',
              min: 0,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(lockTimeoutMinutes: v.toInt()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const KCard(
              child: Text(
                'Passcode and PIN lengths are fixed at 6 and 4 digits. Every '
                'customer code is stored as a hash of a code that length, so '
                'changing it would lock out everyone who already has one.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  color: AppColors.textTertiary,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
            const AdminSectionLabel('PAY-IN AND PAYOUT'),
            _AmountCard(
              label: 'Smallest pay-in we will match',
              value: _draft.minDepositAmount,
              step: 100,
              enabled: canEdit,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(minDepositAmount: v)),
            ),
            const SizedBox(height: AppSpacing.md),
            _AmountCard(
              label: 'Smallest withdrawal',
              value: _draft.minWithdrawalAmount,
              step: 100,
              enabled: canEdit,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(minWithdrawalAmount: v),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
            const AdminSectionLabel('THRIFT CIRCLES'),
            _AmountCard(
              label: 'Minimum contribution per cycle',
              value: _draft.minCircleContribution,
              step: 500,
              enabled: canEdit,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(minCircleContribution: v),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Smallest circle',
              value: '${_draft.minCircleMembers} members',
              enabled: canEdit,
              typedValue: _draft.minCircleMembers,
              unit: ' members',
              min: 2,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(minCircleMembers: v.toInt()),
              ),
              onMinus: _draft.minCircleMembers > 2
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        minCircleMembers: _draft.minCircleMembers - 1,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  minCircleMembers: _draft.minCircleMembers + 1,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'Largest circle',
              value: '${_draft.maxCircleMembers} members',
              enabled: canEdit,
              typedValue: _draft.maxCircleMembers,
              unit: ' members',
              min: 2,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(maxCircleMembers: v.toInt()),
              ),
              onMinus: _draft.maxCircleMembers > _draft.minCircleMembers
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        maxCircleMembers: _draft.maxCircleMembers - 1,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  maxCircleMembers: _draft.maxCircleMembers + 1,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperCard(
              label: 'One-time code resend delay',
              value: '${_draft.otpResendSeconds} seconds',
              enabled: canEdit,
              typedValue: _draft.otpResendSeconds,
              unit: ' seconds',
              min: 5,
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(otpResendSeconds: v.toInt()),
              ),
              onMinus: _draft.otpResendSeconds > 5
                  ? () => setState(
                      () => _draft = _draft.copyWith(
                        otpResendSeconds: _draft.otpResendSeconds - 5,
                      ),
                    )
                  : null,
              onPlus: () => setState(
                () => _draft = _draft.copyWith(
                  otpResendSeconds: _draft.otpResendSeconds + 5,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
            const AdminSectionLabel('COLLECTION ACCOUNT'),
            KCard(
              gradient: AppColors.cardGradient,
              borderColor: AppColors.gold.withValues(alpha: 0.24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Where every customer payment lands. Changing this changes what customers are told to pay into, everywhere in the app.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  KField(
                    label: 'Account name',
                    controller: _accountName,
                    prefixIcon: Icons.business_outlined,
                    enabled: canEdit,
                    onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(companyAccountName: v),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  KField(
                    label: 'Account number',
                    controller: _accountNumber,
                    prefixIcon: Icons.tag_rounded,
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    enabled: canEdit,
                    onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(companyAccountNumber: v),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  KField(
                    label: 'Bank',
                    controller: _bank,
                    prefixIcon: Icons.account_balance_outlined,
                    enabled: canEdit,
                    onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(companyBank: v),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
            const AdminSectionLabel('PRODUCT SWITCHES'),
            _SwitchCard(
              label: 'Savings',
              helper: 'Customers can open new savings plans',
              value: _draft.savingsEnabled,
              enabled: canEdit,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(savingsEnabled: v)),
            ),
            const SizedBox(height: AppSpacing.md),
            _SwitchCard(
              label: 'Lending',
              helper: 'Customers can request new loans',
              value: _draft.lendingEnabled,
              enabled: canEdit,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(lendingEnabled: v)),
            ),
            const SizedBox(height: AppSpacing.md),
            _SwitchCard(
              label: 'Ajo circles',
              helper: 'Customers can create or join savings circles',
              value: _draft.thriftEnabled,
              enabled: canEdit,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(thriftEnabled: v)),
            ),
            const SizedBox(height: AppSpacing.md),
            _SwitchCard(
              label: 'Maintenance mode',
              helper: 'Pauses every new plan and loan across the app',
              value: _draft.maintenanceMode,
              danger: true,
              enabled: canEdit,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(maintenanceMode: v)),
            ),

            const SizedBox(height: AppSpacing.xl),
            const Text(
              'Changing a rate never rewrites history. Plans and loans already open keep the terms they were created with; new ones use the values above.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),

        if (_dirty && canEdit)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.black,
                border: Border(top: BorderSide(color: AppColors.stroke)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GhostButton(
                      label: 'Discard',
                      onPressed: () => setState(() => _draft = settings),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: GoldButton(
                      label: 'Apply ${_changes.length} change${_changes.length == 1 ? '' : 's'}',
                      loading: _saving,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ReadOnlyNote extends StatelessWidget {
  const _ReadOnlyNote();

  @override
  Widget build(BuildContext context) => KCard(
    borderColor: AppColors.info.withValues(alpha: 0.3),
    child: const Row(
      children: [
        Icon(Icons.visibility_outlined, size: 18, color: AppColors.info),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            'Your role can view these settings but not change them.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ),
      ],
    ),
  );
}

/// The whole rate table at a glance: one tile per tenure, showing what that
/// tenure currently charges. Tapping a tile points the slider below at it, so
/// a 17-month rate is as reachable as a 1-month one.
class _TenureRatePicker extends StatelessWidget {
  const _TenureRatePicker({
    required this.draft,
    required this.selected,
    required this.onSelect,
  });

  final PlatformSettings draft;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => KCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Interest by tenure',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              draft.loanRateRange,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          'Every month from 1 to ${draft.maxLoanTenureMonths} is priced '
          'separately. Tap one to edit it.',
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.45,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final months in draft.loanTenures)
              GestureDetector(
                onTap: () => onSelect(months),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 64,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: months == selected
                        ? AppColors.goldWash
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: months == selected
                          ? AppColors.gold
                          : AppColors.stroke,
                      width: months == selected ? 1.4 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${months}m',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: months == selected
                              ? AppColors.gold
                              : AppColors.textTertiary,
                        ),
                      ),
                      Text(
                        draft.loanRateLabelFor(months),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: months == selected
                              ? AppColors.gold
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

/// Types a value in, for admins who would rather not nudge a slider two
/// hundred times to get from 17 to 85.
///
/// Every control on this screen routes here when its value is tapped, so
/// there is no setting that can only be reached by dragging.
Future<double?> editNumber(
  BuildContext context, {
  required String label,
  required double value,
  String unit = '',
  String? helper,
  double? min,
  double? max,
  bool integer = false,
}) async {
  final controller = TextEditingController(
    text: integer
        ? value.round().toString()
        : _trimZeros(value.toStringAsFixed(4)),
  );

  final result = await showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      String? error;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          void save() {
            final typed = double.tryParse(controller.text.trim());
            if (typed == null) {
              setSheetState(() => error = 'Type a number.');
              return;
            }
            if (min != null && typed < min) {
              setSheetState(() => error = 'Cannot go below ${_trimZeros(min.toString())}$unit.');
              return;
            }
            if (max != null && typed > max) {
              setSheetState(() => error = 'Cannot go above ${_trimZeros(max.toString())}$unit.');
              return;
            }
            Navigator.pop(sheetContext, integer ? typed.roundToDouble() : typed);
          }

          return Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              top: AppSpacing.lg,
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleLarge),
                if (helper != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    helper,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: !integer,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      integer ? RegExp(r'[0-9]') : RegExp(r'[0-9.]'),
                    ),
                  ],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                  onSubmitted: (_) => save(),
                  decoration: InputDecoration(
                    suffixText: unit.isEmpty ? null : unit,
                    errorText: error,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.lg,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.stroke),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.gold),
                    ),
                  ),
                ),
                if (min != null || max != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Allowed: '
                    '${min == null ? 'any' : _trimZeros(min.toString())}'
                    ' to '
                    '${max == null ? 'any' : _trimZeros(max.toString())}$unit',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                GoldButton(label: 'Save', onPressed: save),
              ],
            ),
          );
        },
      );
    },
  );

  controller.dispose();
  return result;
}

String _trimZeros(String v) => v.contains('.')
    ? v.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
    : v;

/// Makes a figure tappable, and says so — a dotted underline, so an admin
/// can see which numbers can be typed rather than having to guess.
class _TypeTarget extends StatelessWidget {
  const _TypeTarget({
    required this.child,
    required this.onTap,
    required this.enabled,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: enabled
              ? AppColors.gold.withValues(alpha: 0.35)
              : Colors.transparent,
        ),
      ),
      child: child,
    ),
  );
}

class _RateCard extends StatelessWidget {
  const _RateCard({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.enabled,
    this.helper,
    this.example,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final bool enabled;
  final String? helper;
  final String? example;

  @override
  Widget build(BuildContext context) => KCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Tap the figure to type it. Dragging from 17 to 85 is not a
            // reasonable thing to ask of anyone.
            _TypeTarget(
              enabled: enabled,
              onTap: () async {
                final typed = await editNumber(
                  context,
                  label: label,
                  value: value,
                  unit: '%',
                  helper: helper,
                  min: min,
                  max: max,
                );
                if (typed != null) onChanged(typed);
              },
              child: Text(
                valueLabel,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColors.gold,
                ),
              ),
            ),
          ],
        ),
        if (helper != null) ...[
          const SizedBox(height: 3),
          Text(
            helper!,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textTertiary,
            ),
          ),
        ],
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: enabled ? onChanged : null,
        ),
        if (example != null)
          Text(
            example!,
            style: const TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    ),
  );
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.enabled,
    this.step = 1000,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final bool enabled;
  final double step;

  @override
  Widget build(BuildContext context) => KCard(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              _TypeTarget(
                enabled: enabled,
                onTap: () async {
                  final typed = await editNumber(
                    context,
                    label: label,
                    value: value,
                    unit: ' naira',
                    integer: true,
                    min: 0,
                  );
                  if (typed != null) onChanged(typed);
                },
                child: Text(
                  value.asNairaFlat,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ),
        _StepButton(
          icon: Icons.remove_rounded,
          onTap: enabled && value - step >= 0
              ? () => onChanged(value - step)
              : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        _StepButton(
          icon: Icons.add_rounded,
          onTap: enabled ? () => onChanged(value + step) : null,
        ),
      ],
    ),
  );
}

class _StepperCard extends StatelessWidget {
  const _StepperCard({
    required this.label,
    required this.value,
    required this.enabled,
    this.onMinus,
    this.onPlus,
    this.typedValue,
    this.onTyped,
    this.unit = '',
    this.min,
    this.max,
  });

  final String label;

  /// The value as it is shown — '30 days', '5 tries'.
  final String value;

  /// The same value as a number, so it can be typed instead of stepped.
  final num? typedValue;
  final ValueChanged<num>? onTyped;
  final String unit;
  final num? min;
  final num? max;

  final bool enabled;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) => KCard(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              _TypeTarget(
                enabled: enabled && onTyped != null,
                onTap: () async {
                  final typed = await editNumber(
                    context,
                    label: label,
                    value: (typedValue ?? 0).toDouble(),
                    unit: unit,
                    integer: true,
                    min: min?.toDouble(),
                    max: max?.toDouble(),
                  );
                  if (typed != null) onTyped!(typed.round());
                },
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ),
        _StepButton(icon: Icons.remove_rounded, onTap: enabled ? onMinus : null),
        const SizedBox(width: AppSpacing.sm),
        _StepButton(icon: Icons.add_rounded, onTap: enabled ? onPlus : null),
      ],
    ),
  );
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap == null
        ? null
        : () {
            HapticFeedback.selectionClick();
            onTap!();
          },
    child: Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Icon(icon, size: 18, color: AppColors.gold),
      ),
    ),
  );
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.label,
    required this.helper,
    required this.value,
    required this.onChanged,
    required this.enabled,
    this.danger = false,
  });

  final String label;
  final String helper;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final bool danger;

  @override
  Widget build(BuildContext context) => KCard(
    padding: const EdgeInsets.all(AppSpacing.md),
    borderColor: danger && value
        ? AppColors.danger.withValues(alpha: 0.4)
        : null,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: danger && value
                      ? AppColors.danger
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                helper,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: enabled ? onChanged : null),
      ],
    ),
  );
}

/// Shows what the current fee settings mean at a few real loan sizes.
/// What the offer formula pays out for a few example customers, so an admin
/// can see the shape of a change before saving it.
class _OfferPreview extends StatelessWidget {
  const _OfferPreview({required this.draft});
  final PlatformSettings draft;

  double _offer(double saved, int score) {
    var cap = draft.loanBaseCap;
    cap += saved * draft.loanSavingsMultiple;
    cap += (score - draft.loanScoreBaseline) * draft.loanScorePerPoint;
    if (cap > draft.maxLoanAmount) cap = draft.maxLoanAmount;
    if (cap < 0) cap = 0;
    return (cap / draft.loanOfferRounding).floor() * draft.loanOfferRounding;
  }

  @override
  Widget build(BuildContext context) {
    const samples = <(String, double, int)>[
      ('New customer, nothing saved', 0, 560),
      ('Saved ₦200,000, fair score', 200000, 620),
      ('Saved ₦1,000,000, strong score', 1000000, 720),
    ];

    return KCard(
      gradient: AppColors.cardGradient,
      borderColor: AppColors.gold.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What these customers would be offered',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            'Capped at ${draft.maxLoanAmount.asNairaFlat}, and never below '
            '${draft.minLoanAmount.asNairaFlat}.',
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (label, saved, score) in samples)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    _offer(saved, score) < draft.minLoanAmount
                        ? 'not eligible'
                        : _offer(saved, score).asNairaFlat,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The score the same example customers would carry.
class _ScorePreview extends StatelessWidget {
  const _ScorePreview({required this.draft});
  final PlatformSettings draft;

  int _score({int plans = 0, double saved = 0, int repaid = 0,
      bool overdue = false, bool verified = false}) {
    var score = draft.creditBaseScore;
    score += (plans * draft.creditPointsPerPlan)
        .clamp(0, draft.creditPlanPointsCap);
    score += (saved / draft.creditNairaPerSavingsPoint)
        .floor()
        .clamp(0, draft.creditSavingsPointsCap);
    score += (repaid * draft.creditPointsPerRepaidLoan)
        .clamp(0, draft.creditRepaidPointsCap);
    if (overdue) score -= draft.creditOverduePenalty;
    if (verified) score += draft.creditVerifiedBonus;
    return score.clamp(draft.creditScoreFloor, draft.creditScoreCeiling);
  }

  @override
  Widget build(BuildContext context) {
    final samples = <(String, int)>[
      ('Brand new account', _score()),
      ('Verified, 2 plans, ₦200,000 saved', _score(
        plans: 2,
        saved: 200000,
        verified: true,
      )),
      ('The same, plus 3 loans repaid', _score(
        plans: 2,
        saved: 200000,
        repaid: 3,
        verified: true,
      )),
      ('The same, but one loan overdue', _score(
        plans: 2,
        saved: 200000,
        repaid: 3,
        overdue: true,
        verified: true,
      )),
    ];

    return KCard(
      gradient: AppColors.cardGradient,
      borderColor: AppColors.gold.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What these customers would score',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (label, score) in samples)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '$score',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FeePreview extends StatelessWidget {
  const _FeePreview({required this.draft});
  final PlatformSettings draft;

  // The same rule the customer is charged by, read off the draft rather
  // than the live settings so the preview shows unsaved edits.
  double _fee(double principal) => draft.processingFeeFor(principal);

  @override
  Widget build(BuildContext context) {
    final samples = <double>[
      draft.minLoanAmount,
      draft.processingFeeThreshold / 2,
      draft.processingFeeThreshold,
      // One naira over is already on the percentage — worth seeing.
      draft.processingFeeThreshold + 1,
      draft.processingFeeThreshold * 2,
    ];

    return KCard(
      gradient: AppColors.cardGradient,
      borderColor: AppColors.gold.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What customers will be charged',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            'Flat up to ${draft.processingFeeThreshold.asNairaFlat}; above '
            'that, ${draft.feeRatePct.toStringAsFixed(2)}% of the whole '
            'amount borrowed.',
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final s in samples)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Borrow ${s.asNairaFlat}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    'fee ${_fee(s).asNairaFlat}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'gets ${(s - _fee(s)).asNairaFlat}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
