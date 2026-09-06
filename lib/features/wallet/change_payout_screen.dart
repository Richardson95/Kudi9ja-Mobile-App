import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_config.dart';
import '../../core/constants/banks.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/pin_sheet.dart';
import '../../widgets/primitives.dart';
import '../../widgets/result_screen.dart';

/// Changing the bank account withdrawals are paid into.
///
/// Withdrawals only ever go to the account given at sign-up. That is what makes
/// the promise in the Terms true — payouts go to an account in the customer's
/// own name and nowhere else — so the destination cannot be retyped on the way
/// out of a withdrawal. Changing it is a deliberate act, and this is where it
/// happens.
///
/// Three gates, each proving something different:
///
///  * the **code** sent by email proves the person holds the address,
///  * the **transaction PIN** proves they are at the phone, and
///  * a **name enquiry** with the bank proves the new account is theirs.
///
/// This is the field an attacker with a live session actually wants, which is
/// why one live session is not enough on its own.
class ChangePayoutScreen extends StatefulWidget {
  const ChangePayoutScreen({super.key});

  @override
  State<ChangePayoutScreen> createState() => _ChangePayoutScreenState();
}

class _ChangePayoutScreenState extends State<ChangePayoutScreen> {
  final _account = TextEditingController();
  final _code = TextEditingController();
  String? _bank;
  bool _codeSent = false;
  bool _sending = false;
  bool _busy = false;

  bool get _detailsReady => _bank != null && _account.text.trim().length == 10;

  bool get _canSubmit =>
      _detailsReady && _codeSent && _code.text.trim().length == 6 && !_busy;

  @override
  void dispose() {
    _account.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Asks for the confirmation code.
  ///
  /// **Seam:** `POST /api/v1/me/payout/code`. The code is emailed and is never
  /// returned to the app.
  Future<void> _sendCode() async {
    final email = context.read<AppState>().user?.email ?? 'your email';
    setState(() => _sending = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() {
      _sending = false;
      _codeSent = true;
    });
    HapticFeedback.selectionClick();
    showToast(context, 'We have sent a code to $email');
  }

  /// **Seam:** `PATCH /api/v1/me/payout` with the bank, account, code and PIN.
  /// The server resolves the name with the bank and refuses a mismatch.
  Future<void> _submit() async {
    final app = context.read<AppState>();
    final bank = _bank!;
    final account = _account.text.trim();

    final pin = await confirmWithPin(
      context,
      title: 'Confirm new account',
      amountLabel: 'Future withdrawals will be paid here',
      details: [('Bank', bank), ('Account', account)],
    );
    if (pin == null || !mounted) return;

    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    await app.changePayoutAccount(bank: bank, accountNumber: account);
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          title: 'Payout account changed',
          message:
              'Withdrawals will now be paid into your $bank account. We have '
              'emailed you about the change. If it was not you, contact '
              '${AppConfig.supportEmail} straight away.',
          details: [('Bank', bank), ('Account', account)],
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
                  title: Text(kBanks[i], style: const TextStyle(fontSize: 14.5)),
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
    final user = context.select<AppState, AppUserView>(
      (s) => (
        bank: s.user?.payoutBank ?? '',
        account: s.user?.payoutAccountNumber ?? '',
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Change payout account')),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    _CurrentAccount(bank: user.bank, account: user.account),
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionLabel('NEW ACCOUNT'),
                    const SizedBox(height: AppSpacing.md),
                    KPickerField(
                      label: 'Bank',
                      icon: Icons.account_balance_outlined,
                      value: _bank,
                      hint: 'Choose your bank',
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
                      helper:
                          'It has to be in your own name. We check the name '
                          'with your bank and refuse the change if it does not '
                          'match.',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionLabel('CONFIRM IT IS YOU'),
                    const SizedBox(height: AppSpacing.md),
                    GhostButton(
                      label: _sending
                          ? 'Sending...'
                          : _codeSent
                          ? 'Send the code again'
                          : 'Email me a code',
                      onPressed: _detailsReady && !_sending ? _sendCode : null,
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: AppSpacing.lg),
                      KField(
                        label: 'Code from your email',
                        hint: '6 digits',
                        controller: _code,
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Withdrawals are always paid to the account on your '
                      'profile, never to one typed at the time. Changing it '
                      'here is the only way to move where your money goes.',
                      style: TextStyle(
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
                decoration: BoxDecoration(
                  color: AppColors.black,
                  border: Border(top: BorderSide(color: AppColors.stroke)),
                ),
                child: GoldButton(
                  label: 'Change payout account',
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

/// Just the two fields this screen watches, so a rebuild is not triggered by
/// every unrelated change to the account.
typedef AppUserView = ({String bank, String account});

class _CurrentAccount extends StatelessWidget {
  const _CurrentAccount({required this.bank, required this.account});

  final String bank;
  final String account;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.stroke),
    ),
    child: Row(
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
                'PAID INTO TODAY',
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
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 10.5,
      letterSpacing: 1.4,
      fontWeight: FontWeight.w800,
      color: AppColors.textTertiary,
    ),
  );
}
