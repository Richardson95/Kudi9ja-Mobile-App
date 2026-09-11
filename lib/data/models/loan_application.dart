/// Applying to borrow, and what became of it.
///
/// Borrowing used to be a button: the server priced the loan and the money
/// appeared. It is now an application carrying a bank statement, three
/// photographs of the business and two guarantors, and a person decides it.
/// Nothing reaches the wallet until they do.
library;

enum LoanApplicationStatus { pending, approved, rejected, cancelled }

extension LoanApplicationStatusX on LoanApplicationStatus {
  String get label => switch (this) {
        LoanApplicationStatus.pending => 'Under review',
        LoanApplicationStatus.approved => 'Approved',
        LoanApplicationStatus.rejected => 'Declined',
        LoanApplicationStatus.cancelled => 'Withdrawn',
      };

  bool get isOpen => this == LoanApplicationStatus.pending;
}

/// Somebody who vouches for the borrower.
///
/// Two are needed. Their BVN is recorded, never verified — asking the issuer
/// about a person means having that person's consent, and the borrower's word
/// that a guarantor agreed is not the guarantor's.
class Guarantor {
  const Guarantor({
    required this.fullName,
    required this.phone,
    required this.address,
    required this.relationship,
    required this.bvn,
    this.occupation = '',
    this.email = '',
  });

  final String fullName;
  final String phone;
  final String address;

  /// What they are to the borrower: a sister, an employer, a landlord.
  final String relationship;
  final String bvn;
  final String occupation;
  final String email;

  bool get isComplete =>
      fullName.trim().isNotEmpty &&
      phone.trim().length == 11 &&
      address.trim().isNotEmpty &&
      relationship.trim().isNotEmpty &&
      bvn.trim().length == 11;

  Map<String, dynamic> toApi() => {
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'address': address.trim(),
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
    this.scoreAtSubmission,
    this.bankStatement,
    this.businessPhotos = const [],
  });

  final String id;
  final double amount;
  final int tenureMonths;
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
  final int? scoreAtSubmission;
  final ApplicationDocument? bankStatement;
  final List<ApplicationDocument> businessPhotos;

  bool get isPending => status == LoanApplicationStatus.pending;
  bool get wasDeclined => status == LoanApplicationStatus.rejected;

  /// Every document on it, the statement first. Empty on a customer's view.
  List<ApplicationDocument> get documents => [
        if (bankStatement != null) bankStatement!,
        ...businessPhotos,
      ];

  LoanApplication copyWith({
    LoanApplicationStatus? status,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? rejectionReason,
    String? loanId,
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
        scoreAtSubmission: scoreAtSubmission,
        bankStatement: bankStatement,
        businessPhotos: businessPhotos,
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
      );
}
