import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/primitives.dart';
import '../shell/home_shell.dart';
import 'pay_in_screen.dart';
import 'transaction_list.dart';
import 'transfer_screen.dart';
import 'withdraw_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  TxFilter _filter = TxFilter.all;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final txns = app.transactions.where(_filter.matches).toList();
    final grouped = _groupByDay(txns);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(
            child: TabHeader(title: 'Wallet', subtitle: 'Every naira, accounted for'),
          ),
          SliverToBoxAdapter(child: _BalanceStrip(app: app)),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                itemCount: TxFilter.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (_, i) {
                  final f = TxFilter.values[i];
                  final on = _filter == f;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on ? AppColors.goldWash : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: on ? AppColors.gold : AppColors.stroke,
                        ),
                      ),
                      child: Text(
                        f.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: on ? AppColors.gold : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),

          if (txns.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Nothing to show',
                message: 'Transactions matching this filter will appear here.',
              ),
            )
          else
            SliverList.builder(
              itemCount: grouped.length,
              itemBuilder: (_, i) {
                final (label, items) = grouped[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                      KCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.xs,
                        ),
                        child: Column(
                          children: [
                            for (var j = 0; j < items.length; j++) ...[
                              if (j > 0) const HairLine(indent: 52),
                              TransactionRow(
                                tx: items[j],
                                hidden: app.hideBalance,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: (40 * i).ms).fadeIn().slideY(begin: 0.08);
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.huge)),
        ],
      ),
    );
  }

  List<(String, List<Transaction>)> _groupByDay(List<Transaction> txns) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final map = <String, List<Transaction>>{};

    for (final tx in txns) {
      final d = DateTime(tx.date.year, tx.date.month, tx.date.day);
      final diff = today.difference(d).inDays;
      final label = switch (diff) {
        0 => 'TODAY',
        1 => 'YESTERDAY',
        _ => tx.date.asDay.toUpperCase(),
      };
      map.putIfAbsent(label, () => []).add(tx);
    }
    return map.entries.map((e) => (e.key, e.value)).toList();
  }
}

class _BalanceStrip extends StatelessWidget {
  const _BalanceStrip({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    child: KCard(
      gradient: AppColors.cardGradient,
      borderColor: AppColors.gold.withValues(alpha: 0.2),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Text(
            'Available balance',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 5),
          Text(
            app.hideBalance ? '••••••' : app.balance.asNaira,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: _Action(
                  icon: Icons.add_rounded,
                  label: 'Add',
                  onTap: () => Navigator.of(
                    context,
                  ).push(slideRoute(const PayInScreen())),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Action(
                  icon: Icons.send_rounded,
                  label: 'Send',
                  onTap: () => Navigator.of(
                    context,
                  ).push(slideRoute(const TransferScreen())),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Action(
                  icon: Icons.north_east_rounded,
                  label: 'Withdraw',
                  onTap: () => Navigator.of(
                    context,
                  ).push(slideRoute(const WithdrawScreen())),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ).animate().fadeIn().slideY(begin: 0.1);
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        children: [
          Icon(icon, size: 19, color: AppColors.gold),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}
