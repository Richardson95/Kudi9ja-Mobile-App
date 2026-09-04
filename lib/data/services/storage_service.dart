import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/admin.dart';
import '../models/app_notification.dart';
import '../models/deposit.dart';
import '../models/models.dart';
import '../models/platform_settings.dart';
import '../models/withdrawal.dart';
import '../models/thrift.dart';

/// Local persistence. In production these calls sit behind the Kudi9ja API;
/// here they read and write a single device-local store so the whole product
/// is demonstrable end to end.
class StorageService {
  StorageService(this._prefs);

  final SharedPreferences _prefs;

  static Future<StorageService> init() async =>
      StorageService(await SharedPreferences.getInstance());

  static const _kUser = 'k9.user';
  static const _kSignInPasscode = 'k9.passcode.signin';
  static const _kTxnPin = 'k9.passcode.txn';
  static const _kPassword = 'k9.password';
  static const _kBalance = 'k9.balance';
  static const _kPlans = 'k9.plans';
  static const _kLoans = 'k9.loans';
  static const _kTxns = 'k9.txns';
  static const _kOnboarded = 'k9.onboarded';
  static const _kSignedIn = 'k9.signedIn';
  static const _kHideBalance = 'k9.hideBalance';
  static const _kThemeMode = 'k9.themeMode';
  static const _kCircles = 'k9.circles';
  static const _kNotifications = 'k9.notifications';
  static const _kAutoDebit = 'k9.autoDebit';
  static const _kAdmins = 'k9.admins';
  static const _kAudit = 'k9.audit';
  static const _kSettings = 'k9.settings';
  static const _kWithdrawals = 'k9.withdrawals';
  static const _kDeposits = 'k9.deposits';

  // ── Onboarding ──────────────────────────────────────────────────────────
  bool get hasSeenOnboarding => _prefs.getBool(_kOnboarded) ?? false;
  Future<void> setSeenOnboarding() => _prefs.setBool(_kOnboarded, true);

  // ── Session ─────────────────────────────────────────────────────────────
  bool get isSignedIn => _prefs.getBool(_kSignedIn) ?? false;
  Future<void> setSignedIn(bool v) => _prefs.setBool(_kSignedIn, v);

  bool get hideBalance => _prefs.getBool(_kHideBalance) ?? false;
  Future<void> setHideBalance(bool v) => _prefs.setBool(_kHideBalance, v);

  /// Light, dark, or follow the phone. Stored on the device today; it
  /// belongs on the account once there is a backend, so the choice follows
  /// the customer between devices.
  int? get themeMode => _prefs.getInt(_kThemeMode);
  Future<void> setThemeMode(int v) => _prefs.setInt(_kThemeMode, v);

  // ── User ────────────────────────────────────────────────────────────────
  AppUser? get user {
    final raw = _prefs.getString(_kUser);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(AppUser u) =>
      _prefs.setString(_kUser, jsonEncode(u.toJson()));

  // ── Credentials ─────────────────────────────────────────────────────────
  // Hashed before storage — a plaintext passcode never touches the disk.
  String? get signInPasscodeHash => _prefs.getString(_kSignInPasscode);
  Future<void> saveSignInPasscode(String hash) =>
      _prefs.setString(_kSignInPasscode, hash);

  String? get txnPinHash => _prefs.getString(_kTxnPin);
  Future<void> saveTxnPin(String hash) => _prefs.setString(_kTxnPin, hash);

  String? get passwordHash => _prefs.getString(_kPassword);
  Future<void> savePassword(String hash) => _prefs.setString(_kPassword, hash);

  // ── Money ───────────────────────────────────────────────────────────────
  double get balance => _prefs.getDouble(_kBalance) ?? 0;
  Future<void> saveBalance(double v) => _prefs.setDouble(_kBalance, v);

  List<SavingsPlan> get plans => _decodeList(_kPlans, SavingsPlan.fromJson);
  Future<void> savePlans(List<SavingsPlan> v) =>
      _encodeList(_kPlans, v.map((e) => e.toJson()).toList());

  List<Loan> get loans => _decodeList(_kLoans, Loan.fromJson);
  Future<void> saveLoans(List<Loan> v) =>
      _encodeList(_kLoans, v.map((e) => e.toJson()).toList());

  List<Transaction> get transactions =>
      _decodeList(_kTxns, Transaction.fromJson);
  Future<void> saveTransactions(List<Transaction> v) =>
      _encodeList(_kTxns, v.map((e) => e.toJson()).toList());

  List<ThriftCircle> get circles => _decodeList(_kCircles, ThriftCircle.fromJson);
  Future<void> saveCircles(List<ThriftCircle> v) =>
      _encodeList(_kCircles, v.map((e) => e.toJson()).toList());

  List<AppNotification> get notifications =>
      _decodeList(_kNotifications, AppNotification.fromJson);
  Future<void> saveNotifications(List<AppNotification> v) =>
      _encodeList(_kNotifications, v.map((e) => e.toJson()).toList());

  /// Whether loan instalments are pulled from the wallet automatically.
  bool get autoDebit => _prefs.getBool(_kAutoDebit) ?? false;
  Future<void> setAutoDebit(bool v) => _prefs.setBool(_kAutoDebit, v);

  // ── Admin ───────────────────────────────────────────────────────────────
  List<AdminUser> get admins => _decodeList(_kAdmins, AdminUser.fromJson);
  Future<void> saveAdmins(List<AdminUser> v) =>
      _encodeList(_kAdmins, v.map((e) => e.toJson()).toList());

  List<AuditEntry> get audit => _decodeList(_kAudit, AuditEntry.fromJson);
  Future<void> saveAudit(List<AuditEntry> v) =>
      _encodeList(_kAudit, v.map((e) => e.toJson()).toList());

  List<WithdrawalRequest> get withdrawals =>
      _decodeList(_kWithdrawals, WithdrawalRequest.fromJson);
  Future<void> saveWithdrawals(List<WithdrawalRequest> v) =>
      _encodeList(_kWithdrawals, v.map((e) => e.toJson()).toList());

  List<DepositClaim> get deposits =>
      _decodeList(_kDeposits, DepositClaim.fromJson);
  Future<void> saveDeposits(List<DepositClaim> v) =>
      _encodeList(_kDeposits, v.map((e) => e.toJson()).toList());

  PlatformSettings get platformSettings {
    final raw = _prefs.getString(_kSettings);
    if (raw == null) return const PlatformSettings();
    try {
      return PlatformSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const PlatformSettings();
    }
  }

  Future<void> savePlatformSettings(PlatformSettings v) =>
      _prefs.setString(_kSettings, jsonEncode(v.toJson()));

  // ── Helpers ─────────────────────────────────────────────────────────────
  List<T> _decodeList<T>(String key, T Function(Map<String, dynamic>) build) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => build(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _encodeList(String key, List<Map<String, dynamic>> data) =>
      _prefs.setString(key, jsonEncode(data));

  /// Wipes the account but keeps onboarding seen.
  Future<void> wipeAccount() async {
    for (final k in [
      _kUser,
      _kSignInPasscode,
      _kTxnPin,
      _kPassword,
      _kBalance,
      _kPlans,
      _kLoans,
      _kTxns,
      _kSignedIn,
      _kHideBalance,
      _kCircles,
      _kNotifications,
      _kAutoDebit,
      _kAdmins,
      _kAudit,
      _kWithdrawals,
      _kDeposits,
    ]) {
      await _prefs.remove(k);
    }
  }
}
