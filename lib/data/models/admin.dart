import 'models.dart';

/// What an admin is allowed to do. Roles are hierarchical: an owner can do
/// everything, a viewer can only look.
enum AdminRole { owner, admin, support, viewer }

extension AdminRoleX on AdminRole {
  String get label => switch (this) {
    AdminRole.owner => 'Owner',
    AdminRole.admin => 'Administrator',
    AdminRole.support => 'Support',
    AdminRole.viewer => 'Viewer',
  };

  String get blurb => switch (this) {
    AdminRole.owner =>
      'Full control, including rates and managing the admin team',
    AdminRole.admin => 'Everything except adding or removing other admins',
    AdminRole.support => 'View customers and act on loans; cannot change rates',
    AdminRole.viewer => 'Read-only access to the panel',
  };

  /// Can change platform rates, limits and feature switches.
  bool get canEditSettings =>
      this == AdminRole.owner || this == AdminRole.admin;

  /// Can add, demote or remove other admins.
  bool get canManageTeam => this == AdminRole.owner;

  /// Can approve, decline or write off a loan.
  bool get canActOnLoans => this != AdminRole.viewer;

  /// Can confirm or reject a pay-in, and approve or decline a withdrawal.
  /// Money only moves on this permission.
  bool get canApprovePayments => this != AdminRole.viewer;

  /// Can flag or freeze a customer.
  bool get canManageCustomers => this != AdminRole.viewer;

  /// Can open a customer's full record.
  bool get canViewCustomers => true;

  /// Can read the audit log. Everyone can — being watched is the point, and
  /// hiding the record from some of the team would defeat it.
  bool get canViewAudit => true;
}

/// One row of the permission matrix: what a capability is called, and which
/// roles hold it.
///
/// The table the panel renders is built from these, and each [held] reads the
/// same getter that gates the real screen — so the table cannot drift away
/// from what the panel actually allows.
class AdminCapability {
  const AdminCapability(this.label, this.held);

  final String label;
  final bool Function(AdminRole) held;
}

const kAdminCapabilities = <AdminCapability>[
  AdminCapability('See customers and their full records', _viewCustomers),
  AdminCapability('Read the audit log', _viewAudit),
  AdminCapability('Confirm pay-ins and approve withdrawals', _approvePayments),
  AdminCapability('Act on loans — remind, write off', _actOnLoans),
  AdminCapability('Flag or freeze a customer', _manageCustomers),
  AdminCapability('Change rates, limits and switches', _editSettings),
  AdminCapability('Add, promote, suspend or remove admins', _manageTeam),
];

bool _viewCustomers(AdminRole r) => r.canViewCustomers;
bool _viewAudit(AdminRole r) => r.canViewAudit;
bool _approvePayments(AdminRole r) => r.canApprovePayments;
bool _actOnLoans(AdminRole r) => r.canActOnLoans;
bool _manageCustomers(AdminRole r) => r.canManageCustomers;
bool _editSettings(AdminRole r) => r.canEditSettings;
bool _manageTeam(AdminRole r) => r.canManageTeam;

/// Someone with access to the admin panel. Membership is keyed on the email
/// address and nothing else — whoever
/// signs in with a listed address gets the panel.
class AdminUser {
  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.addedAt,
    this.phone = '',
    this.addedBy = '',
    this.active = true,
    this.lastActive,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final AdminRole role;
  final DateTime addedAt;
  final String addedBy;
  final bool active;
  final DateTime? lastActive;

  AdminUser copyWith({AdminRole? role, bool? active, DateTime? lastActive}) =>
      AdminUser(
        id: id,
        name: name,
        email: email,
        phone: phone,
        role: role ?? this.role,
        addedAt: addedAt,
        addedBy: addedBy,
        active: active ?? this.active,
        lastActive: lastActive ?? this.lastActive,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'role': role.index,
    'addedAt': addedAt.toIso8601String(),
    'addedBy': addedBy,
    'active': active,
    'lastActive': lastActive?.toIso8601String(),
  };

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
    id: j['id'] as String,
    name: j['name'] as String,
    email: j['email'] as String,
    phone: j['phone'] as String? ?? '',
    role: AdminRole.values[j['role'] as int],
    addedAt: DateTime.parse(j['addedAt'] as String),
    addedBy: j['addedBy'] as String? ?? '',
    active: j['active'] as bool? ?? true,
    lastActive: j['lastActive'] == null
        ? null
        : DateTime.parse(j['lastActive'] as String),
  );
}

/// An immutable record of something an admin did. Rate changes, team changes
/// and loan decisions all land here.
class AuditEntry {
  AuditEntry({
    required this.id,
    required this.actor,
    required this.action,
    required this.detail,
    required this.date,
    this.category = AuditCategory.general,
  });

  final String id;
  final String actor;
  final String action;
  final String detail;
  final DateTime date;
  final AuditCategory category;

  Map<String, dynamic> toJson() => {
    'id': id,
    'actor': actor,
    'action': action,
    'detail': detail,
    'date': date.toIso8601String(),
    'category': category.index,
  };

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
    id: j['id'] as String,
    actor: j['actor'] as String,
    action: j['action'] as String,
    detail: j['detail'] as String,
    date: DateTime.parse(j['date'] as String),
    category: AuditCategory.values[j['category'] as int? ?? 0],
  );
}

enum AuditCategory {
  general,
  settings,
  team,
  customer,
  loan,

  /// Somebody looked at a customer's records — a receipt, a bank account, an
  /// export of their data.
  ///
  /// Kept separate from [customer], which is about changing something. The
  /// Privacy Policy commits to being able to say who *viewed* a customer's
  /// details, and an entry filed under "General" answers nobody's question.
  dataAccess,

  /// A regulatory action: a report filed, a retention period run, an account
  /// frozen under an obligation rather than at anyone's discretion.
  compliance,
}

extension AuditCategoryX on AuditCategory {
  String get label => switch (this) {
    AuditCategory.general => 'General',
    AuditCategory.settings => 'Settings',
    AuditCategory.team => 'Admin team',
    AuditCategory.customer => 'Customer',
    AuditCategory.loan => 'Lending',
    AuditCategory.dataAccess => 'Record access',
    AuditCategory.compliance => 'Compliance',
  };
}

/// A customer as the admin panel sees them.
///
/// Every row is a real account. There is no illustrative data: fabricated
/// customers in a panel that also freezes accounts and releases money are a
/// standing invitation to act on one by mistake.
///
/// Device-local, [isThisDevice] is true for the one account on this phone.
/// Against the server this is a page of `GET /api/v1/admin/customers`.
class CustomerRecord {
  const CustomerRecord({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.accountNumber,
    required this.joinedAt,
    required this.balance,
    required this.totalSaved,
    required this.totalOwed,
    required this.interestPaid,
    required this.plansCount,
    required this.loansCount,
    this.state = '',
    this.bvn = '',
    this.nin = '',
    this.address = '',
    this.gender = '',
    this.dateOfBirth,
    this.verified = true,
    this.frozen = false,
    this.isThisDevice = false,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String accountNumber;
  final DateTime joinedAt;
  final double balance;
  final double totalSaved;
  final double totalOwed;
  final double interestPaid;
  final int plansCount;
  final int loansCount;
  final String state;
  final String bvn;
  final String nin;
  final String address;
  final String gender;
  final DateTime? dateOfBirth;
  final bool verified;
  final bool frozen;
  final bool isThisDevice;

  double get netWorth => balance + totalSaved;

  /// The same customer with what they owe filled in.
  ///
  /// The list endpoint is thin on purpose, so a row arrives knowing its wallet
  /// balance and nothing about lending. The panel holds the whole book by the
  /// time it draws this list, so the figure is filled from there rather than
  /// asked for a customer at a time.
  CustomerRecord withDebt({required double owed, required int loans}) =>
      CustomerRecord(
        id: id,
        fullName: fullName,
        email: email,
        phone: phone,
        accountNumber: accountNumber,
        joinedAt: joinedAt,
        balance: balance,
        totalSaved: totalSaved,
        totalOwed: owed,
        interestPaid: interestPaid,
        plansCount: plansCount,
        loansCount: loans,
        state: state,
        bvn: bvn,
        nin: nin,
        address: address,
        gender: gender,
        dateOfBirth: dateOfBirth,
        verified: verified,
        frozen: frozen,
        isThisDevice: isThisDevice,
      );
}

/// The book-wide figures, as `GET /api/v1/admin/overview` reports them.
///
/// These used to be added up in the app from a page of customer rows, which
/// carry a wallet balance and nothing else: every loan total the panel showed
/// was therefore zero, whatever the company had lent. The server already
/// totals the whole book — across every customer, not only the page that was
/// fetched — so the panel asks rather than counts.
class PlatformBook {
  const PlatformBook({
    required this.customers,
    required this.fundsHeld,
    required this.saved,
    required this.lent,
    required this.interestPaid,
    required this.interestCharged,
    this.feesCharged = 0,
    required this.overdue,
    required this.activePlans,
    required this.activeLoans,
    required this.overdueLoans,
    required this.repaidLoans,
  });

  final int customers;

  /// Everything sitting in wallets. Customers' money, not the company's.
  final double fundsHeld;
  final double saved;

  /// Principal out on loan, across live loans.
  final double lent;
  /// Interest paid **to** savers. Money the company has given up.
  final double interestPaid;

  /// Interest charged on the loans still running: what the live book earns if
  /// it all comes back. Contracted, not collected.
  final double interestCharged;

  /// Management (processing) fees on the loans still running. A one-off
  /// charge taken off the disbursement — not interest, so never added to
  /// [interestCharged].
  final double feesCharged;

  final double overdue;
  final int activePlans;
  final int activeLoans;
  final int overdueLoans;
  final int repaidLoans;
}

/// One loan in the lending book, as the panel lists it.
///
/// Distinct from [Loan], which is a loan on *this* account with its schedule.
/// This is somebody else's loan seen from the panel: enough to list, total and
/// act on, and no schedule, because the panel does not show one.
class BookLoan {
  const BookLoan({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerRef,
    required this.principal,
    required this.outstanding,
    required this.amountRepaid,
    required this.processingFee,
    required this.tenureMonths,
    required this.purpose,
    required this.status,
    required this.statusLabel,
    required this.disbursedAt,
    required this.dueDate,
    required this.daysOverdue,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String customerRef;
  final double principal;
  final double outstanding;
  final double amountRepaid;
  final double processingFee;
  final int tenureMonths;
  final String purpose;
  final LoanStatus status;
  final String statusLabel;
  final DateTime? disbursedAt;
  final DateTime? dueDate;
  final int daysOverdue;

  bool get isOpen =>
      status == LoanStatus.active || status == LoanStatus.overdue;
}

/// A loan written on paper, waiting for its borrower to open an account.
///
/// It is not on anybody's account yet and so appears nowhere in the lending
/// book. It is still money out of the door, which is why the panel shows it
/// rather than leaving it invisible until somebody signs up.
class WaitingLoan {
  const WaitingLoan({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.principal,
    required this.outstanding,
    required this.tenureMonths,
    required this.purpose,
    required this.disbursedAt,
    required this.dueDate,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final double principal;
  final double outstanding;
  final int tenureMonths;
  final String purpose;
  final DateTime? disbursedAt;
  final DateTime? dueDate;
}
