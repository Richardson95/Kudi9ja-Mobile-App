import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../widgets/inputs.dart';
import '../signup_draft.dart';
import 'step_scaffold.dart';

class PersonalStep extends StatefulWidget {
  const PersonalStep({super.key, required this.draft, required this.onNext});

  final SignupDraft draft;
  final VoidCallback onNext;

  @override
  State<PersonalStep> createState() => _PersonalStepState();
}

class _PersonalStepState extends State<PersonalStep> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.draft.fullName);
  late final _email = TextEditingController(text: widget.draft.email);
  late final _phone = TextEditingController(text: widget.draft.phone);
  String? _dobError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.draft.dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Select your date of birth',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          datePickerTheme: DatePickerThemeData(
            backgroundColor: AppColors.surface,
            headerBackgroundColor: AppColors.surfaceAlt,
            todayForegroundColor: WidgetStatePropertyAll(AppColors.gold),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        widget.draft.dateOfBirth = picked;
        _dobError = null;
      });
    }
  }

  void _submit() {
    final dobError = Validators.dateOfBirth(widget.draft.dateOfBirth);
    setState(() => _dobError = dobError);
    if (!_form.currentState!.validate() || dobError != null) return;
    if (widget.draft.gender.isEmpty) {
      setState(() => widget.draft.gender = kGenders.last);
    }

    widget.draft
      ..fullName = _name.text
      ..email = _email.text
      ..phone = _phone.text;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final dob = widget.draft.dateOfBirth;

    return Form(
      key: _form,
      child: StepScaffold(
        headline: 'Let us start\nwith you',
        subhead:
            'Use your name exactly as it appears on your BVN. It has to match for your account to be approved.',
        actionLabel: 'Continue',
        onAction: _submit,
        children: [
          KField(
            label: 'Full name',
            hint: 'Adaeze Okonkwo',
            controller: _name,
            prefixIcon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            validator: Validators.fullName,
            autofillHints: const [AutofillHints.name],
          ),
          KField(
            label: 'Email address',
            hint: 'you@example.com',
            controller: _email,
            prefixIcon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
            helper: 'We will send a 6-digit code here',
            autofillHints: const [AutofillHints.email],
          ),
          KField(
            label: 'Phone number',
            hint: '08031234567',
            controller: _phone,
            prefixIcon: Icons.phone_iphone_rounded,
            keyboardType: TextInputType.phone,
            maxLength: 11,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: Validators.phone,
            helper: 'This becomes your Kudi9ja account number',
          ),
          KPickerField(
            label: 'Date of birth',
            icon: Icons.cake_outlined,
            value: dob?.asDay,
            hint: 'You must be 18 or older',
            onTap: _pickDob,
            error: _dobError,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gender',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  for (final g in kGenders)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: _GenderChip(
                          label: g,
                          selected: widget.draft.gender == g,
                          onTap: () => setState(() => widget.draft.gender = g),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          InfoNote(
            text:
                'Kudi9ja is a licensed lender. Your details are encrypted in transit and at rest, and are never sold or shared.',
          ),
        ],
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 46,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: selected ? AppColors.goldWash : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.stroke,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.gold : AppColors.textSecondary,
        ),
      ),
    ),
  );
}
