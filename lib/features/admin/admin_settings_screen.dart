import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/admin.dart';
import '../../data/models/models.dart';
import '../../data/models/platform_settings.dart';
import '../../data/api/api_exception.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import 'admin_group_terms_screen.dart';
import 'admin_number_field.dart';
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

  /// The settings the draft was taken from. While nothing has been edited,
  /// a fresher copy from the server replaces both — the screen must not
  /// open on figures the server has since moved past.
  late PlatformSettings _base = settings;
  bool _saving = false;

  late final _accountName = TextEditingController(
    text: settings.companyAccountName,
  );
  late final _accountNumber = TextEditingController(
    text: settings.companyAccountNumber,
  );
  late final _bank = TextEditingController(text: settings.companyBank);

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
      _draft.loanRepaymentFeeRate != settings.loanRepaymentFeeRate ||
      _draft.loanWeeklyAllowed != settings.loanWeeklyAllowed ||
      _draft.loanMonthlyAllowed != settings.loanMonthlyAllowed ||
      !_draft.groupLending.sameAs(settings.groupLending) ||
      _draft.maxPasscodeAttempts != settings.maxPasscodeAttempts ||
      _draft.lockTimeoutMinutes != settings.lockTimeoutMinutes ||
      _draft.minDepositAmount != settings.minDepositAmount ||
      _draft.minWithdrawalAmount != settings.minWithdrawalAmount ||
      _draft.minCircleContribution != settings.minCircleContribution ||
      _draft.minCircleMembers != settings.minCircleMembers ||
      _draft.maxCircleMembers != settings.maxCircleMembers ||
      _draft.otpResendSeconds != settings.otpResendSeconds;

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
      'Transaction fee on each repayment',
      '${(settings.loanRepaymentFeeRate * 100).toStringAsFixed(2)}%',
      '${(_draft.loanRepaymentFeeRate * 100).toStringAsFixed(2)}%',
    );
    cmp('Weekly repayment', settings.loanWeeklyAllowed, _draft.loanWeeklyAllowed);
    cmp('Monthly repayment', settings.loanMonthlyAllowed, _draft.loanMonthlyAllowed);
    out.addAll(groupTermsChanges(settings.groupLending, _draft.groupLending));
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
    if (!_draft.loanWeeklyAllowed && !_draft.loanMonthlyAllowed) {
      return 'Offer weekly repayment, monthly repayment, or both.';
    }
    if (_draft.lockTimeoutMinutes < AppConfig.minLockTimeoutMinutes) {
      return 'The idle lock must be at least '
          '${AppConfig.minLockTimeoutMinutes} minutes.';
    }
    final group = _draft.groupLending;
    if (group.minAmount >= group.maxAmount) {
      return 'The smallest group loan must be smaller than the largest.';
    }
    if (!group.weeklyAllowed && !group.monthlyAllowed) {
      return 'Group loans need weekly repayment, monthly repayment, or both.';
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
              Text(
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
                    style: TextStyle(
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
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Apply',
              style: TextStyle(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await context.read<AppState>().updatePlatformSettings(_draft, summary);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      // SETTINGS_STALE means another admin changed the rate card while this one
      // was editing. Saying so is the whole point: the alternative is one
      // person's rate change silently undoing another's.
      showToast(context, e.message, error: true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _draft = settings;
      _base = settings;
    });
    HapticFeedback.heavyImpact();
    showToast(context, 'Settings applied across the app');
  }

  /// The draft with its longest loan term set to [months], and a rate for
  /// every month that brings in.
  PlatformSettings _withLoanTenure(int months) => _draft.copyWith(
    maxLoanTenureMonths: months,
    loanRates: ratesUpTo(_draft.loanRates, months),
  );

  Future<void> _editGroupTerms(bool canEdit) async {
    final next = await Navigator.of(context).push<LendingTerms>(
      MaterialPageRoute(
        builder: (_) => AdminGroupTermsScreen(
          terms: _draft.groupLending,
          standard: _draft.lending,
          canEdit: canEdit,
        ),
      ),
    );
    if (next != null && mounted) {
      setState(() => _draft = _draft.copyWith(groupLending: next));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final canEdit = app.adminRole.canEditSettings;
    // Nothing edited yet, and the server has sent fresher settings: start
    // from those.
    if (identical(_draft, _base) && !identical(_base, settings)) {
      _base = settings;
      _draft = settings;
      _accountName.text = settings.companyAccountName;
      _accountNumber.text = settings.companyAccountNumber;
      _bank.text = settings.companyBank;
    }

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
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Flat rate by term',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        _draft.loanRateRange,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'One flat charge on the amount borrowed. Every month from 1 '
                    'to ${_draft.maxLoanTenureMonths} is priced on its own.',
                    style: TextStyle(fontSize: 11.5, height: 1.45, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  RateByTermGrid(
                    rates: _draft.loanRates,
                    maxTenureMonths: _draft.maxLoanTenureMonths,
                    enabled: canEdit,
                    onChanged: (m, r) => setState(() => _draft = _draft.withLoanRate(m, r)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '₦200,000 over 3 months repays '
                    '${(200000 * (1 + _draft.loanRateFor(3))).asNairaFlat}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
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
                () => _draft = _withLoanTenure(_draft.maxLoanTenureMonths + 1),
              ),
              typedValue: _draft.maxLoanTenureMonths,
              unit: ' months',
              min: 1,
              onTyped: (v) =>
                  setState(() => _draft = _withLoanTenure(v.toInt())),
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
              value: _draft.feeRatePct,
              min: 0,
              max: 5,
              divisions: 50,
              enabled: canEdit,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(loanProcessingFeeRate: v / 100),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            const AdminSectionLabel('REPAYMENTS'),
            _RateCard(
              label: 'Transaction fee on each repayment',
              helper:
                  'Covers what the payment provider charges to move the '
                  'money. Added to every instalment, weekly or monthly, and '
                  'rounded up to the naira. Frozen onto a loan when it is '
                  'paid out.',
              value: (_draft.loanRepaymentFeeRate * 100).clamp(0, 20),
              min: 0,
              max: 20,
              divisions: 80,
              enabled: canEdit,
              onChanged: (v) => setState(
                () => _draft = _draft.copyWith(loanRepaymentFeeRate: v / 100),
              ),
              example: () {
                final p = Finance.loanPreview(
                  125000,
                  3,
                  frequency: RepaymentFrequency.weekly,
                  terms: _draft.lending,
                );
                return '₦125,000 over 3 months, weekly: ${p.count} payments of '
                    '${p.base.asNairaFlat} + ${p.instalmentFee.asNairaFlat} fee';
              }(),
            ),
            const SizedBox(height: AppSpacing.md),
            _SwitchCard(
              label: 'Weekly repayment',
              helper: 'Borrowers may choose to repay once a week',
              value: _draft.loanWeeklyAllowed,
              enabled: canEdit,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(loanWeeklyAllowed: v)),
            ),
            const SizedBox(height: AppSpacing.md),
            _SwitchCard(
              label: 'Monthly repayment',
              helper: 'Borrowers may choose to repay once a month',
              value: _draft.loanMonthlyAllowed,
              enabled: canEdit,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(loanMonthlyAllowed: v)),
            ),
            const SizedBox(height: AppSpacing.md),
            KCard(
              child: Text(
                'Paying off early costs exactly what is still owed, and a loan '
                'in the wallet cannot be cancelled: both the rebate and the '
                'change-of-mind window are retired.',
                style: TextStyle(fontSize: 11.5, height: 1.5, color: AppColors.textTertiary),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            const AdminSectionLabel('LOAN GROUP TERMS'),
            KCard(
              onTap: () => _editGroupTerms(canEdit),
              borderColor: _draft.groupLending.sameAs(settings.groupLending)
                  ? null
                  : AppColors.gold.withValues(alpha: 0.5),
              child: Row(
                children: [
                  IconBadge(icon: Icons.groups_2_outlined, size: 42),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'What members of a loan group borrow on',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_draft.groupLending.rateRange} over up to '
                          '${_draft.groupLending.maxTenureMonths} months · '
                          '${_draft.groupLending.minAmount.asNairaFlat} to '
                          '${_draft.groupLending.maxAmount.asNairaFlat} · '
                          '${_draft.groupLending.repaymentFeeLabel} per repayment',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                ],
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
              // Ten minutes is the floor the server holds: a lock that fires
              // mid-application loses a customer their place.
              onMinus: _draft.lockTimeoutMinutes > AppConfig.minLockTimeoutMinutes
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
              min: AppConfig.minLockTimeoutMinutes.toDouble(),
              onTyped: (v) => setState(
                () => _draft = _draft.copyWith(lockTimeoutMinutes: v.toInt()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            KCard(
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
                  Text(
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
            Text(
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
              decoration: BoxDecoration(
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
    child: Row(
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

class _RateCard extends StatelessWidget {
  const _RateCard({
    required this.label,
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

  /// As a percentage: 17.5, not 0.175.
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
            const SizedBox(width: AppSpacing.md),
            // Typed, as on the web. The slider below is a shortcut, and
            // stops at its ends; the field does not.
            AdminNumberField(
              value: value / 100,
              kind: AdminNumberKind.percent,
              width: 104,
              enabled: enabled,
              onChanged: (fraction) => onChanged(fraction * 100),
            ),
          ],
        ),
        if (helper != null) ...[
          const SizedBox(height: 3),
          Text(
            helper!,
            style: TextStyle(
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
            style: TextStyle(
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
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AdminNumberField(
                value: value,
                kind: AdminNumberKind.money,
                enabled: enabled,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
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
      ],
    ),
  );
}

class _StepperCard extends StatelessWidget {
  const _StepperCard({
    required this.label,
    required this.value,
    required this.enabled,
    required this.typedValue,
    required this.onTyped,
    this.onMinus,
    this.onPlus,
    this.unit = '',
    this.min,
  });

  final String label;

  /// The value as it reads — '30 days (1 month)', '15 min idle'. Shown under
  /// the field when it says more than the number and its unit.
  final String value;

  final num typedValue;
  final ValueChanged<num> onTyped;
  final String unit;
  final num? min;

  final bool enabled;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final plain = '$typedValue$unit';
    return KCard(
      padding: const EdgeInsets.all(AppSpacing.md),
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
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AdminNumberField(
                  value: typedValue.toDouble(),
                  suffix: unit.trim(),
                  min: min?.toDouble(),
                  enabled: enabled,
                  onChanged: (v) => onTyped(v.round()),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StepButton(icon: Icons.remove_rounded, onTap: enabled ? onMinus : null),
              const SizedBox(width: AppSpacing.sm),
              _StepButton(icon: Icons.add_rounded, onTap: enabled ? onPlus : null),
            ],
          ),
          if (value != plain) ...[
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
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
                style: TextStyle(
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
            style: TextStyle(
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
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    'fee ${_fee(s).asNairaFlat}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'gets ${(s - _fee(s)).asNairaFlat}',
                    style: TextStyle(
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
