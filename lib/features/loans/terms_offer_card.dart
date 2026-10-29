import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/loan_application.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/pin_sheet.dart';
import '../../widgets/primitives.dart';

/// Terms the team changed on an application, side by side with what was
/// asked for.
///
/// Agreeing sends it back to them to approve; turning them down ends it.
/// Nothing is lent either way until a person approves it, and the card says
/// so, because "new terms" read quickly sounds like "approved".
class TermsOfferCard extends StatefulWidget {
  const TermsOfferCard({super.key, required this.application});

  final LoanApplication application;

  @override
  State<TermsOfferCard> createState() => _TermsOfferCardState();
}

class _TermsOfferCardState extends State<TermsOfferCard> {
  bool _busy = false;

  LoanApplication get _a => widget.application;

  Future<void> _agree(LoanPreview after) async {
    final pin = await confirmWithPin(
      context,
      title: 'Agree to the new terms',
      amountLabel: 'You would receive',
      amount: after.net,
      details: [
        ('Repay', '${after.each.asNaira} a ${_a.repaymentFrequency.unit}'),
        ('Total', after.total.asNaira),
      ],
    );
    if (pin == null || !mounted) return;

    setState(() => _busy = true);
    final app = context.read<AppState>();
    final ok = await app.agreeToLoanTerms(_a.id, pin: pin);
    if (!mounted) return;
    setState(() => _busy = false);
    showToast(
      context,
      ok
          ? 'Agreed — it is back with our team for approval'
          : app.lastError ?? 'That could not be sent. Try again.',
      error: !ok,
    );
  }

  Future<void> _turnDown() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reject the new terms?'),
        content: Text(
          'This closes the application and nothing is lent. You can apply '
          'again later.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Reject', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final app = context.read<AppState>();
    final ok = await app.turnDownLoanTerms(_a.id);
    if (!mounted) return;
    setState(() => _busy = false);
    showToast(
      context,
      ok
          ? 'Terms rejected. The application is closed'
          : app.lastError ?? 'That could not be sent. Try again.',
      error: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final offer = _a.offer;
    if (offer == null) return const SizedBox.shrink();

    final terms = context.read<AppState>().lendingTerms;
    final freq = _a.repaymentFrequency;
    final before = Finance.loanPreview(
      _a.amount,
      _a.tenureMonths,
      frequency: freq,
      terms: terms,
    );
    final after = Finance.loanPreview(
      _a.amount,
      offer.months,
      frequency: freq,
      terms: terms,
      flatRate: offer.flatRate,
      managementFee: offer.managementFee,
      repaymentFeeRate: offer.repaymentFeeRate,
    );
    final rows = <(String, String, String)>[
      ('Length', freq.paymentsPhrase(_a.tenureMonths),
          freq.paymentsPhrase(offer.months)),
      ('Interest (flat)', fractionPct(before.rate), fractionPct(after.rate)),
      ('Management fee', before.fee.asNaira, after.fee.asNaira),
      ('Transaction fee on each repayment', fractionPct(before.feeRate),
          fractionPct(after.feeRate)),
      ('Each ${freq.unit}', before.each.asNaira, after.each.asNaira),
      ('Total to repay', before.total.asNaira, after.total.asNaira),
      ('Paid into your wallet', before.net.asNaira, after.net.asNaira),
    ];

    return KCard(
      borderColor: AppColors.info.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: AppColors.info),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'New terms for your ${_a.amount.asNaira} application',
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Our team reviewed your application and can offer it on the '
            'terms below. Nothing is lent until you agree.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          if (offer.note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.infoWash,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                offer.note,
                style: const TextStyle(fontSize: 12.5, height: 1.45),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _header(),
          const HairLine(),
          for (final (label, was, now) in rows) _row(label, was, now),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: GhostButton(
                  label: 'Reject',
                  danger: true,
                  onPressed: _busy ? null : _turnDown,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: GoldButton(
                  label: 'Agree',
                  height: 54,
                  loading: _busy,
                  onPressed: _busy ? null : () => _agree(after),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final style = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: AppColors.textTertiary,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Expanded(flex: 5, child: SizedBox()),
          Expanded(flex: 4, child: Text('YOU ASKED FOR', style: style)),
          Expanded(flex: 4, child: Text('NEW TERMS', style: style)),
        ],
      ),
    );
  }

  Widget _row(String label, String was, String now) {
    final changed = was != now;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              was,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              now,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: changed ? AppColors.gold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
