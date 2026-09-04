import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../widgets/inputs.dart';
import '../../../../widgets/primitives.dart';
import '../signup_draft.dart';
import 'step_scaffold.dart';

/// BVN + NIN + address. This is the KYC gate that unlocks lending.
class IdentityStep extends StatefulWidget {
  const IdentityStep({super.key, required this.draft, required this.onNext});

  final SignupDraft draft;
  final VoidCallback onNext;

  @override
  State<IdentityStep> createState() => _IdentityStepState();
}

class _IdentityStepState extends State<IdentityStep> {
  final _form = GlobalKey<FormState>();
  late final _bvn = TextEditingController(text: widget.draft.bvn);
  late final _nin = TextEditingController(text: widget.draft.nin);
  late final _address = TextEditingController(text: widget.draft.address);
  String? _stateError;
  bool _checking = false;
  bool _verified = false;

  @override
  void dispose() {
    _bvn.dispose();
    _nin.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _runCheck() async {
    final stateMissing = widget.draft.stateOfResidence.isEmpty;
    setState(() => _stateError = stateMissing ? 'Select your state' : null);
    if (!_form.currentState!.validate() || stateMissing) return;

    FocusScope.of(context).unfocus();
    setState(() => _checking = true);
    // Stands in for the NIBSS identity lookup.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    // Commit what was checked before showing the confirmation. The verified
    // view reads these back, so writing them on Continue instead would leave
    // that screen displaying an empty BVN and NIN.
    widget.draft
      ..bvn = _bvn.text.trim()
      ..nin = _nin.text.trim()
      ..address = _address.text.trim();

    setState(() {
      _checking = false;
      _verified = true;
    });
    HapticFeedback.heavyImpact();
  }

  void _continue() {
    widget.draft.identityVerified = true;
    widget.onNext();
  }

  void _pickState() {
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
                'State of residence',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const HairLine(),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: kNigerianStates.length,
                itemBuilder: (_, i) {
                  final s = kNigerianStates[i];
                  final on = widget.draft.stateOfResidence == s;
                  return ListTile(
                    title: Text(
                      s,
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
                      setState(() {
                        widget.draft.stateOfResidence = s;
                        _stateError = null;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_verified) return _VerifiedView(draft: widget.draft, onNext: _continue);

    return Form(
      key: _form,
      child: StepScaffold(
        headline: 'Verify your\nidentity',
        subhead:
            'Your BVN and NIN confirm you are who you say you are. This is what unlocks lending and your full savings limits.',
        actionLabel: _checking ? 'Verifying...' : 'Verify identity',
        loading: _checking,
        onAction: _checking ? null : _runCheck,
        children: [
          KField(
            label: 'Bank Verification Number (BVN)',
            hint: '11 digits',
            controller: _bvn,
            prefixIcon: Icons.account_balance_outlined,
            keyboardType: TextInputType.number,
            maxLength: 11,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: Validators.bvn,
            helper: 'Dial *565*0# on your registered line to retrieve it',
          ),
          KField(
            label: 'National Identity Number (NIN)',
            hint: '11 digits',
            controller: _nin,
            prefixIcon: Icons.badge_outlined,
            keyboardType: TextInputType.number,
            maxLength: 11,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: Validators.nin,
          ),
          KField(
            label: 'Residential address',
            hint: '12 Adeola Odeku Street, Victoria Island',
            controller: _address,
            prefixIcon: Icons.home_outlined,
            textCapitalization: TextCapitalization.words,
            validator: (v) => Validators.required(v, 'Address'),
          ),
          KPickerField(
            label: 'State of residence',
            icon: Icons.location_on_outlined,
            value: widget.draft.stateOfResidence.isEmpty
                ? null
                : widget.draft.stateOfResidence,
            hint: 'Select your state',
            onTap: _pickState,
            error: _stateError,
          ),
          const InfoNote(
            icon: Icons.verified_user_outlined,
            text:
                'We only read your name, date of birth and phone from your BVN record. Kudi9ja can never move money in your bank accounts.',
          ),
        ],
      ),
    );
  }
}

class _VerifiedView extends StatelessWidget {
  const _VerifiedView({required this.draft, required this.onNext});

  final SignupDraft draft;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      headline: 'Identity confirmed',
      subhead:
          'Your records match. You are cleared for the full Kudi9ja product range.',
      actionLabel: 'Continue',
      onAction: onNext,
      children: [
        Center(
          child:
              Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.successGradient,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      size: 44,
                      color: Colors.white,
                    ),
                  )
                  .animate()
                  .scale(
                    duration: 500.ms,
                    curve: Curves.elasticOut,
                    begin: const Offset(0.3, 0.3),
                  )
                  .fadeIn(),
        ),
        const SizedBox(height: AppSpacing.md),
        KCard(
          gradient: AppColors.cardGradient,
          borderColor: AppColors.success.withValues(alpha: 0.25),
          child: Column(
            children: [
              _Row(label: 'Name', value: draft.fullName),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: HairLine(),
              ),
              _Row(label: 'BVN', value: _mask(draft.bvn)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: HairLine(),
              ),
              _Row(label: 'NIN', value: _mask(draft.nin)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: HairLine(),
              ),
              _Row(label: 'State', value: draft.stateOfResidence),
            ],
          ),
        ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.15),
        Row(
          children: [
            const StatusPill(
              label: 'TIER 2 VERIFIED',
              color: AppColors.success,
              icon: Icons.shield_rounded,
            ),
            const SizedBox(width: AppSpacing.sm),
            const StatusPill(
              label: 'LENDING UNLOCKED',
              color: AppColors.gold,
              icon: Icons.lock_open_rounded,
            ),
          ],
        ).animate(delay: 320.ms).fadeIn(),
      ],
    );
  }

  static String _mask(String v) {
    if (v.isEmpty) return '-';
    return v.length < 11 ? v : '${v.substring(0, 3)}*****${v.substring(8)}';
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
      ),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}
