import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import '../../widgets/company_account.dart';
import '../../widgets/result_screen.dart';
import 'pay_in_screen.dart';

class FundWalletScreen extends StatefulWidget {
  const FundWalletScreen({super.key});

  @override
  State<FundWalletScreen> createState() => _FundWalletScreenState();
}

class _FundWalletScreenState extends State<FundWalletScreen> {
  final _amount = TextEditingController();
  String _method = 'Bank transfer';
  bool _busy = false;

  static const _methods = <(IconData, String, String)>[
    (
      Icons.account_balance_rounded,
      'Bank transfer',
      'Pay into our account and upload your receipt',
    ),
    (Icons.credit_card_rounded, 'Card', 'Instant • Visa, Mastercard, Verve'),
    (Icons.qr_code_rounded, 'USSD', 'Dial a code from your phone'),
  ];

  bool get _isTransfer => _method == 'Bank transfer';

  double get _value => parseAmount(_amount.text);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final tx = await context.read<AppState>().fundWallet(_value, _method);
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          title: 'Wallet funded',
          message: '${_value.asNaira} is now available to spend, save or send.',
          details: [
            ('Amount', _value.asNaira),
            ('Method', _method),
            ('New balance', tx.balanceAfter.asNaira),
            ('Reference', tx.reference),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add money')),
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
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'How much are you adding?',
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
                          const SizedBox(height: AppSpacing.lg),
                          QuickAmounts(
                            amounts: const [5000, 20000, 50000, 100000, 500000],
                            onPick: (a) => setState(
                              () => _amount.text = a.toInt().asPlain,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    const Text(
                      'PAYMENT METHOD',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final (icon, name, note) in _methods)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: KOptionTile(
                          title: name,
                          subtitle: note,
                          icon: icon,
                          selected: _method == name,
                          onTap: () => setState(() => _method = name),
                        ),
                      ),
                    if (_isTransfer) ...[
                      const SizedBox(height: AppSpacing.sm),
                      CompanyAccountCard(
                        reference: context.watch<AppState>().paymentReference,
                        amount: _value > 0 ? _value.asNairaFlat : null,
                      ),
                    ],
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
                  label: _isTransfer
                      ? 'I have made the transfer'
                      : (_value == 0
                            ? 'Add money'
                            : 'Add ${_value.asNairaFlat}'),
                  icon: _isTransfer ? Icons.receipt_long_rounded : null,
                  loading: _busy,
                  onPressed: _isTransfer
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PayInScreen(
                              presetAmount: _value > 0 ? _value : null,
                            ),
                          ),
                        )
                      : (_value >= 100 ? _submit : null),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
