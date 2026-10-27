import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/deposit.dart';
import '../../data/models/models.dart';
import '../../data/models/platform_settings.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import 'pay_in_screen.dart';
import 'paystack_checkout_screen.dart';

/// Money in: to the wallet, or onto a loan.
///
/// Through Paystack — card, bank transfer or USSD — whenever the server has it
/// switched on. Nothing is credited here: the customer pays on Paystack's own
/// page, and the server asks Paystack what happened before a naira moves.
/// While Paystack is off, this is the transfer-and-receipt flow it replaced.
class AddMoneyScreen extends StatefulWidget {
  const AddMoneyScreen({super.key, this.loan, this.presetAmount});

  /// When set, the payment goes onto this loan.
  final Loan? loan;
  final double? presetAmount;

  @override
  State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  late final _amount = TextEditingController(
    text: widget.presetAmount == null ? '' : widget.presetAmount!.ceil().asPlain,
  );
  late DepositPurpose _purpose =
      widget.loan != null ? DepositPurpose.loanRepayment : DepositPurpose.wallet;
  late String? _loanId = widget.loan?.id;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    // Asked fresh: an admin can switch it on or off at any time, and the
    // server refuses a receipt claim the moment it is on.
    if (app.paystackEnabled == null) unawaited(app.refreshExtras());
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double get _value => parseAmount(_amount.text);

  Loan? _loanIn(AppState app) {
    for (final l in app.activeLoans) {
      if (l.id == _loanId) return l;
    }
    return null;
  }

  String? _problem(AppState app) {
    final v = _value;
    if (v <= 0) return null;
    if (v < settings.minDepositAmount) {
      return 'The smallest payment is ${settings.minDepositAmount.asNairaFlat}.';
    }
    if (_purpose == DepositPurpose.loanRepayment) {
      final loan = _loanIn(app);
      if (loan == null) return 'Choose the loan you are repaying.';
      if (v > loan.outstanding + 0.5) {
        return 'That is more than the ${loan.outstanding.asNaira} still owed.';
      }
    }
    return null;
  }

  Future<void> _pay() async {
    FocusScope.of(context).unfocus();
    final app = context.read<AppState>();
    setState(() => _busy = true);
    try {
      final checkout = await app.startPaystack(
        amount: _value,
        purpose: _purpose,
        loanId: _loanId,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaystackCheckoutScreen(checkout: checkout),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final enabled = app.paystackEnabled;

    // Paystack is off: transfer to the company account and send the receipt.
    if (enabled == false || !app.isOnline) {
      return PayInScreen(loan: widget.loan, presetAmount: widget.presetAmount);
    }

    final loans = app.activeLoans;
    final loan = _loanIn(app);
    final problem = _problem(app);
    final repaying = _purpose == DepositPurpose.loanRepayment;

    return Scaffold(
      appBar: AppBar(title: Text(repaying ? 'Repay a loan' : 'Add money')),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: enabled == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
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
                          Text(
                            'Pay by card, bank transfer or USSD.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          if (loans.isNotEmpty) ...[
                            KOptionTile(
                              title: 'Fund my wallet',
                              subtitle: 'Save, join a circle, or keep it',
                              icon: Icons.account_balance_wallet_outlined,
                              selected: !repaying,
                              onTap: () => setState(() => _purpose = DepositPurpose.wallet),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            KOptionTile(
                              title: 'Repay a loan',
                              subtitle: 'Applied to the loan at once',
                              icon: Icons.bolt_rounded,
                              selected: repaying,
                              onTap: () => setState(() {
                                _purpose = DepositPurpose.loanRepayment;
                                _loanId ??= loans.length == 1 ? loans.first.id : null;
                              }),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                          ],
                          if (repaying) ...[
                            for (final l in loans) ...[
                              KOptionTile(
                                title: '${l.purpose} loan',
                                subtitle: '${l.outstanding.asNaira} still owed',
                                selected: l.id == _loanId,
                                onTap: () => setState(() => _loanId = l.id),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          Center(
                            child: Text(
                              'How much?',
                              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AmountField(
                            controller: _amount,
                            autofocus: widget.presetAmount == null,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (repaying && loan != null)
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                if (loan.nextInstallment != null)
                                  _Chip(
                                    label: 'Next instalment · '
                                        '${loan.nextInstallment!.outstanding.asNaira}',
                                    onTap: () => setState(() => _amount.text =
                                        loan.nextInstallment!.outstanding.ceil().asPlain),
                                  ),
                                _Chip(
                                  label: 'All of it · ${loan.outstanding.asNaira}',
                                  onTap: () => setState(
                                      () => _amount.text = loan.outstanding.ceil().asPlain),
                                ),
                              ],
                            )
                          else if (!repaying)
                            QuickAmounts(
                              amounts: const [5000, 10000, 20000, 50000, 100000],
                              onPick: (v) => setState(() => _amount.text = v.round().asPlain),
                            ),
                          if (problem != null) ...[
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              problem,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                          if (_value > 0 && problem == null) ...[
                            const SizedBox(height: AppSpacing.xl),
                            KCard(
                              child: Column(
                                children: [
                                  _Row('You pay', _value.asNaira),
                                  const SizedBox(height: AppSpacing.sm),
                                  _Row(
                                    repaying ? 'Applied to your loan' : 'Added to your wallet',
                                    _value.asNaira,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  const _Row('Fee', 'Free'),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          const _Points(),
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
                        label: 'Continue to Paystack',
                        icon: Icons.lock_rounded,
                        loading: _busy,
                        onPressed: _value > 0 && problem == null ? _pay : null,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    label: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
    onPressed: onTap,
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
    ],
  );
}

/// What a customer should know before they hand over a card.
class _Points extends StatelessWidget {
  const _Points();

  @override
  Widget build(BuildContext context) {
    const points = [
      (Icons.verified_user_outlined, 'Card details go to Paystack, never to Kudi9ja.'),
      (Icons.credit_card_rounded, 'Card, bank transfer, USSD or your bank app.'),
      (Icons.bolt_rounded, 'Credited the moment Paystack confirms it.'),
    ];
    return Column(
      children: [
        for (final (icon, text) in points)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.gold),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
