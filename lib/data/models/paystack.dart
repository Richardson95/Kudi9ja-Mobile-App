/// Paying in through Paystack: by card, bank transfer or USSD, credited the
/// moment Paystack confirms it, with no receipt to upload and nobody to wait
/// for.
library;

import '_wire.dart';
import 'deposit.dart';

/// A checkout the server has opened. Moves no money: the customer pays on
/// Paystack's page, and the server asks Paystack what happened before a
/// naira is credited.
class PaystackCheckout {
  const PaystackCheckout({
    required this.reference,
    required this.authorizationUrl,
    required this.amount,
  });

  final String reference;

  /// Paystack's page, where the customer pays.
  final String authorizationUrl;
  final double amount;

  static PaystackCheckout fromApi(Map<String, dynamic> j) => PaystackCheckout(
    reference: str(j['reference']),
    authorizationUrl: str(j['authorizationUrl']),
    amount: money(j['amount']),
  );
}

enum PaystackStatus { initialized, successful, failed, abandoned }

/// One payment through Paystack, from either side.
///
/// The customer's view and the panel's are the same row; the panel's carries
/// who paid and what Paystack charged for it.
class PaystackPayment {
  const PaystackPayment({
    required this.id,
    required this.reference,
    required this.amount,
    required this.purpose,
    required this.purposeLabel,
    required this.status,
    required this.statusLabel,
    required this.credited,
    required this.createdAt,
    this.loanId = '',
    this.channel = '',
    this.cardType = '',
    this.cardLast4 = '',
    this.cardBank = '',
    this.paidAt,
    this.customerId = '',
    this.customerName = '',
    this.customerRef = '',
    this.fees = 0,
    this.gatewayResponse = '',
  });

  final String id;
  final String reference;
  final double amount;
  final DepositPurpose purpose;
  final String purposeLabel;
  final String loanId;
  final PaystackStatus status;
  final String statusLabel;

  /// Whether the wallet or the loan has been credited. The only thing that
  /// means the money is the customer's.
  final bool credited;
  final String channel;
  final String cardType;
  final String cardLast4;
  final String cardBank;
  final DateTime createdAt;
  final DateTime? paidAt;

  // The panel's fields.
  final String customerId;
  final String customerName;
  final String customerRef;

  /// What Paystack charged Kudi9ja to take it.
  final double fees;
  final String gatewayResponse;

  /// Still waiting on Paystack — a bank transfer can take a few minutes.
  bool get stillProcessing => status == PaystackStatus.initialized;

  /// "Visa •••• 4081", or how it was paid when it was not a card.
  String get paidWith {
    if (cardLast4.isNotEmpty) {
      return '${cardType.isEmpty ? 'Card' : _title(cardType)} •••• $cardLast4';
    }
    return channel.isEmpty ? '' : _title(channel.replaceAll('_', ' '));
  }

  static String _title(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  static PaystackPayment fromApi(Map<String, dynamic> j) => PaystackPayment(
    id: str(j['id']),
    reference: str(j['reference']),
    amount: money(j['amount']),
    purpose: str(j['purpose']) == 'LOAN_REPAYMENT'
        ? DepositPurpose.loanRepayment
        : DepositPurpose.wallet,
    purposeLabel: str(j['purposeLabel']),
    loanId: str(j['loanId']),
    status: wireEnum(j['status'], PaystackStatus.values, PaystackStatus.initialized),
    statusLabel: str(j['statusLabel']),
    credited: boolean(j['credited']),
    channel: str(j['channel']),
    cardType: str(j['cardType']),
    cardLast4: str(j['cardLast4']),
    cardBank: str(j['cardBank']),
    createdAt: date(j['createdAt']),
    paidAt: dateOrNull(j['paidAt']),
    customerId: str(j['userId']),
    customerName: str(j['customerName']),
    customerRef: str(j['customerRef']),
    fees: money(j['fees']),
    gatewayResponse: str(j['gatewayResponse']),
  );
}
