import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../api/api_exception.dart';
import '../api/kudi9ja_api.dart';

/// Receiving push notifications.
///
/// The server half already works: it sends through Firebase whenever money
/// moves. This is the half that lets a handset hear it.
///
/// Three things are worth knowing before reading.
///
/// **Nothing here is required for the app to run.** Firebase may be
/// unconfigured, the customer may refuse permission, Google Play Services may
/// be missing from the device. Every one of those is normal, and every one of
/// them leaves the app working: notifications are written on the server
/// regardless and appear the moment Kudi9ja is opened. Push is how they arrive
/// sooner, not whether they exist. So every failure in here is swallowed and
/// logged, never thrown.
///
/// **The token belongs to the account, not the phone.** It is registered after
/// sign-in and removed on sign-out, so a customer signing in on a second handset
/// is reachable on both, and signing out of one does not silence the other.
///
/// **A token can change without anybody signing in.** Firebase reissues them —
/// on a restore, on a reinstall, occasionally for its own reasons — so
/// [onTokenRefresh] is subscribed to and re-registers. Without that, a customer
/// quietly stops receiving anything and there is no symptom to notice.
class PushService {
  PushService(this._api);

  final Kudi9jaApi _api;

  FirebaseMessaging? _messaging;
  StreamSubscription<String>? _refreshes;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;

  String? _token;
  bool _started = false;

  /// The token this handset is currently registered under, if any.
  String? get token => _token;

  /// Whether push is actually working, as opposed to merely configured.
  bool get isActive => _token != null;

  /// Called when a notification arrives while the app is open, and when one is
  /// tapped. Set by the app so it can refresh the screen or navigate.
  void Function(RemoteMessage message)? onMessage;
  void Function(RemoteMessage message)? onOpened;

  /// Brings push up for a signed-in customer.
  ///
  /// Safe to call more than once — signing in again, or resuming — and safe to
  /// call when Firebase was never configured.
  Future<void> start() async {
    if (_started) {
      await _register();
      return;
    }

    try {
      // Already initialised when the app started; this is a no-op then, and the
      // thing that fails loudly when google-services.json is missing.
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    } catch (e) {
      _log('Firebase is not configured on this build; push is off. $e');
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;
      _messaging = messaging;

      // Android 13 and every iOS version ask the customer. A refusal is an
      // answer, not an error: they still see everything in the app.
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _log('The customer declined notifications.');
        _started = true;
        return;
      }

      _foreground = FirebaseMessaging.onMessage.listen((message) {
        onMessage?.call(message);
      });
      _opened = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        onOpened?.call(message);
      });

      // A token can be reissued at any time. Missing this is how a handset
      // silently stops receiving anything, with no symptom to notice.
      _refreshes = messaging.onTokenRefresh.listen((fresh) {
        _token = fresh;
        unawaited(_send(fresh));
      });

      _started = true;
      await _register();
    } catch (e) {
      _log('Could not start push. $e');
    }
  }

  /// Registers this handset against the signed-in account.
  Future<void> _register() async {
    final messaging = _messaging;
    if (messaging == null) return;
    try {
      final fresh = await messaging.getToken();
      if (fresh == null) {
        _log('Firebase returned no token; push is off on this device.');
        return;
      }
      _token = fresh;
      await _send(fresh);
    } catch (e) {
      // Reached on an emulator without Google Play Services, among other
      // ordinary situations.
      _log('Could not obtain a push token. $e');
    }
  }

  Future<void> _send(String token) async {
    try {
      await _api.registerDevice(token: token, platform: _platform);
    } on ApiException catch (e) {
      _log('The server would not register this device: ${e.message}');
    }
  }

  /// Unregisters this handset. Called on sign-out.
  ///
  /// Only this one: signing out on a phone must not silence the customer's
  /// other devices.
  Future<void> stop() async {
    final token = _token;
    _token = null;
    if (token == null) return;
    try {
      await _api.unregisterDevice(token);
    } on ApiException catch (e) {
      _log('Could not unregister this device: ${e.message}');
    }
  }

  /// Releases the listeners. The registration on the server is left alone —
  /// closing the app is not signing out.
  Future<void> dispose() async {
    await _refreshes?.cancel();
    await _foreground?.cancel();
    await _opened?.cancel();
  }

  static String get _platform {
    if (kIsWeb) return 'WEB';
    if (Platform.isIOS) return 'IOS';
    if (Platform.isAndroid) return 'ANDROID';
    return 'UNKNOWN';
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[push] $message');
  }
}
