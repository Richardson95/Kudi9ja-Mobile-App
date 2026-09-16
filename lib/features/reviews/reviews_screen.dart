import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/api_exception.dart';
import '../../data/api/kudi9ja_api.dart';
import '../../data/models/admin.dart';
import '../../data/models/app_review.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';
import '../../widgets/review_widgets.dart';

/// Every review, newest first, with the headline on top and the way to add
/// one at the bottom. Reads straight from the server a page at a time, so a
/// long list does not sit in memory on every phone that opens Home.
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final _items = <AppReview>[];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Kudi9jaApi? get _api => context.read<AppState>().api;

  Future<void> _loadMore() async {
    final api = _api;
    if (api == null || _loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final page = await api.reviews(page: _page, size: 20);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore;
        _page += 1;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
    });
    await context.read<AppState>().refreshReviews();
    await _loadMore();
  }

  Future<void> _rate() async {
    await showRateAppSheet(context);
    if (mounted) await _reload();
  }

  /// An admin removing a review, with a reason that is audited.
  Future<void> _remove(AppReview review) async {
    final app = context.read<AppState>();
    if (!app.isAdmin || !app.adminRole.canManageCustomers) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RemoveDialog(review: review),
    );
    if (reason == null || !mounted) return;
    final message = await app.removeReview(review.id, reason: reason);
    if (!mounted) return;
    if (message == null) {
      showToast(context, 'Review removed. The reason is on the audit log.');
      await _reload();
    } else {
      showToast(context, message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final summary = app.reviewSummary;
    final canModerate = app.isAdmin && app.adminRole.canManageCustomers;

    return Scaffold(
      appBar: AppBar(title: const Text('What customers say')),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: AppColors.gold,
            backgroundColor: AppColors.surface,
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.huge,
              ),
              children: [
                KCard(
                  gradient: AppColors.cardGradient,
                  borderColor: AppColors.gold.withValues(alpha: 0.22),
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ReviewHeadline(summary: summary),
                      if (summary.count > 0) ...[
                        const SizedBox(height: AppSpacing.lg),
                        for (var star = 5; star >= 1; star--)
                          _StarBar(
                            star: star,
                            count: summary.perStar[star],
                            total: summary.count,
                          ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      GoldButton(
                        label: app.myReview == null
                            ? 'Rate the app'
                            : 'Update my review',
                        icon: Icons.star_rounded,
                        height: 48,
                        onPressed: _rate,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_error != null && _items.isEmpty)
                  EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load reviews',
                    message: _error!,
                    action: SizedBox(
                      width: 160,
                      child: GhostButton(label: 'Try again', onPressed: _reload),
                    ),
                  )
                else if (_items.isEmpty && !_loading)
                  EmptyState(
                    icon: Icons.rate_review_outlined,
                    title: 'Nothing here yet',
                    message: 'Be the first to say what you think of Kudi9ja.',
                  )
                else ...[
                  for (final review in _items) ...[
                    ReviewTile(
                      review: review,
                      onLongPress: canModerate ? () => _remove(review) : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (_hasMore)
                    Center(
                      child: _loading
                          ? const Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : SizedBox(
                              width: 180,
                              child: GhostButton(
                                label: 'Show more',
                                onPressed: _loadMore,
                              ),
                            ),
                    ),
                ],
                if (canModerate) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'As an admin, press and hold a review to remove it. '
                    'You will be asked why, and the reason is audited.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StarBar extends StatelessWidget {
  const _StarBar({required this.star, required this.count, required this.total});

  final int star;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              child: Text(
                '$star',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ),
            Icon(Icons.star_rounded, size: 12, color: AppColors.gold),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : count / total,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceHigh,
                  valueColor: AlwaysStoppedAnimation(AppColors.gold),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 28,
              child: Text(
                '$count',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      );
}

class _RemoveDialog extends StatefulWidget {
  const _RemoveDialog({required this.review});

  final AppReview review;

  @override
  State<_RemoveDialog> createState() => _RemoveDialogState();
}

class _RemoveDialogState extends State<_RemoveDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enough = _reason.text.trim().length >= 5;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Remove this review?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${widget.review.comment}"',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'For abuse only — a phone number, an insult, somebody else\'s '
            'name. An unflattering review is not a reason, and the reason '
            'you give here goes on the audit log.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _reason,
            maxLines: 3,
            maxLength: 500,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Why it is being removed'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed:
              enough ? () => Navigator.pop(context, _reason.text.trim()) : null,
          child: Text(
            'Remove',
            style: TextStyle(
                color: enough ? AppColors.danger : AppColors.textTertiary),
          ),
        ),
      ],
    );
  }
}
