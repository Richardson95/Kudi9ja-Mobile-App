import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/banks.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../state/app_state.dart';
import 'primitives.dart';

/// Choosing a bank.
///
/// The list comes from the server, and that is the whole point of this widget
/// existing. The app used to carry its own list of fourteen names, and six of
/// them — "OPay", "GTBank", "UBA", "Union Bank", "Stanbic IBTC", "Moniepoint
/// MFB" — were not what the server calls those banks. Choosing any of the six
/// produced "Choose a bank from the list" on a screen where the customer had
/// very obviously just chosen one from the list.
///
/// Two lists that have to agree, maintained in two places, will not agree. So
/// there is one list, it lives on the server beside the code that validates
/// against it, and the app asks for it.
///
/// Search exists because there are thirty-five and a customer knows the name of
/// theirs. Scrolling for Moniepoint past thirty banks they will never use is
/// work the phone should be doing.
Future<String?> pickBank(BuildContext context, {String? current}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _BankSheet(current: current),
    );

class _BankSheet extends StatefulWidget {
  const _BankSheet({this.current});
  final String? current;

  @override
  State<_BankSheet> createState() => _BankSheetState();
}

class _BankSheetState extends State<_BankSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Fetched if it has not been already. Nothing waits on it: the bundled
    // fallback is shown meanwhile, and the sheet fills in when the answer
    // arrives.
    context.read<AppState>().loadBanks();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Matches on the name a customer would type.
  ///
  /// Case-insensitive, and on any part of the name rather than only the start —
  /// somebody looking for Guaranty Trust types "GT", and somebody looking for
  /// First Bank of Nigeria may well type "first bank".
  List<String> _matching(List<String> banks) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return banks;
    return banks.where((b) => b.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final banks = app.banks.isEmpty ? kFallbackBanks : app.banks;
    final shown = _matching(banks);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (_, controller) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select your bank',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _search,
                      autofocus: false,
                      onChanged: (v) => setState(() => _query = v),
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search banks',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: AppColors.textTertiary,
                        ),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: AppColors.textTertiary,
                                ),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        filled: true,
                        fillColor: AppColors.surfaceHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const HairLine(),
              Expanded(
                child: shown.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No bank matches "$_query"',
                        message:
                            'Check the spelling, or search for part of the name.',
                      )
                    : ListView.builder(
                        controller: controller,
                        itemCount: shown.length,
                        itemBuilder: (_, i) {
                          final bank = shown[i];
                          final on = widget.current == bank;
                          return ListTile(
                            title: Text(
                              bank,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight:
                                    on ? FontWeight.w700 : FontWeight.w500,
                                color:
                                    on ? AppColors.gold : AppColors.textPrimary,
                              ),
                            ),
                            trailing: on
                                ? Icon(
                                    Icons.check_rounded,
                                    color: AppColors.gold,
                                    size: 20,
                                  )
                                : null,
                            onTap: () => Navigator.pop(context, bank),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
