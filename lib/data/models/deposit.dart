/// What a customer says their bank transfer was for.
enum DepositPurpose { wallet, loanRepayment }

extension DepositPurposeX on DepositPurpose {
  String get label => switch (this) {
    DepositPurpose.wallet => 'Wallet funding',
    DepositPurpose.loanRepayment => 'Loan repayment',
  };
}

/// Where a claimed bank transfer sits in the confirmation queue.
enum DepositStatus { pending, confirmed, rejected }

extension DepositStatusX on DepositStatus {
  String get label => switch (this) {
    DepositStatus.pending => 'Awaiting confirmation',
    DepositStatus.confirmed => 'Confirmed',
    DepositStatus.rejected => 'Rejected',
  };
}

/// A customer telling us they have paid into the Kudi9ja collection account,
/// with a screenshot of the receipt as proof.
///
/// Nothing moves on their word alone: the wallet is credited, or the loan
/// reduced, only once an admin has matched the receipt against the company
/// statement and approved it.
class DepositClaim {
  DepositClaim({
    required this.id,
    required this.customerName,
    required this.customerAccount,
    required this.amount,
    required this.claimedAt,
    required this.reference,
    required this.purpose,
    this.loanId,
    this.loanPurpose = '',
    this.receiptPath = '',
    this.receiptUrl = '',
    this.senderName = '',
    this.status = DepositStatus.pending,
    this.reviewedAt,
    this.reviewedBy = '',
    this.note = '',
  });

  final String id;
  final String customerName;
  final String customerAccount;
  final double amount;
  final DateTime claimedAt;

  /// The narration the customer was told to quote on the transfer.
  final String reference;
  final DepositPurpose purpose;

  /// Set when the payment is settling a specific loan.
  final String? loanId;
  final String loanPurpose;

  /// Local path to the receipt screenshot the customer attached.
  ///
  /// Only ever set on the device that attached it. A claim read back from the
  /// server has none: the receipt is a private object there, not a file.
  final String receiptPath;

  /// A signed, expiring link to the receipt held by the server.
  ///
  /// This is what an admin actually opens. It carries its own signature and
  /// still requires a live panel session, so it is not a way around anything —
  /// it is the only route to a receipt that was uploaded rather than attached
  /// on this handset.
  final String receiptUrl;

  /// Whose bank account the money came from, if they said.
  final String senderName;

  final DepositStatus status;
  final DateTime? reviewedAt;
  final String reviewedBy;
  final String note;

  bool get isPending => status == DepositStatus.pending;
  /// Whether there is a receipt to look at, wherever it lives.
  ///
  /// This read only the local path once, which meant a claim from the server
  /// always answered no — and the panel told the admin no receipt had been
  /// attached to a claim that could not have been submitted without one.
  bool get hasReceipt => receiptPath.isNotEmpty || receiptUrl.isNotEmpty;
  bool get isLoanRepayment => purpose == DepositPurpose.loanRepayment;

  Duration get age => DateTime.now().difference(claimedAt);

  DepositClaim copyWith({
    DepositStatus? status,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? note,
  }) => DepositClaim(
    id: id,
    customerName: customerName,
    customerAccount: customerAccount,
    amount: amount,
    claimedAt: claimedAt,
    reference: reference,
    purpose: purpose,
    loanId: loanId,
    loanPurpose: loanPurpose,
    receiptPath: receiptPath,
    receiptUrl: receiptUrl,
    senderName: senderName,
    status: status ?? this.status,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    reviewedBy: reviewedBy ?? this.reviewedBy,
    note: note ?? this.note,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerName': customerName,
    'customerAccount': customerAccount,
    'amount': amount,
    'claimedAt': claimedAt.toIso8601String(),
    'reference': reference,
    'purpose': purpose.index,
    'loanId': loanId,
    'loanPurpose': loanPurpose,
    'receiptPath': receiptPath,
    'receiptUrl': receiptUrl,
    'senderName': senderName,
    'status': status.index,
    'reviewedAt': reviewedAt?.toIso8601String(),
    'reviewedBy': reviewedBy,
    'note': note,
  };

  factory DepositClaim.fromJson(Map<String, dynamic> j) => DepositClaim(
    id: j['id'] as String,
    customerName: j['customerName'] as String,
    customerAccount: j['customerAccount'] as String? ?? '',
    amount: (j['amount'] as num).toDouble(),
    claimedAt: DateTime.parse(j['claimedAt'] as String),
    reference: j['reference'] as String? ?? '',
    purpose: DepositPurpose.values[j['purpose'] as int? ?? 0],
    loanId: j['loanId'] as String?,
    loanPurpose: j['loanPurpose'] as String? ?? '',
    receiptPath: j['receiptPath'] as String? ?? '',
    receiptUrl: j['receiptUrl'] as String? ?? '',
    senderName: j['senderName'] as String? ?? '',
    status: DepositStatus.values[j['status'] as int],
    reviewedAt: j['reviewedAt'] == null
        ? null
        : DateTime.parse(j['reviewedAt'] as String),
    reviewedBy: j['reviewedBy'] as String? ?? '',
    note: j['note'] as String? ?? '',
  );
}
