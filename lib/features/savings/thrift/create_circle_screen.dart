import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/models/thrift.dart';
import '../../../data/models/platform_settings.dart';
import '../../../data/api/api_exception.dart';
import '../../../state/app_state.dart';
import '../../../widgets/inputs.dart';
import '../../../widgets/pin_sheet.dart';
import '../../../widgets/primitives.dart';
import '../../../widgets/result_screen.dart';
import '../new_plan_sheet.dart';

class CreateCircleScreen extends StatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  State<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends State<CreateCircleScreen> {
  final _name = TextEditingController();
  final _contribution = TextEditingController();
  final _memberRef = TextEditingController();
  AutoFrequency _frequency = AutoFrequency.monthly;
  String _emoji = '🤝';
  bool _busy = false;

  late final List<ThriftMember> _members = [
    ThriftMember(
      customerRef: context.read<AppState>().user?.customerRef ?? '',
      name: context.read<AppState>().user?.fullName ?? 'You',
      initials: initialsOf(context.read<AppState>().user?.fullName ?? 'You'),
      isMe: true,
    ),
  ];

  double get _amount => parseAmount(_contribution.text);
  double get _pot => _amount * _members.length;

  bool get _canSubmit =>
      _name.text.trim().isNotEmpty &&
      _amount >= settings.minCircleContribution &&
      _members.length >= settings.minCircleMembers &&
      !_busy;

  @override
  void dispose() {
    _name.dispose();
    _contribution.dispose();
    _memberRef.dispose();
    super.dispose();
  }

  /// Adds a seat by customer reference.
  ///
  /// The reference is what identifies a member, not a name: the circle debits
  /// a real wallet every round, so a seat has to belong to an account that can
  /// actually be debited.
  ///
  /// **This is the seam.** Against the server the reference goes to
  /// `POST /api/v1/transfers/resolve`, which answers with the masked name, and
  /// `POST /api/v1/circles` refuses outright if any reference belongs to
  /// nobody. Device-local there is nobody else to look up, so the reference is
  /// checked for shape and shown as typed.
  void _addMember() {
    final ref = _memberRef.text.trim().toUpperCase();
    if (ref.isEmpty) return;

    if (!RegExp(r'^K9-[A-Z0-9]{6}$').hasMatch(ref)) {
      showToast(
        context,
        'A customer reference looks like K9-A1B2C3',
        error: true,
      );
      return;
    }
    if (_members.any((m) => m.customerRef.toUpperCase() == ref)) {
      showToast(context, 'They are already in this circle', error: true);
      return;
    }
    if (_members.length >= settings.maxCircleMembers) {
      showToast(
        context,
        'A circle tops out at ${settings.maxCircleMembers} members',
        error: true,
      );
      return;
    }

    setState(() {
      _members.add(
        ThriftMember(customerRef: ref, name: ref, initials: ref.substring(3, 5)),
      );
      _memberRef.clear();
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    // Starting a circle commits the customer to a contribution every round, and
    // the first one is taken now. That is a money movement, and it is gated the
    // same way every other one is.
    final pin = await confirmWithPin(
      context,
      title: 'Start ${_name.text.trim()}',
      amountLabel: 'Your contribution each round',
      amount: _amount,
      details: [
        ('Members', '${_members.length + 1}'),
        ('Frequency', _frequency.label),
        ('Pot each round', (_amount * (_members.length + 1)).asNaira),
      ],
    );
    if (pin == null || !mounted) return;

    setState(() => _busy = true);

    final ThriftCircle circle;
    try {
      circle = await context.read<AppState>().createCircle(
        name: _name.text.trim(),
        emoji: _emoji,
        contribution: _amount,
        frequency: _frequency,
        members: _members,
        pin: pin,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      // MEMBER_NOT_A_CUSTOMER names the reference that is not a real account,
      // which is exactly what the person needs to correct.
      showToast(context, e.message, error: true);
      return;
    }
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          title: '$_emoji  ${circle.name}',
          message:
              'Your circle is live. Share the invite code so everyone can track it with you.',
          details: [
            ('Members', '${circle.size}'),
            ('Contribution', '${_amount.asNaira} ${_frequency.adverb}'),
            ('Pot each round', circle.potSize.asNaira),
            ('Your turn', 'Round ${circle.myRound}'),
            ('You collect on', circle.myPayoutDate.asDay),
            ('Invite code', circle.inviteCode),
          ],
          primaryLabel: 'Done',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New circle')),
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
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  children: [
                    KField(
                      label: 'Circle name',
                      hint: 'Office ajo, family circle...',
                      controller: _name,
                      prefixIcon: Icons.groups_outlined,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 28,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    EmojiPicker(
                      selected: _emoji,
                      onPick: (e) => setState(() => _emoji = e),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    KField(
                      label: 'Contribution per member',
                      hint: '0',
                      controller: _contribution,
                      prefixIcon: Icons.payments_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      onChanged: (_) => setState(() {}),
                      helper:
                          'Minimum ${settings.minCircleContribution.asNairaFlat} per cycle',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _Label('HOW OFTEN'),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        for (final f in AutoFrequency.values)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.sm,
                              ),
                              child: GestureDetector(
                                onTap: () => setState(() => _frequency = f),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  height: 46,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _frequency == f
                                        ? AppColors.goldWash
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm,
                                    ),
                                    border: Border.all(
                                      color: _frequency == f
                                          ? AppColors.gold
                                          : AppColors.stroke,
                                      width: _frequency == f ? 1.4 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    f.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _frequency == f
                                          ? AppColors.gold
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _Label('MEMBERS'),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      // The helper under the field makes it taller than the
                      // button, so pin both to the top rather than letting
                      // the row centre them against each other.
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: KField(
                            label: 'Add by customer reference',
                            hint: 'K9-A1B2C3',
                            controller: _memberRef,
                            prefixIcon: Icons.person_add_alt_rounded,
                            textCapitalization: TextCapitalization.characters,
                            // Every round debits a real wallet, so a seat has
                            // to belong to a real account. The reference is on
                            // each member's own Kudi9ja profile.
                            helper:
                                'They must already have a Kudi9ja account. '
                                'Ask them for the reference on their profile '
                                '— it looks like K9-A1B2C3.',
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Padding(
                          // Clears the field's label so the button lines up
                          // with the input box itself.
                          padding: const EdgeInsets.only(top: 24),
                          child: GestureDetector(
                            onTap: _addMember,
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: AppColors.goldGradient,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                color: AppColors.textOnGold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (var i = 0; i < _members.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _MemberRow(
                          member: _members[i],
                          round: i + 1,
                          onRemove: _members[i].isMe
                              ? null
                              : () => setState(() => _members.removeAt(i)),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    if (_amount > 0 && _members.length >= 2)
                      _Summary(
                        contribution: _amount,
                        pot: _pot,
                        members: _members.length,
                        frequency: _frequency,
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
                  label: 'Create circle',
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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.6,
      color: AppColors.textTertiary,
    ),
  );
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.round,
    this.onRemove,
  });

  final ThriftMember member;
  final int round;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(
        color: member.isMe
            ? AppColors.gold.withValues(alpha: 0.3)
            : AppColors.stroke,
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: member.isMe ? AppColors.goldGradient : null,
            color: member.isMe ? null : AppColors.surfaceHigh,
          ),
          alignment: Alignment.center,
          child: Text(
            member.initials,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: member.isMe
                  ? AppColors.textOnGold
                  : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            member.isMe ? '${member.name} (you)' : member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          'Round $round',
          style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
        ),
        if (onRemove != null)
          IconButton(
            onPressed: onRemove,
            icon: Icon(
              Icons.close_rounded,
              size: 17,
              color: AppColors.textTertiary,
            ),
          ),
      ],
    ),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.contribution,
    required this.pot,
    required this.members,
    required this.frequency,
  });

  final double contribution;
  final double pot;
  final int members;
  final AutoFrequency frequency;

  @override
  Widget build(BuildContext context) => KCard(
    gradient: AppColors.cardGradient,
    borderColor: AppColors.gold.withValues(alpha: 0.26),
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You collect',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          pot.asNaira,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const HairLine(),
        const SizedBox(height: AppSpacing.md),
        _Row('Members', '$members'),
        _Row('You pay in', '${contribution.asNaira} ${frequency.adverb}'),
        _Row('Rounds until complete', '$members'),
        _Row('Your total commitment', (contribution * members).asNaira),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
