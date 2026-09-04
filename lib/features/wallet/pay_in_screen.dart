import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/deposit.dart';
import '../../data/models/models.dart';
import '../../data/models/platform_settings.dart';
import '../../state/app_state.dart';
import '../../widgets/company_account.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import '../../widgets/result_screen.dart';

/// The single pay-in flow: transfer to the collection account, attach the
/// receipt, and submit it for confirmation.
///
/// Used both for topping up a wallet and for settling a loan by transfer —
/// [loan] decides which.
class PayInScreen extends StatefulWidget {
  const PayInScreen({super.key, this.loan, this.presetAmount});

  /// When set, the payment is applied to this loan once confirmed.
  final Loan? loan;
  final double? presetAmount;

  @override
  State<PayInScreen> createState() => _PayInScreenState();
}

class _PayInScreenState extends State<PayInScreen> {
  late final _amount = TextEditingController(
    text: widget.presetAmount == null
        ? ''
        : widget.presetAmount!.round().asPlain,
  );
  final _sender = TextEditingController();
  String _receipt = '';
  bool _busy = false;

  /// Minted once, when this screen opens, and quoted on the transfer. Every
  /// pay-in carries its own, so two payments of the same amount on the same
  /// day are still tellable apart on the bank statement.
  late final String _reference = context
      .read<AppState>()
      .newPaymentReference();

  bool get _isLoan => widget.loan != null;
  double get _value => parseAmount(_amount.text);

  bool get _canSubmit =>
      _value >= settings.minDepositAmount &&
      _receipt.isNotEmpty &&
      !_busy;

  @override
  void dispose() {
    _amount.dispose();
    _sender.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    final app = context.read<AppState>();
    final claim = await app.submitDepositClaim(
      amount: _value,
      purpose: _isLoan ? DepositPurpose.loanRepayment : DepositPurpose.wallet,
      reference: _reference,
      receiptPath: _receipt,
      senderName: _sender.text.trim(),
      loanId: widget.loan?.id,
      loanPurpose: widget.loan?.purpose ?? '',
    );
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          title: 'Sent for confirmation',
          message: _isLoan
              ? 'Your receipt is with our team. Once the payment is matched against the bank statement, ${_value.asNaira} will be applied to your ${widget.loan!.purpose} loan.'
              : 'Your receipt is with our team. Once the payment is matched against the bank statement, ${_value.asNaira} will land in your wallet.',
          details: [
            ('Amount', _value.asNaira),
            ('Paid into', settings.companyAccountNumber),
            ('Bank', settings.companyBank),
            ('Narration', claim.reference),
            if (_isLoan) ('For', '${widget.loan!.purpose} loan'),
            ('Status', claim.status.label),
          ],
          primaryLabel: 'Done',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoan ? 'Repay by transfer' : 'Pay in by transfer'),
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
                    const _Steps(),
                    const SizedBox(height: AppSpacing.xl),

                    CompanyAccountCard(
                      reference: _reference,
                      amount: _value > 0 ? _value.asNairaFlat : null,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    if (_isLoan) ...[
                      KCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PAYING TOWARDS',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                const IconBadge(
                                  icon: Icons.bolt_rounded,
                                  size: 40,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${widget.loan!.purpose} loan',
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '${widget.loan!.outstanding.asNaira} outstanding',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    KField(
                      label: 'How much did you transfer?',
                      hint: '0',
                      controller: _amount,
                      prefixIcon: Icons.payments_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      onChanged: (_) => setState(() {}),
                      helper: _isLoan
                          ? 'It will be applied to the loan once confirmed'
                          : 'It will be added to your wallet once confirmed',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    KField(
                      label: 'Account name you paid from (optional)',
                      hint: 'Helps us find your payment faster',
                      controller: _sender,
                      prefixIcon: Icons.person_outline_rounded,
                      textCapitalization: TextCapitalization.words,
                    ),

                    const SizedBox(height: AppSpacing.xl),
                    ReceiptPicker(
                      path: _receipt,
                      onPicked: (p) => setState(() => _receipt = p),
                    ),

                    const SizedBox(height: AppSpacing.xl),
                    const _Note(),
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
                  label: 'Submit for confirmation',
                  icon: Icons.send_rounded,
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

class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('1', 'Transfer the money to the account below'),
      ('2', 'Screenshot the receipt from your bank app'),
      ('3', 'Upload it here and submit'),
      ('4', 'We confirm it and your money is applied'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (n, text) in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.goldWash,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.35),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    n,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: AppColors.stroke),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 16,
          color: AppColors.textTertiary,
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            'Every payment is checked against the company bank statement before it is applied. You will be notified either way, usually within a few hours.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ],
    ),
  );
}
