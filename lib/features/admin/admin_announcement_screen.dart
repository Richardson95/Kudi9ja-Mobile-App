import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/api_exception.dart';
import '../../state/app_state.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';
import 'admin_lending_widgets.dart';

/// A push notification to every customer's phone, with an optional picture.
///
/// It reaches everybody at once and cannot be taken back, so it is for owners
/// and administrators, it asks twice, and every send is audited.
class AdminAnnouncementScreen extends StatefulWidget {
  const AdminAnnouncementScreen({super.key});

  @override
  State<AdminAnnouncementScreen> createState() => _AdminAnnouncementScreenState();
}

class _AdminAnnouncementScreenState extends State<AdminAnnouncementScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _image = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _image.dispose();
    super.dispose();
  }

  bool get _ready =>
      _title.text.trim().isNotEmpty &&
      _title.text.trim().length <= 65 &&
      _body.text.trim().isNotEmpty &&
      _body.text.trim().length <= 240 &&
      (_image.text.trim().isEmpty || _image.text.trim().startsWith('https://'));

  Future<void> _send() async {
    if (!await confirmAction(
      context,
      title: 'Send to every customer?',
      message: 'It goes to every registered phone at once and cannot be taken back.',
      confirm: 'Send',
      danger: true,
    )) {
      return;
    }
    if (!mounted) return;
    final admin = context.read<AppState>().adminApi;
    if (admin == null) return;
    setState(() => _busy = true);
    try {
      final devices = await admin.announce(
        title: _title.text.trim(),
        body: _body.text.trim(),
        imageUrl: _image.text.trim(),
      );
      if (!mounted) return;
      showToast(context, 'On its way to $devices phone${devices == 1 ? '' : 's'}');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send an announcement')),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Text(
                'A push notification to every customer. A phone with the app '
                'open shows the text alone; closed, it shows the picture too.',
                style: TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textTertiary),
              ),
              const SizedBox(height: AppSpacing.xl),
              KField(
                label: 'Title (${_title.text.length}/65)',
                controller: _title,
                maxLength: 65,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Message (${_body.text.length}/240)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _body,
                maxLines: 4,
                maxLength: 240,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(counterText: ''),
              ),
              const SizedBox(height: AppSpacing.md),
              KField(
                label: 'Picture link (optional)',
                hint: 'https://… a JPEG or PNG under 1 MB',
                controller: _image,
                keyboardType: TextInputType.url,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.xl),
              GoldButton(
                label: 'Send to everyone',
                icon: Icons.campaign_rounded,
                loading: _busy,
                onPressed: _ready ? _send : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
