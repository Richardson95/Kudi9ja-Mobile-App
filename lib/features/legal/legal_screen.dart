import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/legal/legal_documents.dart';
import '../../widgets/primitives.dart';
import 'legal_document_screen.dart';

/// The three documents that govern a Kudi9ja account, in one place.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  static const _icons = <String, IconData>{
    'terms': Icons.gavel_rounded,
    'privacy': Icons.privacy_tip_outlined,
    'lending': Icons.handshake_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final docs = allLegalDocuments();

    return Scaffold(
      appBar: AppBar(title: const Text('Legal')),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
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
                    Text(
                      'The agreements you have with us',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Written to be read. Every rate, fee and limit quoted in '
                      'these documents is the one the app is actually '
                      'applying today.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.55,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final doc in docs) ...[
                KCard(
                  onTap: () => Navigator.of(context).push(
                    slideRoute(LegalDocumentScreen(document: doc)),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBadge(
                        icon: _icons[doc.id] ?? Icons.description_outlined,
                        size: 42,
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              doc.summary,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'v${doc.version} • ${doc.effective.asDay} • '
                              '${doc.readMinutes} min read',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 10, left: AppSpacing.sm),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              const SizedBox(height: AppSpacing.sm),
              KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'THE COMPANY BEHIND KUDI9JA',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '${AppConfig.legalEntity}\n${AppConfig.rcNumber}\n'
                      '${AppConfig.registeredAddress}',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.65,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const HairLine(),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '${AppConfig.legalEmail}  ·  terms and agreements\n'
                      '${AppConfig.privacyEmail}  ·  privacy and your data\n'
                      '${AppConfig.supportEmail}  ·  general support',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.7,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens one document straight from a link elsewhere in the app.
void openLegalDocument(BuildContext context, String id) => Navigator.of(
  context,
).push(slideRoute(LegalDocumentScreen(document: legalDocumentById(id))));
