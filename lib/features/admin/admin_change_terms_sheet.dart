import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/loan_application.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';
import 'admin_number_field.dart';

/// Opens [ChangeTermsSheet] and returns the application as it stands after
/// the terms were sent, or null if nothing was sent.
Future<LoanApplication?> showChangeTermsSheet(
  BuildContext context, {
  required LoanApplication application,
  required LendingTerms terms,
}) =>
    showModalBottomSheet<LoanApplication>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => ChangeTermsSheet(application: application, terms: terms),
    );

/// Change the rate, the management fee, the transaction fee or the months,
/// and send them to the customer to agree to or turn down — the web panel's
/// "Change the terms".
///
/// Starts from what the application is priced on now: an earlier offer, or
/// [terms] as the rate card has them. Until the rate is typed, it follows the
/// rate card for whatever length is chosen.
class ChangeTermsSheet extends StatefulWidget {
  const ChangeTermsSheet({
    super.key,
    required this.application,
    required this.terms,
  });

  final LoanApplication application;

  /// The terms the applicant borrows on: the loan group's, or the standard.
  final LendingTerms terms;

  @override
  State<ChangeTermsSheet> createState() => _ChangeTermsSheetState();
}

class _ChangeTermsSheetState extends State<ChangeTermsSheet> {
  late final LoanApplication _a = widget.application;
  late final LendingTerms _t = widget.terms;

  late final int _startMonths = _a.offer?.months ?? _a.tenureMonths;
  late final double _startRate = _a.offer?.flatRate ?? _t.rateFor(_a.tenureMonths);
  late final double _startFee =
      _a.offer?.managementFee ?? _t.processingFeeFor(_a.amount);
  late final double _startTxFee = _a.offer?.repaymentFeeRate ?? _t.repaymentFeeRate;

  late int _months = _startMonths;
  late double _rate = _startRate;
  late double _fee = _startFee;
  late double _txFee = _startTxFee;
  bool _rateTyped = false;
  late final _note = TextEditingController(text: _a.offer?.note ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _monthsOk => _months >= 1 && _months <= _t.maxTenureMonths;
  bool get _valid =>
      _monthsOk &&
      _rate >= 0 &&
      _rate <= 1 &&
      _fee >= 0 &&
      _fee < _a.amount &&
      _txFee >= 0 &&
      _txFee <= 0.2;

  /// The server refuses an offer that changes nothing: that is an approval.
  bool get _changed =>
      _months != _startMonths ||
      !_same(_rate, _startRate) ||
      !_same(_fee, _startFee) ||
      !_same(_txFee, _startTxFee);

  static bool _same(double a, double b) => (a - b).abs() < 1e-9;

  String? get _problem {
    if (!_monthsOk) return 'Loans run from 1 to ${_t.maxTenureMonths} months.';
    if (_rate > 1) return 'The interest rate has to be between 0% and 100%.';
    if (_fee >= _a.amount) {
      return 'The management fee has to be less than the amount lent.';
    }
    if (_txFee > 0.2) {
      return 'The transaction fee has to be between 0% and 20% of each repayment.';
    }
    if (!_changed) return 'Change at least one of the four to send an offer.';
    return null;
  }

  Future<void> _send() async {
    if (!_valid || !_changed) return;
    setState(() => _busy = true);
    final app = context.read<AppState>();
    final updated = await app.offerLoanApplicationTerms(
      _a.id,
      months: _months,
      flatRate: _rate,
      managementFee: _fee,
      repaymentFeeRate: _txFee,
      note: _note.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (updated == null) {
      showToast(context, app.lastError ?? 'Those terms could not be sent.',
          error: true);
      return;
    }
    Navigator.pop(context, updated);
    showToast(context, 'Sent to ${_a.customerName} to agree');
  }

  @override
  Widget build(BuildContext context) {
    final p = _valid
        ? Finance.loanPreview(
            _a.amount,
            _months,
            frequency: _a.repaymentFrequency,
            terms: _t,
            flatRate: _rate,
            managementFee: _fee,
            repaymentFeeRate: _txFee,
          )
        : null;
    final problem = _problem;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change the terms',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${_a.customerName} is sent these to agree to or turn down. '
                'Nothing is lent until they agree, and it comes back here '
                'for approval.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'Months',
                      hint: '1 to ${_t.maxTenureMonths}',
                      child: AdminNumberField(
                        value: _months.toDouble(),
                        onChanged: (n) => setState(() {
                          _months = n.round();
                          // Priced on the rate card for the new length until
                          // a rate of its own is typed.
                          if (!_rateTyped && _monthsOk) {
                            _rate = _t.rateFor(_months);
                          }
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _Field(
                      label: 'Interest rate',
                      hint: 'Flat, for the whole loan',
                      child: AdminNumberField(
                        value: _rate,
                        kind: AdminNumberKind.percent,
                        onChanged: (n) => setState(() {
                          _rate = n;
                          _rateTyped = true;
                        }),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'Management fee',
                      hint: 'Taken from the payout',
                      child: AdminNumberField(
                        value: _fee,
                        kind: AdminNumberKind.money,
                        onChanged: (n) => setState(() => _fee = n),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _Field(
                      label: 'Transaction fee',
                      hint: 'On each repayment',
                      child: AdminNumberField(
                        value: _txFee,
                        kind: AdminNumberKind.percent,
                        onChanged: (n) => setState(() => _txFee = n),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _note,
                maxLines: 2,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: 'Note to the customer (optional)',
                ),
              ),
              if (p != null) ...[
                const SizedBox(height: AppSpacing.sm),
                KCard(
                  child: Column(
                    children: [
                      _Line(
                        'Each ${_a.repaymentFrequency.unit}',
                        '${p.each.asNaira} (${p.base.asNaira} + '
                            '${p.instalmentFee.asNaira} fee)',
                      ),
                      _Line(
                        'Repaid',
                        _a.repaymentFrequency.paymentsPhrase(_months),
                      ),
                      _Line('Total to repay', p.total.asNaira),
                      _Line('Paid out', p.net.asNaira, bold: true),
                    ],
                  ),
                ),
              ],
              if (problem != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  problem,
                  style: TextStyle(
                    fontSize: 12,
                    color: _valid ? AppColors.textTertiary : AppColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              GoldButton(
                label: 'Send to customer',
                loading: _busy,
                onPressed: _busy || problem != null ? null : _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.hint, required this.child});

  final String label;
  final String hint;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          child,
          const SizedBox(height: 4),
          Text(
            hint,
            style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
          ),
        ],
      );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Full amounts with their parts run long on a phone: wrap.
            Expanded(
              flex: 3,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}
