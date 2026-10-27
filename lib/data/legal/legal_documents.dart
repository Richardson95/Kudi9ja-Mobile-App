import 'legal_models.dart';
import 'lending_agreement.dart';
import 'privacy_policy.dart';
import 'terms_of_service.dart';

export 'legal_models.dart';

/// The versions in force, as the server last sent them, by id.
///
/// The server decides which wording binds and from when. The copies compiled
/// into the app are what a customer reads when the server has not answered —
/// offline, or on the very first open — and nothing else: a bundled copy
/// stays at the version it was built with, and the day a new one takes effect
/// it would be showing one wording and asking for acceptance of a version the
/// server refuses.
final Map<String, LegalDocument> _fromServer = {};

/// Replaces the bundled copy of each document the server sent.
void useServerLegalDocuments(Iterable<LegalDocument> documents) {
  for (final d in documents) {
    _fromServer[d.id] = d;
  }
}

/// Whether the server's copies have been read this session.
bool get hasServerLegalDocuments => _fromServer.length >= 3;

/// Every legal document, in the order a customer meets them.
///
/// The server's copy where there is one. The bundled ones are built on demand
/// rather than held as constants, because the rates and limits inside them
/// are read from the live platform settings.
List<LegalDocument> allLegalDocuments() => [
  _fromServer['terms'] ?? termsOfService(),
  _fromServer['privacy'] ?? privacyPolicy(),
  _fromServer['lending'] ?? lendingAgreement(),
];

/// Looks a document up by [LegalDocument.id] — 'terms', 'privacy' or
/// 'lending'.
LegalDocument legalDocumentById(String id) =>
    allLegalDocuments().firstWhere((d) => d.id == id);
