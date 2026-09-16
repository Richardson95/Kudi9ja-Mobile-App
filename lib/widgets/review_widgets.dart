import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../data/models/app_review.dart';
import '../state/app_state.dart';
import 'inputs.dart';
import 'primitives.dart';

/// Five stars, filled to [rating]. Tappable when [onChanged] is given.
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.rating,
    this.size = 16,
    this.onChanged,
  });

  final int rating;
  final double size;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            GestureDetector(
              onTap: onChanged == null ? null : () => onChanged!(i),
              child: Padding(
                padding: EdgeInsets.only(right: onChanged == null ? 1 : 6),
                child: Icon(
                  i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: size,
                  color: i <= rating ? AppColors.gold : AppColors.textTertiary,
                ),
              ),
            ),
        ],
      );
}

/// One review as the list shows it: who, how many stars, what they said.
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review, this.onLongPress});

  final AppReview review;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => KCard(
        borderColor:
            review.mine ? AppColors.gold.withValues(alpha: 0.35) : null,
        child: GestureDetector(
          onLongPress: onLongPress,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      review.mine ? '${review.displayName} (you)' : review.displayName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StarRow(rating: review.rating, size: 14),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                review.comment,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${review.writtenAt.asDay}${review.edited ? ' · edited' : ''}',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      );
}

/// The headline: "4.6" beside five stars, and how many said so.
class ReviewHeadline extends StatelessWidget {
  const ReviewHeadline({super.key, required this.summary});

  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final average = summary.average;
    if (average == null) {
      return Text(
        'No ratings yet. Be the first to say what you think.',
        style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
      );
    }
    return Row(
      children: [
        Text(
          average.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StarRow(rating: average.round(), size: 18),
            const SizedBox(height: 2),
            Text(
              '${summary.count} ${summary.count == 1 ? 'rating' : 'ratings'}',
              style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
            ),
          ],
        ),
      ],
    );
  }
}

/// Lets a customer rate the app and say why. Rewrites their existing review
/// if they have one; withdraws it on request.
Future<void> showRateAppSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => const _RateAppSheet(),
    );

class _RateAppSheet extends StatefulWidget {
  const _RateAppSheet();

  @override
  State<_RateAppSheet> createState() => _RateAppSheetState();
}

class _RateAppSheetState extends State<_RateAppSheet> {
  late final TextEditingController _comment;
  int _rating = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final mine = context.read<AppState>().myReview;
    _rating = mine?.rating ?? 0;
    _comment = TextEditingController(text: mine?.comment ?? '');
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final message = await context.read<AppState>().submitReview(
          rating: _rating,
          comment: _comment.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (message == null) {
      Navigator.pop(context);
      showToast(context, 'Thank you. Your review is up for everyone to see.');
    } else {
      showToast(context, message, error: true);
    }
  }

  Future<void> _withdraw() async {
    setState(() => _busy = true);
    final message = await context.read<AppState>().withdrawReview();
    if (!mounted) return;
    setState(() => _busy = false);
    if (message == null) {
      Navigator.pop(context);
      showToast(context, 'Your review has been removed.');
    } else {
      showToast(context, message, error: true);
    }
  }

  static const _labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  Widget build(BuildContext context) {
    final existing = context.watch<AppState>().myReview != null;
    final canSubmit = _rating > 0 && _comment.text.trim().length >= 3 && !_busy;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: IconBadge(
                icon: Icons.star_rounded,
                color: AppColors.gold,
                size: 48,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              existing ? 'Update your review' : 'Rate Kudi9ja',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Every customer can read what you write, under your first name.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: StarRow(
                rating: _rating,
                size: 38,
                onChanged: (v) => setState(() => _rating = v),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _rating == 0 ? 'Tap a star' : _labels[_rating],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _rating == 0 ? AppColors.textTertiary : AppColors.gold,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            KField(
              label: 'What do you think?',
              controller: _comment,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            GoldButton(
              label: existing ? 'Save my review' : 'Post my review',
              loading: _busy,
              onPressed: canSubmit ? _submit : null,
            ),
            if (existing) ...[
              const SizedBox(height: AppSpacing.md),
              GhostButton(
                label: 'Remove my review',
                danger: true,
                onPressed: _busy ? null : _withdraw,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
