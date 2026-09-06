/// Turns the server's JSON into the app's models.
///
/// Kept apart from each model's own `fromJson`, which reads what the app itself
/// wrote to disk. The two are genuinely different formats and merging them
/// would mean one parser guessing which it had been handed:
///
///   * **Enums.** On disk they are integer indices; on the wire they are names.
///     Indices are the app's own bad habit — reordering an enum silently
///     reinterprets every stored record — so nothing here reads one. Wire names
///     are matched by name, and an unrecognised name falls back to a safe value
///     rather than throwing, because a server that grows a new state must not
///     crash an app that has not been updated.
///   * **Field names.** `date` on disk, `occurredAt` on the wire, and so on.
///   * **Reach.** The server sends far more than the app models hold —
///     `statusLabel`, `progress`, `daysRemaining`, whole schedules. What the app
///     already computes for itself is ignored here; what only the server knows
///     is what these read.
///
/// Everything is defensive about nulls. A field the server stops sending should
/// degrade a screen, never crash one.
library;

import '../../core/theme/app_colors.dart';
import '../models/admin.dart';
import '../models/app_notification.dart';
import '../models/deposit.dart';
import '../models/models.dart';
import '../models/thrift.dart';
import '../models/withdrawal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Primitives
// ─────────────────────────────────────────────────────────────────────────────

double _money(Object? value) => switch (value) {
      num n => n.toDouble(),
      String s => double.tryParse(s) ?? 0,
      _ => 0,
    };

double? _moneyOrNull(Object? value) => value == null ? null : _money(value);

int _int(Object? value, [int fallback = 0]) => switch (value) {
      num n => n.toInt(),
      String s => int.tryParse(s) ?? fallback,
      _ => fallback,
    };

bool _bool(Object? value, [bool fallback = false]) =>
    value is bool ? value : fallback;

String _str(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

/// Parses a timestamp, falling back to now.
///
/// A record with an unreadable date is still worth showing — a transaction that
/// vanishes because its timestamp was malformed is worse than one dated today,
/// since the customer can see the amount either way.
DateTime _date(Object? value, [DateTime? fallback]) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toLocal();
  }
  return fallback ?? DateTime.now();
}

DateTime? _dateOrNull(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toLocal();
}

/// Matches a wire name against an enum, by name, tolerantly.
///
/// The server writes `SAVINGS_LOCK`; the app calls it `savingsLock`. Rather than
/// keep a table that has to be edited in two places every time a state is added,
/// both sides are reduced to letters and digits and compared.
T _enum<T extends Enum>(Object? value, List<T> values, T fallback) {
  if (value is! String) return fallback;
  final wanted = value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
  for (final candidate in values) {
    if (candidate.name.toLowerCase() == wanted) return candidate;
  }
  return fallback;
}

Map<String, dynamic> _obj(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : const {};

List<Map<String, dynamic>> _list(Object? value) => value is List
    ? value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
    : const [];

// ─────────────────────────────────────────────────────────────────────────────
// User
// ─────────────────────────────────────────────────────────────────────────────

/// Reads a `ProfileResponse`.
///
/// The BVN and NIN arrive as their last four digits and nothing more — the
/// server never returns them in full, and the app has no reason to hold them.
/// They are kept in the model's `bvn`/`nin` fields as those four digits so the
/// profile screen can show `••••••• 1234` without a second field.
AppUser userFromApi(Map<String, dynamic> j) => AppUser(
      id: _str(j['id']),
      customerRef: j['customerRef'] as String?,
      fullName: _str(j['fullName']),
      email: _str(j['email']),
      phone: _str(j['phone']),
      // A closed account has its date of birth erased once the retention
      // period ends, so this can genuinely be absent.
      dateOfBirth: _date(j['dateOfBirth'], DateTime(1970)),
      gender: _str(j['gender']),
      bvn: _str(j['bvnLast4']),
      nin: _str(j['ninLast4']),
      address: _str(j['address']),
      state: _str(j['state']),
      payoutBank: _str(j['payoutBank']),
      payoutAccountNumber: _str(j['payoutAccountNumber']),
      createdAt: _date(j['createdAt']),
      kycTier: _enum(j['kycTier'], KycTier.values, KycTier.tier0),
      emailVerified: _bool(j['emailVerified']),
      phoneVerified: _bool(j['phoneVerified']),
      biometricsEnabled: _bool(j['biometricsEnabled']),
      securityQuestion: _str(j['securityQuestion']),
    );

/// The theme the account carries, so the choice follows the customer between
/// phones rather than living on one device.
AppThemeMode themeModeFromApi(Object? value) =>
    _enum(value, AppThemeMode.values, AppThemeMode.system);

String themeModeToApi(AppThemeMode mode) => switch (mode) {
      AppThemeMode.system => 'SYSTEM',
      AppThemeMode.light => 'LIGHT',
      AppThemeMode.dark => 'DARK',
    };

// ─────────────────────────────────────────────────────────────────────────────
// Ledger
// ─────────────────────────────────────────────────────────────────────────────

Transaction transactionFromApi(Map<String, dynamic> j) => Transaction(
      id: _str(j['id']),
      kind: _enum(j['kind'], TxKind.values, TxKind.fee),
      amount: _money(j['amount']),
      description: _str(j['description']),
      date: _date(j['occurredAt']),
      balanceAfter: _money(j['balanceAfter']),
      reference: _str(j['reference']),
      counterparty: _str(j['counterparty']),
      // An unknown status is treated as pending rather than successful. If the
      // app must guess about money, it should guess the cautious way: showing
      // an unsettled payment as settled is how a customer spends twice.
      status: _enum(j['status'], TxStatus.values, TxStatus.pending),
    );

List<Transaction> transactionsFromApi(Object? value) =>
    _list(value).map(transactionFromApi).toList();

/// What the wallet endpoint reports. These are the server's figures, not the
/// app's — the app used to add them up itself, and two totals that disagree is
/// worse than one that is occasionally stale.
class WalletSnapshot {
  const WalletSnapshot({
    required this.balance,
    required this.totalSaved,
    required this.totalOwed,
    required this.netWorth,
    required this.totalInterestEarned,
    required this.pendingWithdrawals,
    this.customerRef = '',
  });

  final double balance;
  final double totalSaved;
  final double totalOwed;
  final double netWorth;
  final double totalInterestEarned;
  final double pendingWithdrawals;
  final String customerRef;

  static WalletSnapshot fromApi(Map<String, dynamic> j) => WalletSnapshot(
        balance: _money(j['balance']),
        totalSaved: _money(j['totalSaved']),
        totalOwed: _money(j['totalOwed']),
        netWorth: _money(j['netWorth']),
        totalInterestEarned: _money(j['totalInterestEarned']),
        pendingWithdrawals: _money(j['pendingWithdrawals']),
        customerRef: _str(j['customerRef']),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Savings
// ─────────────────────────────────────────────────────────────────────────────

SavingsPlan planFromApi(Map<String, dynamic> j) => SavingsPlan(
      id: _str(j['id']),
      title: _str(j['title']),
      principal: _money(j['principal']),
      lockDays: _int(j['lockDays']),
      interestPaid: _money(j['interestPaid']),
      startDate: _date(j['startDate']),
      maturityDate: _date(j['maturityDate']),
      status: _enum(j['status'], SavingsStatus.values, SavingsStatus.active),
      type: _enum(j['type'], SavingsType.values, SavingsType.fixed),
      targetAmount: _moneyOrNull(j['targetAmount']),
      emoji: _str(j['emoji'], '🎯'),
      autoFrequency: j['autoFrequency'] == null
          ? null
          : _enum(j['autoFrequency'], AutoFrequency.values, AutoFrequency.monthly),
      autoAmount: _moneyOrNull(j['autoAmount']),
      nextAutoRun: _dateOrNull(j['nextAutoRun']),
      autoEnabled: _bool(j['autoEnabled']),
      contributions: _int(j['contributions'], 1),
      bonusRate: _money(j['bonusRate']),
      bonusPaid: _bool(j['bonusPaid']),
    );

List<SavingsPlan> plansFromApi(Object? value) =>
    _list(value).map(planFromApi).toList();

// ─────────────────────────────────────────────────────────────────────────────
// Lending
// ─────────────────────────────────────────────────────────────────────────────

/// Reads a `LoanResponse`.
///
/// A pending loan has no disbursement date and no due date — it has not been
/// approved, so neither exists yet. Both fall back to the request date rather
/// than to now, so a loan requested last week does not appear to have been
/// disbursed today while it sits in the queue.
Loan loanFromApi(Map<String, dynamic> j) {
  final requested = _date(j['requestedAt']);
  return Loan(
    id: _str(j['id']),
    principal: _money(j['principal']),
    tenureMonths: _int(j['tenureMonths'], 1),
    flatRate: _money(j['flatRate']),
    processingFee: _money(j['processingFee']),
    purpose: _str(j['purpose']),
    disbursedAt: _date(j['disbursedAt'], requested),
    dueDate: _date(j['dueDate'], requested),
    amountRepaid: _money(j['amountRepaid']),
    status: _enum(j['status'], LoanStatus.values, LoanStatus.pending),
  );
}

List<Loan> loansFromApi(Object? value) => _list(value).map(loanFromApi).toList();

/// What the server offers this customer, and why.
///
/// The app used to work this out from local savings and a local credit score.
/// It is the server's decision — the app asks and displays the answer, so the
/// figure a customer is shown is the figure they can actually borrow.
class LoanEligibility {
  const LoanEligibility({
    required this.offer,
    required this.headroom,
    required this.creditScore,
    required this.band,
    required this.eligible,
    this.reason = '',
  });

  final double offer;
  final double headroom;
  final int creditScore;
  final String band;
  final bool eligible;
  final String reason;

  static LoanEligibility fromApi(Map<String, dynamic> j) => LoanEligibility(
        offer: _money(j['offer']),
        headroom: _money(j['headroom']),
        creditScore: _int(j['creditScore']),
        band: _str(j['band']),
        eligible: _bool(j['eligible'], true),
        reason: _str(j['reason']),
      );
}

class CreditScoreSnapshot {
  const CreditScoreSnapshot({
    required this.score,
    required this.band,
    required this.factors,
  });

  final int score;
  final String band;
  final List<CreditFactorRow> factors;

  static CreditScoreSnapshot fromApi(Map<String, dynamic> j) =>
      CreditScoreSnapshot(
        score: _int(j['score']),
        band: _str(j['band']),
        factors: _list(j['factors']).map(CreditFactorRow.fromApi).toList(),
      );
}

class CreditFactorRow {
  const CreditFactorRow({
    required this.label,
    required this.detail,
    required this.points,
    required this.maxPoints,
  });

  final String label;
  final String detail;
  final int points;
  final int maxPoints;

  static CreditFactorRow fromApi(Map<String, dynamic> j) => CreditFactorRow(
        label: _str(j['label']),
        detail: _str(j['detail']),
        points: _int(j['points']),
        maxPoints: _int(j['maxPoints']),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Money in and out
// ─────────────────────────────────────────────────────────────────────────────

/// Reads a `ClaimResponse`.
///
/// `receiptPath` is left empty on purpose. On the server the receipt is a
/// private object behind a signed, expiring, audited URL — there is no path the
/// app can hold, and `hasReceipt` is the only thing worth knowing here.
DepositClaim claimFromApi(Map<String, dynamic> j, {String customerName = '', String customerRef = ''}) =>
    DepositClaim(
      id: _str(j['id']),
      customerName: customerName,
      customerAccount: customerRef,
      amount: _money(j['amount']),
      claimedAt: _date(j['claimedAt']),
      reference: _str(j['reference']),
      purpose: _enum(j['purpose'], DepositPurpose.values, DepositPurpose.wallet),
      loanId: j['loanId'] as String?,
      loanPurpose: _str(j['loanPurpose']),
      senderName: _str(j['senderName']),
      status: _enum(j['status'], DepositStatus.values, DepositStatus.pending),
      reviewedAt: _dateOrNull(j['reviewedAt']),
      reviewedBy: _str(j['reviewedBy']),
      note: _str(j['note']),
    );

List<DepositClaim> claimsFromApi(Object? value,
        {String customerName = '', String customerRef = ''}) =>
    _list(value)
        .map((e) => claimFromApi(e, customerName: customerName, customerRef: customerRef))
        .toList();

WithdrawalRequest withdrawalFromApi(Map<String, dynamic> j,
        {String customerName = '', String customerRef = ''}) =>
    WithdrawalRequest(
      id: _str(j['id']),
      customerName: customerName,
      customerAccount: customerRef,
      amount: _money(j['amount']),
      bank: _str(j['bank']),
      destinationAccount: _str(j['destinationAccount']),
      requestedAt: _date(j['requestedAt']),
      reference: _str(j['reference']),
      status: _enum(j['status'], WithdrawalStatus.values, WithdrawalStatus.pending),
      reviewedAt: _dateOrNull(j['reviewedAt']),
      reviewedBy: _str(j['reviewedBy']),
      note: _str(j['note']),
    );

List<WithdrawalRequest> withdrawalsFromApi(Object? value,
        {String customerName = '', String customerRef = ''}) =>
    _list(value)
        .map((e) =>
            withdrawalFromApi(e, customerName: customerName, customerRef: customerRef))
        .toList();

/// Where to send a payment, and under what reference.
///
/// The reference is the whole point: the collection account is the same for
/// every customer, so the narration is the only thing telling one ₦50,000
/// transfer from another on the same statement.
class PaymentInstruction {
  const PaymentInstruction({
    required this.reference,
    required this.accountName,
    required this.accountNumber,
    required this.bank,
    this.note = '',
  });

  final String reference;
  final String accountName;
  final String accountNumber;
  final String bank;
  final String note;

  static PaymentInstruction fromApi(Map<String, dynamic> j) {
    final account = _obj(j['account']).isEmpty ? j : _obj(j['account']);
    return PaymentInstruction(
      reference: _str(j['reference']),
      accountName: _str(account['accountName']),
      accountNumber: _str(account['accountNumber']),
      bank: _str(account['bank']),
      note: _str(j['note'] ?? j['message']),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thrift
// ─────────────────────────────────────────────────────────────────────────────

ThriftMember memberFromApi(Map<String, dynamic> j) => ThriftMember(
      customerRef: _str(j['customerRef']),
      name: _str(j['displayName']),
      initials: _str(j['initials']),
      isMe: _bool(j['isMe']),
    );

ThriftCircle circleFromApi(Map<String, dynamic> j) => ThriftCircle(
      id: _str(j['id']),
      name: _str(j['name']),
      contribution: _money(j['contribution']),
      frequency: _enum(j['frequency'], AutoFrequency.values, AutoFrequency.monthly),
      members: _list(j['members']).map(memberFromApi).toList(),
      startDate: _date(j['startDate']),
      createdByMe: _bool(j['createdByMe']),
      currentRound: _int(j['currentRound'], 1),
      roundsPaid: (j['myRoundsPaid'] as List?)?.map((e) => _int(e)).toList() ?? const [],
      inviteCode: _str(j['inviteCode']),
      emoji: _str(j['emoji'], '🤝'),
    );

List<ThriftCircle> circlesFromApi(Object? value) =>
    _list(value).map(circleFromApi).toList();

// ─────────────────────────────────────────────────────────────────────────────
// Notifications
// ─────────────────────────────────────────────────────────────────────────────

AppNotification notificationFromApi(Map<String, dynamic> j) => AppNotification(
      id: _str(j['id']),
      kind: _enum(j['kind'], NotifyKind.values, NotifyKind.general),
      title: _str(j['title']),
      body: _str(j['body']),
      date: _date(j['date']),
      read: _bool(j['read']),
      amount: _moneyOrNull(j['amount']),
    );

List<AppNotification> notificationsFromApi(Object? value) =>
    _list(value).map(notificationFromApi).toList();

// ─────────────────────────────────────────────────────────────────────────────
// Paging
// ─────────────────────────────────────────────────────────────────────────────

/// One page of a list endpoint.
///
/// The server pages everything that can grow without bound. Reading only
/// `content` and ignoring the rest is how a customer with two hundred
/// transactions is shown twenty-five and told that is all of them.
class Page<T> {
  const Page({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  final List<T> items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  bool get hasMore => page + 1 < totalPages;

  static Page<T> fromApi<T>(Object? value, T Function(Map<String, dynamic>) build) {
    // A plain list, for the endpoints that return everything.
    if (value is List) {
      final items = _list(value).map(build).toList();
      return Page(
        items: items,
        page: 0,
        size: items.length,
        totalElements: items.length,
        totalPages: 1,
      );
    }
    final j = _obj(value);
    final items = _list(j['content'] ?? j['items']).map(build).toList();
    return Page(
      items: items,
      page: _int(j['page']),
      size: _int(j['size'], items.length),
      totalElements: _int(j['totalElements'], items.length),
      totalPages: _int(j['totalPages'], 1),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The admin panel
// ─────────────────────────────────────────────────────────────────────────────

/// A row in the customer list.
///
/// The list endpoint is deliberately thin — it carries what a list shows and
/// nothing more. Balances beyond the wallet, identity numbers and scores come
/// from the detail endpoint, so browsing a page of customers does not spray
/// everyone's BVN across the wire.
CustomerRecord customerRowFromApi(Map<String, dynamic> j) => CustomerRecord(
      id: _str(j['id']),
      fullName: _str(j['fullName']),
      email: _str(j['email']),
      phone: _str(j['phone']),
      // The customer reference, not a Kudi9ja account number: Kudi9ja issues
      // none, and this is what a bank narration is matched against.
      accountNumber: _str(j['customerRef']),
      joinedAt: _date(j['createdAt']),
      balance: _money(j['balance']),
      totalSaved: 0,
      totalOwed: 0,
      interestPaid: 0,
      creditScore: 0,
      plansCount: 0,
      loansCount: 0,
      verified: _str(j['kycTier']) != 'TIER0',
      frozen: _str(j['accountStatus']) == 'FROZEN',
    );

/// The full customer record behind one row.
CustomerRecord customerDetailFromApi(Map<String, dynamic> j) {
  final money = _obj(j['financials']);
  return CustomerRecord(
    id: _str(j['id']),
    fullName: _str(j['fullName']),
    email: _str(j['email']),
    phone: _str(j['phone']),
    accountNumber: _str(j['customerRef']),
    joinedAt: _date(j['createdAt']),
    balance: _money(money['balance']),
    totalSaved: _money(money['totalSaved']),
    totalOwed: _money(money['totalOwed']),
    interestPaid: _money(money['totalInterestEarned']),
    creditScore: _int(money['creditScore']),
    plansCount: _int(money['totalPlans']),
    loansCount: _int(money['totalLoans']),
    state: _str(j['state']),
    // Four digits, which is all the server will ever return. The panel shows
    // them so a support call can be verified without anybody reading a whole
    // BVN aloud.
    bvn: _str(j['bvnLast4']),
    nin: _str(j['ninLast4']),
    address: _str(j['address']),
    gender: _str(j['gender']),
    dateOfBirth: _dateOrNull(j['dateOfBirth']),
    verified: _str(j['kycTier']) != 'TIER0',
    frozen: _str(j['accountStatus']) == 'FROZEN',
  );
}

/// A pay-in claim as the panel sees it — with the customer attached, which the
/// customer's own view of the same claim has no need of.
DepositClaim adminClaimFromApi(Map<String, dynamic> j) => claimFromApi(
      j,
      customerName: _str(j['customerName']),
      customerRef: _str(j['customerRef']),
    );

WithdrawalRequest adminWithdrawalFromApi(Map<String, dynamic> j) =>
    withdrawalFromApi(
      j,
      customerName: _str(j['customerName']),
      customerRef: _str(j['customerRef']),
    );

AdminUser teamMemberFromApi(Map<String, dynamic> j) => AdminUser(
      id: _str(j['id']),
      name: _str(j['name']),
      email: _str(j['email']),
      role: _enum(j['role'], AdminRole.values, AdminRole.viewer),
      addedAt: _date(j['addedAt']),
      phone: _str(j['phone']),
      addedBy: _str(j['addedBy']),
      active: _bool(j['active'], true),
      lastActive: _dateOrNull(j['lastActiveAt']),
    );

AuditEntry auditRowFromApi(Map<String, dynamic> j) => AuditEntry(
      id: _str(j['id']),
      actor: _str(j['actor']),
      action: _str(j['action']),
      detail: _str(j['detail']),
      date: _date(j['date']),
      category: _enum(j['category'], AuditCategory.values, AuditCategory.general),
    );
