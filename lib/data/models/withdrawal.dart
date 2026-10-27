/// Where a withdrawal sits in the approval queue.
enum WithdrawalStatus { pending, approved, declined }

extension WithdrawalStatusX on WithdrawalStatus {
  String get label => switch (this) {
    WithdrawalStatus.pending => 'Awaiting approval',
    WithdrawalStatus.approved => 'Approved',
    WithdrawalStatus.declined => 'Declined',
  };
}

/// A customer's request to move money out of Kudi9ja to their bank.
///
/// Money leaves the wallet the moment the request is made, so it cannot be
/// spent twice while an admin reviews it. Declining refunds it in full.
class WithdrawalRequest {
  WithdrawalRequest({
    required this.id,
    required this.customerName,
    required this.customerAccount,
    required this.amount,
    required this.bank,
    required this.destinationAccount,
    required this.requestedAt,
    required this.reference,
    this.status = WithdrawalStatus.pending,
    this.reviewedAt,
    this.reviewedBy = '',
    this.note = '',
    this.payoutStatus = '',
    this.payoutFailure = '',
    this.paidOutAt,
    this.payoutProvider = '',
    this.payoutReference = '',
  });

  final String id;
  final String customerName;
  final String customerAccount;
  final double amount;
  final String bank;
  final String destinationAccount;
  final DateTime requestedAt;
  final String reference;
  final WithdrawalStatus status;
  final DateTime? reviewedAt;
  final String reviewedBy;

  /// Reason given when declining, shown to the customer.
  final String note;

  /// Where the money is once approved: `PROCESSING` while Paystack is still
  /// sending it, `PAID` once it has landed, `FAILED` when the bank turned it
  /// back and the wallet was refunded. Empty until approved, and on a payout
  /// made by hand before Paystack.
  final String payoutStatus;

  /// Why a transfer failed or is waiting, in the words the bank used.
  final String payoutFailure;
  final DateTime? paidOutAt;

  /// `PAYSTACK` or `MANUAL` — how an approved payout was sent.
  final String payoutProvider;

  /// The bank's or Paystack's reference for the transfer.
  final String payoutReference;

  bool get isPending => status == WithdrawalStatus.pending;

  /// Approved and on its way, but not yet confirmed by the bank.
  bool get isSending =>
      status == WithdrawalStatus.approved && payoutStatus == 'PROCESSING';

  /// Approved, then turned back by the bank, and refunded to the wallet.
  bool get bounced =>
      status == WithdrawalStatus.approved && payoutStatus == 'FAILED';

  /// What to call this request's state, payout included.
  String get stateLabel => isSending
      ? 'Sending'
      : bounced
      ? 'Returned to wallet'
      : status == WithdrawalStatus.approved
      ? 'Paid'
      : status.label;

  /// How long the request has been sitting in the queue.
  Duration get age => DateTime.now().difference(requestedAt);

  WithdrawalRequest copyWith({
    WithdrawalStatus? status,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? note,
  }) => WithdrawalRequest(
    id: id,
    customerName: customerName,
    customerAccount: customerAccount,
    amount: amount,
    bank: bank,
    destinationAccount: destinationAccount,
    requestedAt: requestedAt,
    reference: reference,
    status: status ?? this.status,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    reviewedBy: reviewedBy ?? this.reviewedBy,
    note: note ?? this.note,
    payoutStatus: payoutStatus,
    payoutFailure: payoutFailure,
    paidOutAt: paidOutAt,
    payoutProvider: payoutProvider,
    payoutReference: payoutReference,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerName': customerName,
    'customerAccount': customerAccount,
    'amount': amount,
    'bank': bank,
    'destinationAccount': destinationAccount,
    'requestedAt': requestedAt.toIso8601String(),
    'reference': reference,
    'status': status.index,
    'reviewedAt': reviewedAt?.toIso8601String(),
    'reviewedBy': reviewedBy,
    'note': note,
    'payoutStatus': payoutStatus,
    'payoutFailure': payoutFailure,
    'paidOutAt': paidOutAt?.toIso8601String(),
    'payoutProvider': payoutProvider,
    'payoutReference': payoutReference,
  };

  factory WithdrawalRequest.fromJson(Map<String, dynamic> j) =>
      WithdrawalRequest(
        id: j['id'] as String,
        customerName: j['customerName'] as String,
        customerAccount: j['customerAccount'] as String? ?? '',
        amount: (j['amount'] as num).toDouble(),
        bank: j['bank'] as String,
        destinationAccount: j['destinationAccount'] as String,
        requestedAt: DateTime.parse(j['requestedAt'] as String),
        reference: j['reference'] as String? ?? '',
        status: WithdrawalStatus.values[j['status'] as int],
        reviewedAt: j['reviewedAt'] == null
            ? null
            : DateTime.parse(j['reviewedAt'] as String),
        reviewedBy: j['reviewedBy'] as String? ?? '',
        note: j['note'] as String? ?? '',
        payoutStatus: j['payoutStatus'] as String? ?? '',
        payoutFailure: j['payoutFailure'] as String? ?? '',
        paidOutAt: DateTime.tryParse(j['paidOutAt'] as String? ?? ''),
        payoutProvider: j['payoutProvider'] as String? ?? '',
        payoutReference: j['payoutReference'] as String? ?? '',
      );
}
