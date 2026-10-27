import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/deposit.dart';
import '../../data/models/paystack.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';

/// Paystack's own checkout page, inside the app.
///
/// Card details are typed into Paystack's page, never into Kudi9ja's. The app
/// watches only for the moment the page heads back — to the return address,
/// with the payment's reference on it — and then closes it and asks the
/// server what happened. Closing it early is fine too: the payment is
/// confirmed by its reference, not by where the page was when it closed.
class PaystackCheckoutScreen extends StatefulWidget {
  const PaystackCheckoutScreen({super.key, required this.checkout});

  final PaystackCheckout checkout;

  @override
  State<PaystackCheckoutScreen> createState() => _PaystackCheckoutScreenState();
}

class _PaystackCheckoutScreenState extends State<PaystackCheckoutScreen> {
  late final WebViewController _web;
  int _progress = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onNavigationRequest: _route,
          onUrlChange: (change) {
            final url = change.url;
            if (url != null && _isReturn(Uri.tryParse(url))) _finish();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkout.authorizationUrl));
  }

  /// Whether this address is Paystack sending the customer back: the return
  /// address, or anywhere off Paystack carrying the payment's reference.
  bool _isReturn(Uri? uri) {
    if (uri == null) return false;
    final configured = Uri.parse(AppConfig.paystackCallbackUrl);
    if (uri.host == configured.host && uri.path == configured.path) return true;
    final onPaystack = uri.host.endsWith('paystack.co') || uri.host.endsWith('paystack.com');
    final carriesReference = uri.queryParameters.containsKey('reference') ||
        uri.queryParameters.containsKey('trxref');
    // Paystack's own "close" page, when the customer cancels.
    final closed = onPaystack && uri.path.contains('close');
    return (!onPaystack && carriesReference) || closed;
  }

  FutureOr<NavigationDecision> _route(NavigationRequest request) async {
    final uri = Uri.tryParse(request.url);
    if (_isReturn(uri)) {
      _finish();
      return NavigationDecision.prevent;
    }
    // A bank app, USSD dialler or WhatsApp link: hand it to the phone, since
    // the page cannot open it.
    if (uri != null && uri.scheme != 'https' && uri.scheme != 'http' && uri.scheme != 'about') {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // Nothing on this phone opens it; the page stays where it was.
      }
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaystackResultScreen(
          reference: widget.checkout.reference,
          amount: widget.checkout.amount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // Leaving checkout still asks about the payment: the customer may
        // have paid and then pressed back before the page moved on.
        if (!didPop) _finish();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
            onPressed: _finish,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pay with Paystack', style: TextStyle(fontSize: 16)),
              Text(
                widget.checkout.amount.asNaira,
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: Icon(Icons.lock_rounded, size: 18, color: AppColors.success),
            ),
          ],
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    value: _progress / 100,
                    minHeight: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.gold),
                    backgroundColor: Colors.transparent,
                  ),
                )
              : null,
        ),
        body: WebViewWidget(controller: _web),
      ),
    );
  }
}

/// Asks the server about a Paystack payment, and says what happened.
///
/// A card is usually confirmed on the first ask. A bank transfer can take
/// Paystack a few minutes, so a payment still processing is asked about again
/// a few times before the screen says it will update on its own — it will:
/// Paystack tells the server, and the server credits it and sends a push.
class PaystackResultScreen extends StatefulWidget {
  const PaystackResultScreen({super.key, required this.reference, this.amount});

  final String reference;
  final double? amount;

  @override
  State<PaystackResultScreen> createState() => _PaystackResultScreenState();
}

enum _Outcome { checking, done, waiting, failed }

class _PaystackResultScreenState extends State<PaystackResultScreen> {
  static const _polls = 6;

  PaystackPayment? _payment;
  String? _error;
  _Outcome _outcome = _Outcome.checking;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_ask(1));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _ask(int attempt) async {
    try {
      final p = await context.read<AppState>().confirmPaystack(widget.reference);
      if (!mounted) return;
      setState(() {
        _payment = p;
        _error = null;
        if (p.credited) {
          _outcome = _Outcome.done;
        } else if (p.stillProcessing) {
          _outcome = attempt < _polls ? _Outcome.checking : _Outcome.waiting;
        } else {
          _outcome = _Outcome.failed;
        }
      });
      if (p.stillProcessing && attempt < _polls) {
        _timer = Timer(const Duration(seconds: 4), () => _ask(attempt + 1));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _outcome = _Outcome.failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _payment;
    final amount = p?.amount ?? widget.amount ?? 0;
    final (icon, color, title, message) = switch (_outcome) {
      _Outcome.checking => (
        Icons.hourglass_top_rounded,
        AppColors.gold,
        'Confirming with Paystack…',
        'This takes a few seconds. Please keep this screen open.',
      ),
      _Outcome.done => (
        Icons.check_circle_rounded,
        AppColors.success,
        'Payment received',
        p?.purpose == DepositPurpose.loanRepayment
            ? '${amount.asNaira} has been applied to your loan.'
            : '${amount.asNaira} has been added to your wallet.',
      ),
      _Outcome.waiting => (
        Icons.schedule_rounded,
        AppColors.gold,
        'Still being processed',
        'Paystack has not confirmed it yet. Bank transfers can take a few '
            'minutes. Your wallet updates by itself when it does, and we will '
            'notify you.',
      ),
      _Outcome.failed => (
        Icons.cancel_rounded,
        AppColors.danger,
        'The payment did not go through',
        _error ?? 'Nothing was taken. You can try again.',
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your payment'),
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: _outcome == _Outcome.checking
                    ? SizedBox(
                        width: 64,
                        height: 64,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(AppColors.gold),
                        ),
                      )
                    : IconBadge(icon: icon, color: color, size: 72),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (_outcome == _Outcome.done) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  amount.asNaira,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textSecondary),
              ),
              if (p != null) ...[
                const SizedBox(height: AppSpacing.xl),
                KCard(
                  child: Column(
                    children: [
                      _Line('Reference', p.reference),
                      _Line('For', p.purposeLabel.isEmpty
                          ? (p.purpose == DepositPurpose.loanRepayment ? 'Loan repayment' : 'Wallet')
                          : p.purposeLabel),
                      if (p.paidWith.isNotEmpty) _Line('Paid with', p.paidWith),
                      _Line('Started', p.createdAt.asDayTime),
                      if (p.paidAt != null) _Line('Paid', p.paidAt!.asDayTime),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              GoldButton(
                label: _outcome == _Outcome.checking ? 'Please wait' : 'Done',
                onPressed: _outcome == _Outcome.checking
                    ? null
                    : () => Navigator.of(context).pop(),
              ),
              if (_outcome == _Outcome.waiting) ...[
                const SizedBox(height: AppSpacing.md),
                GhostButton(
                  label: 'Check again',
                  onPressed: () {
                    setState(() => _outcome = _Outcome.checking);
                    unawaited(_ask(_polls));
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary)),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
