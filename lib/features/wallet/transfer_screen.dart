import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/pin_sheet.dart';
import '../../widgets/primitives.dart';
import '../../widgets/result_screen.dart';
import '../../data/models/platform_settings.dart';

const kBanks = <String>[
  'Access Bank',
  'Fidelity Bank',
  'First Bank of Nigeria',
  'GTBank',
  'Kuda Microfinance Bank',
  'Moniepoint MFB',
  'OPay',
  'PalmPay',
  'Stanbic IBTC',
  'Sterling Bank',
  'UBA',
  'Union Bank',
  'Wema Bank',
  'Zenith Bank',
];

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _amount = TextEditingController();
  final _account = TextEditingController();
  final _note = TextEditingController();
  String? _bank;
  String? _resolvedName;
  bool _resolving = false;
  bool _busy = false;

  double get _value => parseAmount(_amount.text);

  bool get _canSubmit =>
      _value > 0 &&
      _value <= settings.dailyTransferLimit &&
      _resolvedName != null &&
      !_busy;

  @override
  void dispose() {
    _amount.dispose();
    _account.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Mimics the name-enquiry call banks run before a transfer.
  Future<void> _resolve() async {
    if (_account.text.length != 10 || _bank == null) return;
    setState(() {
      _resolving = true;
      _resolvedName = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    const names = [
      'CHIOMA ADEYEMI',
      'IBRAHIM MUSA BELLO',
      'TUNDE OLAWALE JOHNSON',
      'NGOZI EMEKA OKAFOR',
      'FATIMA ABDULLAHI',
    ];
    setState(() {
      _resolving = false;
      _resolvedName = names[_account.text.hashCode.abs() % names.length];
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _submit() async {
    final app = context.read<AppState>();
    if (_value > app.balance) {
      showToast(context, 'Not enough in your wallet', error: true);
      return;
    }

    final ok = await confirmWithPin(
      context,
      title: 'Confirm transfer',
      amountLabel: 'Sending to $_resolvedName',
      amount: _value,
      details: [
        ('Bank', _bank ?? ''),
        ('Account', _account.text),
        ('Fee', 'Free'),
      ],
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final tx = await app.transfer(_value, _resolvedName!, _note.text.trim());
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          title: 'Transfer successful',
          message: '${_value.asNaira} is on its way to $_resolvedName.',
          details: [
            ('Recipient', _resolvedName!),
            ('Bank', _bank ?? ''),
            ('Account', _account.text),
            ('Amount', _value.asNaira),
            ('Reference', tx.reference),
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
                  leading: IconBadge(
                    icon: Icons.account_balance_rounded,
                    size: 38,
                    color: AppColors.textSecondary,
                  ),
                  title: Text(
                    kBanks[i],
                    style: const TextStyle(fontSize: 14.5),
                  ),
                  onTap: () {
                    setState(() {
                      _bank = kBanks[i];
                      _resolvedName = null;
                    });
                    Navigator.pop(context);
                    _resolve();
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
      appBar: AppBar(title: const Text('Send money')),
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
                          AmountField(
                            controller: _amount,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Available: ${balance.asNaira}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    KPickerField(
                      label: 'Bank',
                      icon: Icons.account_balance_outlined,
                      value: _bank,
                      hint: 'Choose the recipient bank',
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
                      onChanged: (v) {
                        setState(() => _resolvedName = null);
                        if (v.length == 10) _resolve();
                      },
                    ),
                    if (_resolving)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.md),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: AppSpacing.md),
                            Text(
                              'Checking account...',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_resolvedName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.successWash,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 17,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  _resolvedName!,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    KField(
                      label: 'Narration (optional)',
                      hint: 'What is this for?',
                      controller: _note,
                      prefixIcon: Icons.notes_rounded,
                      maxLength: 60,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Daily transfer limit: ${settings.dailyTransferLimit.asShortNaira}. Transfers to any Nigerian bank are free on Kudi9ja.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        color: AppColors.textTertiary,
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
                decoration: const BoxDecoration(
                  color: AppColors.black,
                  border: Border(top: BorderSide(color: AppColors.stroke)),
                ),
                child: GoldButton(
                  label: 'Send money',
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
