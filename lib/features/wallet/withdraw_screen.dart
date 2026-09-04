import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/banks.dart';
import '../../data/models/platform_settings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/withdrawal.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/pin_sheet.dart';
import '../../widgets/primitives.dart';
import '../../widgets/result_screen.dart';

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
    // Most withdrawals go to the account the customer named at sign-up, so
    // start there. They can still send this one somewhere else.
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

    final ok = await confirmWithPin(
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
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    final request = await app.requestWithdrawal(
      _value,
      _bank!,
      _account.text,
    );
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

  void _pickBank() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Select bank',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const HairLine(),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: kBanks.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(
                    kBanks[i],
                    style: const TextStyle(fontSize: 14.5),
                  ),
                  onTap: () {
                    setState(() => _bank = kBanks[i]);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
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
                    KPickerField(
                      label: 'Destination bank',
                      icon: Icons.account_balance_outlined,
                      value: _bank,
                      hint: 'Where should it go?',
                      onTap: _pickBank,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    KField(
                      label: 'Account number',
                      hint: '10 digits',
                      controller: _account,
                      prefixIcon: Icons.tag_rounded,
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
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
