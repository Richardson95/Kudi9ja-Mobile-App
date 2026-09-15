import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../app.dart';
import '../data/legal/legal_documents.dart';
import '../features/legal/legal_document_screen.dart';
import '../state/app_state.dart';
import 'primitives.dart';

/// Tells a customer that an agreement has changed since they accepted it,
/// says what changed, and records their acceptance.
///
/// Shown once per session when the server lists anything outstanding. It
/// asks rather than blocks: the account works whether or not they accept
/// now, and the sheet comes back next time. The wording they are asked to
/// accept is opened from the copy shipped in this build, which carries the
/// same version number the server is asking about — a stale build would be
/// refused by the server rather than recording agreement to words the
/// customer never saw.
Future<void> showAgreementUpdates(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => const _AgreementUpdateSheet(),
    );

class _AgreementUpdateSheet extends StatefulWidget {
  const _AgreementUpdateSheet();

  @override
  State<_AgreementUpdateSheet> createState() => _AgreementUpdateSheetState();
}

class _AgreementUpdateSheetState extends State<_AgreementUpdateSheet> {
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    final message = await context.read<AppState>().acceptOutstandingAgreements();
    if (!mounted) return;
    setState(() => _busy = false);
    if (message == null) {
      Navigator.pop(context);
    } else {
      showToast(context, message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notices = context.watch<AppState>().outstandingAgreements;
    if (notices.isEmpty) {
      // Accepted from elsewhere while this was open.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }
    final several = notices.length > 1;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: IconBadge(
              icon: Icons.gavel_rounded,
              color: AppColors.gold,
              size: 48,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            several
                ? 'We have updated our agreements'
                : 'We have updated the ${notices.first.title}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Here is what changed. Read the new version if you like, then '
            'accept it to carry on.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          for (final notice in notices) ...[
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notice.title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        'v${notice.version}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  if (notice.changeSummary.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      notice.changeSummary,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(slideRoute(
                      LegalDocumentScreen(
                        document: legalDocumentById(notice.id),
                      ),
                    )),
                    child: Text(
                      'Read the new version',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.sm),
          GoldButton(
            label: several ? 'I accept the new versions' : 'I accept',
            loading: _busy,
            onPressed: _busy ? null : _accept,
          ),
          const SizedBox(height: AppSpacing.md),
          GhostButton(
            label: 'Not now',
            onPressed: _busy ? null : () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
