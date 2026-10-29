/// Applying to borrow, and what became of it.
///
/// Borrowing used to be a button: the server priced the loan and the money
/// appeared. It is now an application carrying a bank statement, three
/// photographs of the business and a guarantor, and a person decides it.
/// Nothing reaches the wallet until they do.
library;

import 'platform_settings.dart';

/// Where an application stands.
///
/// [offered] and [termsDeclined] are last so that applications saved on the
/// device by index before they existed still read back as what they were.
enum LoanApplicationStatus {
  pending,
  approved,
  rejected,
  cancelled,

  /// The reviewing admin changed the terms and sent them back. Waiting for
  /// the customer to agree, which returns it to [pending], or to turn them
  /// down, which ends it.
  offered,

  /// The customer turned down the changed terms. Nothing was lent.
  termsDeclined,
}

extension LoanApplicationStatusX on LoanApplicationStatus {
  String get label => switch (this) {
        LoanApplicationStatus.pending => 'Under review',
        LoanApplicationStatus.approved => 'Approved',
        LoanApplicationStatus.rejected => 'Declined',
        LoanApplicationStatus.cancelled => 'Withdrawn',
        LoanApplicationStatus.offered => 'New terms to answer',
        LoanApplicationStatus.termsDeclined => 'Terms turned down',
      };

  /// As the server spells it: `TERMS_DECLINED`, not `TERMSDECLINED`.
  String get wire => switch (this) {
        LoanApplicationStatus.termsDeclined => 'TERMS_DECLINED',
        _ => name.toUpperCase(),
      };

  /// Still waiting on someone: the team, or the customer's answer.
  bool get isOpen =>
      this == LoanApplicationStatus.pending ||
      this == LoanApplicationStatus.offered;
}

/// A fraction as a percentage, to two places at most: "30%", "2.25%".
///
/// An admin can type any rate into an offer, and a customer agreeing to one
/// has to see exactly that rate, not one rounded to a whole point.
String fractionPct(double fraction) {
  final v = ((fraction * 10000).roundToDouble() / 100).toStringAsFixed(2);
  return '${v.replaceFirst(RegExp(r'\.?0+$'), '')}%';
}

/// Terms the reviewing admin changed, as a whole set — changed or not, so
/// the loan is priced from one place.
///
/// Kept on the application alone and frozen onto its loan at approval; the
/// standard pricing is untouched. Nothing is lent on them until the customer
/// agrees.
class TermsOffer {
  const TermsOffer({
    required this.months,
    required this.flatRate,
    required this.managementFee,
    required this.repaymentFeeRate,
    required this.offeredAt,
    this.note = '',
    this.offeredBy = '',
    this.agreedAt,
  });

  final int months;

  /// Flat interest for the whole loan, as a fraction: 0.3 for 30%.
  final double flatRate;

  /// In naira, taken from the payout.
  final double managementFee;

  /// On each repayment, as a fraction of the instalment: 0.02 for 2%.
  final double repaymentFeeRate;

  /// What the admin told the customer about the change.
  final String note;
  final DateTime offeredAt;

  /// Which admin sent it. Empty on the customer's view: they are told by the
  /// team, not by a person's email.
  final String offeredBy;

  /// When the customer agreed; null while they have not.
  final DateTime? agreedAt;

  bool get agreed => agreedAt != null;

  TermsOffer agree(DateTime at) => TermsOffer(
        months: months,
        flatRate: flatRate,
        managementFee: managementFee,
        repaymentFeeRate: repaymentFeeRate,
        offeredAt: offeredAt,
        note: note,
        offeredBy: offeredBy,
        agreedAt: at,
      );

  Map<String, dynamic> toJson() => {
        'months': months,
        'flatRate': flatRate,
        'managementFee': managementFee,
        'repaymentFeeRate': repaymentFeeRate,
        'note': note,
        'offeredAt': offeredAt.toIso8601String(),
        'offeredBy': offeredBy,
        'agreedAt': agreedAt?.toIso8601String(),
      };

  static TermsOffer? fromJson(Object? value) {
    if (value is! Map) return null;
    final j = value.cast<String, dynamic>();
    return TermsOffer(
      months: (j['months'] as num?)?.toInt() ?? 0,
      flatRate: (j['flatRate'] as num?)?.toDouble() ?? 0,
      managementFee: (j['managementFee'] as num?)?.toDouble() ?? 0,
      repaymentFeeRate: (j['repaymentFeeRate'] as num?)?.toDouble() ?? 0,
      note: j['note'] as String? ?? '',
      offeredAt:
          DateTime.tryParse(j['offeredAt'] as String? ?? '') ?? DateTime.now(),
      offeredBy: j['offeredBy'] as String? ?? '',
      agreedAt: DateTime.tryParse(j['agreedAt'] as String? ?? ''),
    );
  }
}

/// Somebody who vouches for the borrower.
///
/// One is needed. Their BVN is recorded, never verified — asking the issuer
/// about a person means having that person's consent, and the borrower's word
/// that a guarantor agreed is not the guarantor's.
class Guarantor {
  const Guarantor({
    required this.fullName,
    required this.phone,
    required this.address,
    required this.state,
    required this.localGovernment,
    required this.landmark,
    required this.relationship,
    required this.bvn,
    this.occupation = '',
    this.email = '',
  });

  final String fullName;
  final String phone;
  final String address;

  /// Where the address actually is, in the terms somebody would use to go
  /// there. Street numbering is irregular and streets share names across a
  /// city; the landmark is how anybody finds the place.
  final String state;
  final String localGovernment;
  final String landmark;

  /// What they are to the borrower: a sister, an employer, a landlord.
  final String relationship;
  final String bvn;
  final String occupation;
  final String email;

  bool get isComplete =>
      fullName.trim().isNotEmpty &&
      phone.trim().length == 11 &&
      address.trim().isNotEmpty &&
      state.trim().isNotEmpty &&
      localGovernment.trim().isNotEmpty &&
      landmark.trim().isNotEmpty &&
      relationship.trim().isNotEmpty &&
      bvn.trim().length == 11;

  Map<String, dynamic> toApi() => {
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'address': address.trim(),
        'state': state.trim(),
        'localGovernment': localGovernment.trim(),
        'landmark': landmark.trim(),
        'relationship': relationship.trim(),
        'bvn': bvn.trim(),
        'occupation': occupation.trim(),
        'email': email.trim(),
      };

  Map<String, dynamic> toJson() => toApi();

  static Guarantor fromJson(Map<String, dynamic> j) => Guarantor(
        fullName: j['fullName'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        address: j['address'] as String? ?? '',
        state: j['state'] as String? ?? '',
        localGovernment: j['localGovernment'] as String? ?? '',
        landmark: j['landmark'] as String? ?? '',
        relationship: j['relationship'] as String? ?? '',
        bvn: j['bvn'] as String? ?? '',
        occupation: j['occupation'] as String? ?? '',
        email: j['email'] as String? ?? '',
      );
}

/// One uploaded file, as the panel receives it.
///
/// The URL is signed and expires. It is only ever present on the admin's view
/// of an application — the customer uploaded these and has them already, and
/// minting a link to somebody's bank statement is a way of handing one out.
class ApplicationDocument {
  const ApplicationDocument({
    required this.label,
    required this.url,
    this.contentType = '',
    this.sizeBytes = 0,
  });

  final String label;
  final String url;
  final String contentType;
  final int sizeBytes;

  /// Whether the panel can draw this, as against having to open it.
  ///
  /// Asked this way round on purpose. A statement can be a PDF, a spreadsheet
  /// or a Word file, and listing the ones that are not pictures means the list
  /// goes stale the first time a bank sends something new — whereas the set of
  /// things that render as an image does not grow.
  bool get isImage => contentType.toLowerCase().startsWith('image/');
}

/// An application, from either side of it.
///
/// The admin's view carries the documents and the customer's name; the
/// customer's view carries the rejection reason. One class for both because
/// they are the same row, and the fields that are absent are absent rather
/// than different.
class LoanApplication {
  const LoanApplication({
    required this.id,
    required this.amount,
    required this.tenureMonths,
    required this.purpose,
    required this.status,
    required this.submittedAt,
    this.businessName = '',
    this.businessAddress = '',
    this.monthlyIncome = 0,
    this.guarantors = const [],
    this.documentsAttached = 0,
    this.reviewedAt,
    this.reviewedBy = '',
    this.rejectionReason = '',
    this.loanId = '',
    this.userId = '',
    this.customerName = '',
    this.customerRef = '',
    this.bankStatement,
    this.statementPassword = '',
    this.selfie,
    this.businessPhotos = const [],
    this.repaymentFrequency = RepaymentFrequency.monthly,
    this.groupPricing = false,
    this.offer,
    this.termsAgreed = false,
  });

  final String id;
  final double amount;
  final int tenureMonths;

  /// Weekly or monthly — the borrower's choice, carried onto the loan.
  final RepaymentFrequency repaymentFrequency;

  /// Admin's view only: whether the applicant borrows on the loan-group
  /// terms rather than the standard ones.
  final bool groupPricing;

  /// Terms the reviewing admin changed, if they did. Null on an application
  /// priced as asked.
  final TermsOffer? offer;

  /// The queue's view only, which carries no [offer]: whether the customer
  /// agreed to changed terms.
  final bool termsAgreed;
  final String purpose;
  final LoanApplicationStatus status;
  final DateTime submittedAt;

  final String businessName;
  final String businessAddress;
  final double monthlyIncome;
  final List<Guarantor> guarantors;
  final int documentsAttached;

  final DateTime? reviewedAt;
  final String reviewedBy;

  /// Why it was declined, in the admin's own words. Shown to the customer
  /// exactly as written — it is the thing they can act on.
  final String rejectionReason;

  /// The loan this became, once approved.
  final String loanId;

  // Present on the admin's view only.
  final String userId;
  final String customerName;
  final String customerRef;
  final ApplicationDocument? bankStatement;

  /// What opens the statement, if the bank locked it. Banks send PDF
  /// statements locked with the customer's date of birth or phone number,
  /// and the file is kept as sent. Empty when there is no lock, and always
  /// empty on the customer's own view — it is theirs, and they know it.
  final String statementPassword;

  /// The applicant's face, taken at application time.
  final ApplicationDocument? selfie;
  final List<ApplicationDocument> businessPhotos;

  bool get isPending => status == LoanApplicationStatus.pending;
  bool get wasDeclined => status == LoanApplicationStatus.rejected;

  /// Changed terms are with the customer, waiting for their answer.
  bool get isOffered => status == LoanApplicationStatus.offered;

  /// Back with the team on changed terms the customer agreed to. Approving it
  /// lends on those.
  bool get hasAgreedTerms => offer?.agreed ?? termsAgreed;

  /// The months it is priced on: the changed terms once sent, else as asked.
  int get pricedMonths => offer?.months ?? tenureMonths;

  /// Every document on it, the statement first. Empty on a customer's view.
  List<ApplicationDocument> get documents => [
        if (bankStatement != null) bankStatement!,
        if (selfie != null) selfie!,
        ...businessPhotos,
      ];

  LoanApplication copyWith({
    LoanApplicationStatus? status,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? rejectionReason,
    String? loanId,
    TermsOffer? offer,
  }) =>
      LoanApplication(
        id: id,
        amount: amount,
        tenureMonths: tenureMonths,
        purpose: purpose,
        status: status ?? this.status,
        submittedAt: submittedAt,
        businessName: businessName,
        businessAddress: businessAddress,
        monthlyIncome: monthlyIncome,
        guarantors: guarantors,
        documentsAttached: documentsAttached,
        reviewedAt: reviewedAt ?? this.reviewedAt,
        reviewedBy: reviewedBy ?? this.reviewedBy,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        loanId: loanId ?? this.loanId,
        userId: userId,
        customerName: customerName,
        customerRef: customerRef,
        bankStatement: bankStatement,
        statementPassword: statementPassword,
        selfie: selfie,
        businessPhotos: businessPhotos,
        repaymentFrequency: repaymentFrequency,
        groupPricing: groupPricing,
        offer: offer ?? this.offer,
        termsAgreed: offer?.agreed ?? termsAgreed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'tenureMonths': tenureMonths,
        'purpose': purpose,
        'status': status.index,
        'submittedAt': submittedAt.toIso8601String(),
        'businessName': businessName,
        'businessAddress': businessAddress,
        'monthlyIncome': monthlyIncome,
        'guarantors': guarantors.map((g) => g.toJson()).toList(),
        'documentsAttached': documentsAttached,
        'reviewedAt': reviewedAt?.toIso8601String(),
        'reviewedBy': reviewedBy,
        'rejectionReason': rejectionReason,
        'loanId': loanId,
        'customerName': customerName,
        'customerRef': customerRef,
        'repaymentFrequency': repaymentFrequency.wire,
        if (offer != null) 'offer': offer!.toJson(),
      };

  static LoanApplication fromJson(Map<String, dynamic> j) => LoanApplication(
        id: j['id'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        tenureMonths: (j['tenureMonths'] as num?)?.toInt() ?? 0,
        purpose: j['purpose'] as String? ?? '',
        status: LoanApplicationStatus
            .values[(j['status'] as num?)?.toInt() ?? 0],
        submittedAt:
            DateTime.tryParse(j['submittedAt'] as String? ?? '') ?? DateTime.now(),
        businessName: j['businessName'] as String? ?? '',
        businessAddress: j['businessAddress'] as String? ?? '',
        monthlyIncome: (j['monthlyIncome'] as num?)?.toDouble() ?? 0,
        guarantors: ((j['guarantors'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Guarantor.fromJson(e.cast<String, dynamic>()))
            .toList(),
        documentsAttached: (j['documentsAttached'] as num?)?.toInt() ?? 0,
        reviewedAt: DateTime.tryParse(j['reviewedAt'] as String? ?? ''),
        reviewedBy: j['reviewedBy'] as String? ?? '',
        rejectionReason: j['rejectionReason'] as String? ?? '',
        loanId: j['loanId'] as String? ?? '',
        customerName: j['customerName'] as String? ?? '',
        customerRef: j['customerRef'] as String? ?? '',
        repaymentFrequency: RepaymentFrequency.fromWire(j['repaymentFrequency']),
        offer: TermsOffer.fromJson(j['offer']),
      );
}
