import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/banks.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/inputs.dart';
import '../../../../widgets/primitives.dart';
import '../signup_draft.dart';
import 'step_scaffold.dart';

/// Where money leaves Kudi9ja to.
///
/// Kudi9ja does not issue account numbers. Savings returns, loan
/// disbursements and anything else a customer withdraws go to a bank account
/// they already hold, in their own name — this step is where they name it.
class PayoutStep extends StatefulWidget {
  const PayoutStep({super.key, required this.draft, required this.onNext});

  final SignupDraft draft;
  final VoidCallback onNext;

  @override
  State<PayoutStep> createState() => _PayoutStepState();
}

class _PayoutStepState extends State<PayoutStep> {
  late final _account = TextEditingController(
    text: widget.draft.payoutAccountNumber,
  );

  @override
  void dispose() {
    _account.dispose();
    super.dispose();
  }

  bool get _ready =>
      widget.draft.payoutBank.isNotEmpty &&
      widget.draft.payoutAccountNumber.length == 10;

  void _pickBank() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, controller) => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Select your bank',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const HairLine(),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: kBanks.length,
                  itemBuilder: (_, i) {
                    final bank = kBanks[i];
                    final on = widget.draft.payoutBank == bank;
                    return ListTile(
                      title: Text(
                        bank,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                          color: on ? AppColors.gold : AppColors.textPrimary,
                        ),
                      ),
                      trailing: on
                          ? const Icon(
                              Icons.check_rounded,
                              color: AppColors.gold,
                              size: 20,
                            )
                          : null,
                      onTap: () {
                        setState(() => widget.draft.payoutBank = bank);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StepScaffold(
    headline: 'Where should we\npay you?',
    subhead:
        'Kudi9ja does not give you a new account number. Your savings '
        'returns, your loans and anything you withdraw go straight to a bank '
        'account you already have.',
    actionLabel: 'Continue',
    onAction: _ready ? widget.onNext : null,
    children: [
      KPickerField(
        label: 'Your bank',
        icon: Icons.account_balance_outlined,
        value: widget.draft.payoutBank.isEmpty ? null : widget.draft.payoutBank,
        hint: 'Choose your bank',
        onTap: _pickBank,
      ),
      const SizedBox(height: AppSpacing.lg),
      KField(
        label: 'Account number',
        hint: '10 digits',
        controller: _account,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        prefixIcon: Icons.pin_outlined,
        onChanged: (v) =>
            setState(() => widget.draft.payoutAccountNumber = v.trim()),
      ),
      const SizedBox(height: AppSpacing.lg),
      KCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.person_outline_rounded,
              size: 17,
              color: AppColors.gold,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'The account must be in your own name',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'We only pay out to '
                    '${widget.draft.fullName.trim().isEmpty ? 'the name on your Kudi9ja account' : widget.draft.fullName.trim()}. '
                    'A payout to somebody else is refused, and the money stays '
                    'in your wallet.',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      const Text(
        'You can change this later, and you can send a withdrawal to a '
        'different account of yours at the time you make it.',
        style: TextStyle(
          fontSize: 12,
          height: 1.5,
          color: AppColors.textTertiary,
        ),
      ),
    ],
  );
}
