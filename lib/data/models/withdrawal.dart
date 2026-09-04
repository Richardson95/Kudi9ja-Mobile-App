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

  bool get isPending => status == WithdrawalStatus.pending;

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
      );
}
