/// The shape of a legal document, so Terms, Privacy and the Lending
/// Agreement can all be written as plain data and rendered by one screen.
///
/// Blocks are deliberately few. Anything a policy needs to say fits into a
/// paragraph, a list, a set of defined terms, a highlighted note or a small
/// worked example — and keeping the set small keeps the rendering honest.
library;

/// A whole document: Terms of Service, Privacy Policy or Lending Agreement.
class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.summary,
    required this.version,
    required this.effective,
    required this.readMinutes,
    required this.sections,
  });

  /// Stable identifier, used for deep links and acceptance records.
  final String id;
  final String title;

  /// The name used in lists and links, where the full title is too long.
  final String shortTitle;

  /// One or two sentences a customer can read instead of the whole thing.
  final String summary;

  /// Bumped whenever the wording changes in a way customers must be told
  /// about. Acceptance is recorded against this value.
  final String version;
  final DateTime effective;
  final int readMinutes;
  final List<LegalSection> sections;
}

/// A numbered section. Sections are numbered by position at render time, so
/// inserting one never leaves a stale number behind in the text.
class LegalSection {
  const LegalSection(this.title, this.blocks);
  final String title;
  final List<LegalBlock> blocks;
}

sealed class LegalBlock {
  const LegalBlock();
}

/// A paragraph. Wrap a phrase in **asterisks** to emphasise it.
class LegalText extends LegalBlock {
  const LegalText(this.text);
  final String text;
}

/// A bulleted list. Items support the same **emphasis**.
class LegalList extends LegalBlock {
  const LegalList(this.items, {this.ordered = false});
  final List<String> items;
  final bool ordered;
}

/// Defined terms, or any label-and-meaning pairing.
class LegalDefs extends LegalBlock {
  const LegalDefs(this.entries);

  /// (term, meaning) pairs.
  final List<(String, String)> entries;
}

/// A short passage that must not be skimmed past — a warning, a right the
/// customer has, or a commitment we are making.
class LegalNote extends LegalBlock {
  const LegalNote(this.text, {this.tone = LegalTone.neutral, this.title});
  final String text;
  final String? title;
  final LegalTone tone;
}

enum LegalTone { neutral, caution, positive }

/// A worked example — used to show the true cost of a loan in figures
/// rather than leaving a customer to do the arithmetic.
class LegalExample extends LegalBlock {
  const LegalExample(this.title, this.rows);
  final String title;

  /// (label, value) pairs, rendered as a small card.
  final List<(String, String)> rows;
}
