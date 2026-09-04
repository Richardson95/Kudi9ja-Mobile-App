import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/legal/legal_documents.dart';
import '../../widgets/primitives.dart';

/// Renders one [LegalDocument] — the same screen serves the Terms, the
/// Privacy Policy and the Lending Agreement.
///
/// Legal text is only useful if it is actually read, so sections are
/// numbered, keyed and reachable from a contents list at the top, and the
/// document ends with the contacts a customer would need to act on it.
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  final _sectionKeys = <int, GlobalKey>{};
  bool _contentsOpen = false;

  GlobalKey _keyFor(int i) => _sectionKeys.putIfAbsent(i, GlobalKey.new);

  Future<void> _jumpTo(int index) async {
    setState(() => _contentsOpen = false);
    // Let the contents list collapse before measuring where to scroll to.
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final ctx = _keyFor(index).currentContext;
    if (ctx == null || !ctx.mounted) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;

    return Scaffold(
      appBar: AppBar(
        title: Text(doc.shortTitle),
        actions: [
          IconButton(
            tooltip: 'Contents',
            icon: Icon(
              _contentsOpen ? Icons.close_rounded : Icons.list_rounded,
              color: AppColors.gold,
            ),
            onPressed: () => setState(() => _contentsOpen = !_contentsOpen),
          ),
        ],
      ),
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
              _Masthead(doc: doc),
              const SizedBox(height: AppSpacing.lg),
              _Contents(
                doc: doc,
                open: _contentsOpen,
                onSelect: _jumpTo,
                onToggle: () => setState(() => _contentsOpen = !_contentsOpen),
              ),
              const SizedBox(height: AppSpacing.xl),
              for (var i = 0; i < doc.sections.length; i++)
                _SectionView(
                  key: _keyFor(i),
                  number: i + 1,
                  section: doc.sections[i],
                ),
              const SizedBox(height: AppSpacing.sm),
              const _ContactFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _Masthead extends StatelessWidget {
  const _Masthead({required this.doc});
  final LegalDocument doc;

  @override
  Widget build(BuildContext context) => KCard(
    gradient: AppColors.cardGradient,
    borderColor: AppColors.gold.withValues(alpha: 0.22),
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const BrandMark(size: 26),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                AppConfig.legalEntity.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(doc.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          doc.summary,
          style: TextStyle(
            fontSize: 13,
            height: 1.55,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            StatusPill(
              label: 'VERSION ${doc.version}',
              color: AppColors.gold,
              dense: true,
            ),
            StatusPill(
              label: 'FROM ${doc.effective.asDay.toUpperCase()}',
              color: AppColors.info,
              dense: true,
            ),
            StatusPill(
              label: '${doc.readMinutes} MIN READ',
              color: AppColors.textTertiary,
              dense: true,
            ),
          ],
        ),
      ],
    ),
  );
}

class _Contents extends StatelessWidget {
  const _Contents({
    required this.doc,
    required this.open,
    required this.onSelect,
    required this.onToggle,
  });

  final LegalDocument doc;
  final bool open;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => KCard(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    child: Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 18,
                  color: AppColors.gold,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Contents — ${doc.sections.length} sections',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          firstChild: const SizedBox(width: double.infinity),
          crossFadeState: open
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.sm),
              const HairLine(),
              for (var i = 0; i < doc.sections.length; i++)
                InkWell(
                  onTap: () => onSelect(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 26,
                          child: Text(
                            '${i + 1}.',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            doc.sections[i].title,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Sections and blocks ───────────────────────────────────────────────────

class _SectionView extends StatelessWidget {
  const _SectionView({
    super.key,
    required this.number,
    required this.section,
  });

  final int number;
  final LegalSection section;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.goldWash,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                '$number',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                section.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final block in section.blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _BlockView(block: block),
          ),
      ],
    ),
  );
}

class _BlockView extends StatelessWidget {
  const _BlockView({required this.block});
  final LegalBlock block;

  @override
  Widget build(BuildContext context) => switch (block) {
    LegalText(:final text) => _Body(text),
    LegalList(:final items, :final ordered) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: ordered
                      ? Text(
                          '${i + 1}.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold,
                          ),
                        )
                      : const Padding(
                          padding: EdgeInsets.only(top: 7, left: 3),
                          child: _Dot(),
                        ),
                ),
                Expanded(child: _Body(items[i])),
              ],
            ),
          ),
      ],
    ),
    LegalDefs(:final entries) => KCard(
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entries[i].$1,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 4),
                _Body(entries[i].$2),
              ],
            ),
            if (i != entries.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: HairLine(),
              ),
          ],
        ],
      ),
    ),
    LegalNote(:final text, :final title, :final tone) => _NoteCard(
      text: text,
      title: title,
      tone: tone,
    ),
    LegalExample(:final title, :final rows) => KCard(
      borderColor: AppColors.gold.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 4,
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  };
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
    width: 4,
    height: 4,
    decoration: BoxDecoration(
      color: AppColors.gold,
      shape: BoxShape.circle,
    ),
  );
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.text, required this.title, required this.tone});

  final String text;
  final String? title;
  final LegalTone tone;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (tone) {
      LegalTone.caution => (AppColors.danger, Icons.warning_amber_rounded),
      LegalTone.positive => (AppColors.success, Icons.verified_rounded),
      LegalTone.neutral => (AppColors.info, Icons.info_outline_rounded),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
                _Body(text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Body copy with **emphasis** rendered as bold, bright text.
class _Body extends StatelessWidget {
  const _Body(this.text);
  final String text;

  static final _emphasis = RegExp(r'\*\*(.+?)\*\*');

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: 13.5,
      height: 1.62,
      color: AppColors.textSecondary,
    );

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final m in _emphasis.allMatches(text)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(1),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return SelectableText.rich(TextSpan(style: base, children: spans));
  }
}

// ── Footer ────────────────────────────────────────────────────────────────

class _ContactFooter extends StatelessWidget {
  const _ContactFooter();

  @override
  Widget build(BuildContext context) => KCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUESTIONS ABOUT THIS DOCUMENT',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const _CopyRow(
          icon: Icons.gavel_rounded,
          label: 'Terms and agreements',
          value: AppConfig.legalEmail,
        ),
        const _CopyRow(
          icon: Icons.privacy_tip_outlined,
          label: 'Privacy and your data',
          value: AppConfig.privacyEmail,
        ),
        const _CopyRow(
          icon: Icons.headset_mic_outlined,
          label: 'General support',
          value: AppConfig.supportEmail,
        ),
        const _CopyRow(
          icon: Icons.call_outlined,
          label: 'Phone',
          value: AppConfig.supportPhone,
        ),
        for (final number in AppConfig.supportWhatsapp.keys)
          _CopyRow(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'WhatsApp',
            value: number,
          ),
        const SizedBox(height: AppSpacing.md),
        const HairLine(),
        const SizedBox(height: AppSpacing.md),
        Text(
          '${AppConfig.legalEntity} (${AppConfig.rcNumber})\n'
          '${AppConfig.registeredAddress}\n'
          'Kudi9ja is a product of ${AppConfig.legalEntity}.',
          style: TextStyle(
            fontSize: 11.5,
            height: 1.6,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    ),
  );
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () {
      Clipboard.setData(ClipboardData(text: value));
      HapticFeedback.selectionClick();
      showToast(context, '$value copied', icon: Icons.copy_rounded);
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.copy_rounded,
            size: 15,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    ),
  );
}
