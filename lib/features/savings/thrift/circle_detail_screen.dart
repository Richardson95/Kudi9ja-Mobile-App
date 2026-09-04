import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/models/thrift.dart';
import '../../../state/app_state.dart';
import '../../../widgets/pin_sheet.dart';
import '../../../widgets/primitives.dart';

class CircleDetailScreen extends StatelessWidget {
  const CircleDetailScreen({super.key, required this.circleId});
  final String circleId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    ThriftCircle? found;
    for (final c in app.circles) {
      if (c.id == circleId) found = c;
    }
    if (found == null) return const Scaffold(body: SizedBox.shrink());

    final circle = found;
    final myTurn = circle.currentRound == circle.myRound;

    return Scaffold(
      appBar: AppBar(
        title: Text(circle.name),
        actions: [
          IconButton(
            onPressed: () => _confirmLeave(context, circle),
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              _Hero(circle: circle, myTurn: myTurn),
              const SizedBox(height: AppSpacing.xl),

              if (!circle.isComplete) ...[
                if (!circle.hasPaidThisRound)
                  GoldButton(
                    label: 'Pay ${circle.contribution.asNairaFlat} for round ${circle.currentRound}',
                    icon: Icons.payments_rounded,
                    onPressed: () => _contribute(context, circle),
                  )
                else if (myTurn)
                  GoldButton(
                    label: 'Collect ${circle.potSize.asNairaFlat}',
                    icon: Icons.celebration_rounded,
                    onPressed: () => _advance(context, circle),
                  )
                else
                  GhostButton(
                    label: 'Close round ${circle.currentRound}',
                    icon: Icons.skip_next_rounded,
                    onPressed: () => _advance(context, circle),
                  ),
                const SizedBox(height: AppSpacing.xl),
              ],

              const _SectionLabel('PAYOUT ROTATION'),
              const SizedBox(height: AppSpacing.md),
              KCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < circle.members.length; i++) ...[
                      if (i > 0) const HairLine(indent: 46),
                      _RotationRow(
                        member: circle.members[i],
                        round: i + 1,
                        circle: circle,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              const _SectionLabel('CIRCLE DETAILS'),
              const SizedBox(height: AppSpacing.md),
              KCard(
                child: Column(
                  children: [
                    _Line('Contribution', '${circle.contribution.asNaira} ${circle.frequency.adverb}'),
                    const _Sep(),
                    _Line('Pot each round', circle.potSize.asNaira),
                    const _Sep(),
                    _Line('Members', '${circle.size}'),
                    const _Sep(),
                    _Line('Started', circle.startDate.asDay),
                    const _Sep(),
                    _Line('Your turn', 'Round ${circle.myRound}'),
                    const _Sep(),
                    _Line('You collect on', circle.myPayoutDate.asDay),
                    const _Sep(),
                    _Line(
                      'Your total commitment',
                      circle.totalCommitment.asNaira,
                    ),
                  ],
                ),
              ),

              if (circle.inviteCode.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                _InviteCard(code: circle.inviteCode),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _contribute(BuildContext context, ThriftCircle c) async {
    final app = context.read<AppState>();
    if (c.contribution > app.balance) {
      showToast(context, 'Not enough in your wallet', error: true);
      return;
    }

    final ok = await confirmWithPin(
      context,
      title: 'Pay into ${c.name}',
      amountLabel: 'Round ${c.currentRound} contribution',
      amount: c.contribution,
      details: [
        ('Circle', c.name),
        ('Collector this round', c.currentCollector?.name ?? '-'),
        ('Pot', c.potSize.asNaira),
      ],
    );
    if (!ok || !context.mounted) return;

    await app.contributeToCircle(c.id);
    if (!context.mounted) return;
    showToast(context, 'Round ${c.currentRound} settled. Well done.');
  }

  Future<void> _advance(BuildContext context, ThriftCircle c) async {
    final app = context.read<AppState>();
    final payout = await app.advanceCircle(c.id);
    if (!context.mounted) return;

    showToast(
      context,
      payout > 0
          ? 'You collected ${payout.asNaira} from ${c.name}.'
          : 'Round ${c.currentRound} closed. Next up: ${c.members.length > c.currentRound ? c.members[c.currentRound].name : 'the circle is complete'}.',
    );
  }

  void _confirmLeave(BuildContext context, ThriftCircle c) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.share_rounded, color: AppColors.gold),
              title: const Text('Share invite code'),
              onTap: () {
                Navigator.pop(sheetContext);
                Clipboard.setData(ClipboardData(text: c.inviteCode));
                showToast(context, 'Invite code copied');
              },
            ),
            ListTile(
              leading: Icon(
                Icons.exit_to_app_rounded,
                color: AppColors.danger,
              ),
              title: Text(
                'Leave circle',
                style: TextStyle(color: AppColors.danger),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                context.read<AppState>().leaveCircle(c.id);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.circle, required this.myTurn});
  final ThriftCircle circle;
  final bool myTurn;

  @override
  Widget build(BuildContext context) {
    final accent = myTurn ? AppColors.success : AppColors.gold;

    return KCard(
      gradient: AppColors.cardGradient,
      borderColor: accent.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Text(circle.emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: AppSpacing.md),
          Text(
            myTurn ? 'It is your turn to collect' : 'Round ${circle.currentRound} of ${circle.size}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            circle.potSize.asNaira,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.4,
            ),
          ),
          Text(
            'pot this round',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: LinearProgressIndicator(
              value: circle.progress,
              minHeight: 7,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${circle.paidThisRound} of ${circle.size} paid this round',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textTertiary,
                ),
              ),
              Text(
                circle.isComplete
                    ? 'Complete'
                    : 'Next: ${circle.nextCollectionDate.asDay}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RotationRow extends StatelessWidget {
  const _RotationRow({
    required this.member,
    required this.round,
    required this.circle,
  });

  final ThriftMember member;
  final int round;
  final ThriftCircle circle;

  @override
  Widget build(BuildContext context) {
    final done = round < circle.currentRound;
    final current = round == circle.currentRound;
    final accent = done
        ? AppColors.success
        : (current ? AppColors.gold : AppColors.textTertiary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: current ? AppColors.goldGradient : null,
              color: current ? null : AppColors.surfaceHigh,
              border: done
                  ? Border.all(color: AppColors.success.withValues(alpha: 0.5))
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              member.initials,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: current
                    ? AppColors.textOnGold
                    : (done ? AppColors.success : AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.isMe ? '${member.name} (you)' : member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: member.isMe ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Round $round • ${circle.dateForRound(round).asDay}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          StatusPill(
            label: done ? 'COLLECTED' : (current ? 'COLLECTING' : 'WAITING'),
            color: accent,
            dense: true,
          ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) => KCard(
    child: Row(
      children: [
        IconBadge(icon: Icons.qr_code_rounded, size: 42),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite code',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                code,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: code));
            HapticFeedback.selectionClick();
            showToast(context, 'Invite code copied');
          },
          child: Icon(
            Icons.copy_rounded,
            size: 18,
            color: AppColors.gold,
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
      fontWeight: FontWeight.w800,
      letterSpacing: 1.6,
      color: AppColors.textTertiary,
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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

class _Sep extends StatelessWidget {
  const _Sep();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: HairLine(),
  );
}
