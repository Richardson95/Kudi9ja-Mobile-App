import 'legal_models.dart';
import 'lending_agreement.dart';
import 'privacy_policy.dart';
import 'terms_of_service.dart';

export 'legal_models.dart';

/// Every legal document, in the order a customer meets them.
///
/// They are built on demand rather than held as constants, because the rates
/// and limits inside them are read from the live platform settings.
List<LegalDocument> allLegalDocuments() => [
  termsOfService(),
  privacyPolicy(),
  lendingAgreement(),
];

/// Looks a document up by [LegalDocument.id] — 'terms', 'privacy' or
/// 'lending'.
LegalDocument legalDocumentById(String id) =>
    allLegalDocuments().firstWhere((d) => d.id == id);
