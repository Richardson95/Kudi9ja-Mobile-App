import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/platform_settings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/withdrawal.dart';
import '../../data/api/api_exception.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/pin_sheet.dart';
import '../../widgets/primitives.dart';
import '../../widgets/result_screen.dart';
import 'change_payout_screen.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _amount = TextEditingController();
  final _account = TextEditingController();
  String? _bank;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The destination is not a choice made here. Money goes to the account the
    // customer named at sign-up, which was checked against their own name —
    // that is what stops a withdrawal being used to push money into somebody
    // else's account. Changing it is a deliberate act on its own screen,
    // behind an emailed code, the PIN and a fresh name check.
    final user = context.read<AppState>().user;
    if (user != null && user.hasPayoutAccount) {
      _bank = user.payoutBank;
      _account.text = user.payoutAccountNumber;
    }
  }

  double get _value => parseAmount(_amount.text);

  bool get _canSubmit =>
      _value >= settings.minWithdrawalAmount &&
      _bank != null &&
      _account.text.length == 10 &&
      !_busy;

  /// Opens the payout-account screen and picks up whatever it left behind.
  ///
  /// The app state is read before the navigation rather than after it: holding
  /// a BuildContext across an await is how a widget ends up reading a context
  /// that has since been disposed.
  Future<void> _openPayoutChange() async {
    final app = context.read<AppState>();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ChangePayoutScreen()),
    );
    if (!mounted) return;

    setState(() {
      _bank = app.user?.payoutBank;
      _account.text = app.user?.payoutAccountNumber ?? '';
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _account.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final app = context.read<AppState>();
    if (_value > app.balance) {
      showToast(context, 'Not enough in your wallet', error: true);
      return;
    }

    final pin = await confirmWithPin(
      context,
      title: 'Request withdrawal',
      amountLabel: 'Sending to your bank',
      amount: _value,
      details: [
        ('Bank', _bank ?? ''),
        ('Account', _account.text),
        ('Status', 'Goes for approval'),
      ],
    );
    if (pin == null || !mounted) return;

    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    final WithdrawalRequest request;
    try {
      request = await app.requestWithdrawal(
        _value,
        _bank!,
        _account.text,
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
          title: 'Withdrawal requested',
          message:
              '${_value.asNaira} has been set aside and sent to our team for approval. You will be notified the moment it is released to your $_bank account.',
          details: [
            ('Amount', _value.asNaira),
            ('Bank', _bank ?? ''),
            ('Account', _account.text),
            ('Status', request.status.label),
            ('New wallet balance', app.balance.asNaira),
            ('Reference', request.reference),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balance = context.select<AppState, double>((s) => s.balance);

    return Scaffold(
      appBar: AppBar(title: const Text('Withdraw')),
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
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          AmountField(
                            controller: _amount,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Available: ${balance.asNaira}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          QuickAmounts(
                            amounts: const [5000, 20000, 50000, 100000],
                            onPick: (a) => setState(
                              () => _amount.text = a.toInt().asPlain,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _PayoutDestination(
                      bank: _bank ?? '',
                      account: _account.text,
                      onChange: _openPayoutChange,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.infoWash,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: AppColors.info,
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Every withdrawal is reviewed by our team before it is released. The amount leaves your wallet as soon as you request it, and comes straight back in full if the request is declined. Minimum withdrawal is ₦500.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                  label: 'Request withdrawal',
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

/// Where this withdrawal is going, shown rather than chosen.
///
/// Read-only on purpose. The account was verified as the customer's own when
/// they gave it at sign-up, and a withdrawal that could be redirected to a
/// freshly typed account would undo that check — which is exactly the shape
/// somebody moving money into a name that is not theirs would use.
class _PayoutDestination extends StatelessWidget {
  const _PayoutDestination({
    required this.bank,
    required this.account,
    required this.onChange,
  });

  final String bank;
  final String account;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.stroke),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconBadge(
              icon: Icons.account_balance_rounded,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PAYING INTO',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bank.isEmpty ? 'No account on file' : bank,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (account.isNotEmpty)
                    Text(
                      account,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'This is the account you registered, in your own name. We only pay '
          'into it.',
          style: TextStyle(
            fontSize: 11.5,
            height: 1.4,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        GestureDetector(
          onTap: onChange,
          child: Text(
            'Change payout account',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
        ),
      ],
    ),
  );
}
