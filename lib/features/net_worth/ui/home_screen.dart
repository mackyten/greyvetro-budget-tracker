import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/design_tokens.dart';
import '../../../core/format.dart';
import '../../../core/theme_controller.dart';
import '../data/budget_repository.dart';
import '../data/home_widget_sync.dart';
import '../data/net_worth_preferences.dart';
import '../data/reminder_scheduler.dart';
import '../models/account.dart';
import '../models/month_summary.dart';
import '../models/monthly_entry.dart';
import 'app_drawer.dart';
import 'ghost_icon_button.dart';
import 'manage_accounts_screen.dart';
import 'milestone_celebration_dialog.dart';
import 'month_detail_screen.dart';
import 'month_row_tile.dart';
import 'net_worth_trends_section.dart';
import 'snapshots_screen.dart';

/// App root (behind `PinGate`): a single scrollable screen combining the
/// net-worth hero card, Accounts/Snapshots nav cards, the Trends section,
/// and a "Recent snapshots" preview. Replaces the old 3-tab bottom-nav shell
/// (`AppShell`) — the current design has no bottom nav at all; Accounts and
/// Snapshots are pushed sub-screens reached via the nav cards, and secondary
/// destinations (Settings/Export/Help/Vault) live in the drawer.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.authService,
    required this.themeController,
  });

  final BudgetRepository repository;
  final AuthService authService;
  final ThemeController themeController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<List<MonthlyEntry>>? _launchCheckSub;

  @override
  void initState() {
    super.initState();
    // Runs once, after the first snapshot of entries is available. Shared by
    // the reminder, milestone-celebration, and home-widget-sync launch
    // checks rather than each adding its own separate listener (previously
    // owned by AppShell, moved here now that it's the app root).
    _launchCheckSub = widget.repository.watchMonthlyEntries().listen((entries) {
      _launchCheckSub?.cancel();
      _runLaunchChecks(entries);
    });
  }

  Future<void> _runLaunchChecks(List<MonthlyEntry> entries) async {
    await ReminderScheduler.instance.scheduleMonthEndReminder(entries);

    final accounts = await widget.repository.watchAccounts().first;
    final summaries = computeMonthSummaries(entries: entries, accounts: accounts);
    if (summaries.isEmpty) return;

    await _checkMilestones(summaries);
    await updateHomeWidget(summaries.last);
  }

  Future<void> _checkMilestones(List<MonthSummary> summaries) async {
    final latestNetSavings = summaries.last.netSavings;
    final targets = await NetWorthPreferences.instance.getTargets();
    targets.sort();
    final celebrated = await NetWorthPreferences.instance.getCelebratedTargets();

    for (final target in targets) {
      if (celebrated.contains(target) || latestNetSavings < target) continue;
      if (!mounted) return;
      await showMilestoneCelebrationDialog(context, target);
      await NetWorthPreferences.instance.markCelebrated(target);
    }
  }

  @override
  void dispose() {
    _launchCheckSub?.cancel();
    super.dispose();
  }

  void _openEntry(
    BuildContext context,
    MonthSummary summary,
    List<MonthlyEntry> entries,
    List<Account> accounts,
  ) {
    final previous = entries
        .where((e) => e.month.isBefore(summary.entry.month))
        .fold<MonthlyEntry?>(
          null,
          (prev, e) => prev == null || e.month.isAfter(prev.month) ? e : prev,
        );
    showMonthDetailSheet(
      context,
      repository: widget.repository,
      entry: summary.entry,
      accounts: accounts,
      previous: previous,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      endDrawer: AppDrawer(
        repository: widget.repository,
        authService: widget.authService,
        themeController: widget.themeController,
      ),
      body: Builder(
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1, right: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.asset(
                          'assets/branding/app_mark.png',
                          width: 36,
                          height: 36,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Net Worth Tracker',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              fontFamily: uiFont,
                              color: palette.heading,
                            ),
                          ),
                          Text(
                            'Liquidity across all accounts',
                            style: TextStyle(fontSize: 12, fontFamily: uiFont, color: palette.muted),
                          ),
                        ],
                      ),
                    ),
                    GhostIconButton(
                      icon: Icons.menu,
                      onPressed: () => Scaffold.of(context).openEndDrawer(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: StreamBuilder<List<Account>>(
                    stream: widget.repository.watchAccounts(),
                    builder: (context, accountsSnap) {
                      if (!accountsSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final accounts = accountsSnap.data!;
                      return StreamBuilder<List<MonthlyEntry>>(
                        stream: widget.repository.watchMonthlyEntries(),
                        builder: (context, entriesSnap) {
                          if (!entriesSnap.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final entries = entriesSnap.data!;
                          final summaries = computeMonthSummaries(entries: entries, accounts: accounts);
                          final recent = summaries.reversed.take(5).toList();

                          return ListView(
                            padding: const EdgeInsets.only(bottom: 24),
                            children: [
                              _HeroNetWorthCard(summaries: summaries),
                              const SizedBox(height: 14),
                              _NavCardRow(
                                activeAccountsCount: accounts.where((a) => a.active).length,
                                snapshotsCount: entries.length,
                                onOpenAccounts: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ManageAccountsScreen(repository: widget.repository),
                                  ),
                                ),
                                onOpenSnapshots: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SnapshotsScreen(repository: widget.repository),
                                  ),
                                ),
                              ),
                              const _SectionLabel('Trends'),
                              NetWorthTrendsSection(accounts: accounts, entries: entries),
                              Padding(
                                padding: const EdgeInsets.only(top: 18, bottom: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'RECENT SNAPSHOTS',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        fontFamily: uiFont,
                                        color: AppPalette.blueDeep,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => SnapshotsScreen(repository: widget.repository),
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppPalette.blueDeep,
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 0),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'See all',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (recent.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'No months tracked yet.',
                                    style: TextStyle(fontFamily: uiFont, color: palette.muted),
                                  ),
                                )
                              else
                                for (final summary in recent)
                                  MonthRowTile(
                                    summary: summary,
                                    onTap: () => _openEntry(context, summary, entries, accounts),
                                  ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          fontFamily: uiFont,
          color: AppPalette.blueDeep,
        ),
      ),
    );
  }
}

/// Gradient net-worth summary card: latest month's totals plus an optional
/// vs.-last-month delta pill. Uses [MonthSummary.currentMonthSaved] /
/// [MonthSummary.momChangePct] directly rather than re-diffing, since those
/// are already computed against the immediately preceding month.
class _HeroNetWorthCard extends StatefulWidget {
  const _HeroNetWorthCard({required this.summaries});

  final List<MonthSummary> summaries;

  @override
  State<_HeroNetWorthCard> createState() => _HeroNetWorthCardState();
}

class _HeroNetWorthCardState extends State<_HeroNetWorthCard> {
  /// Off by default — balances are shown in the clear until the user
  /// explicitly taps the eye toggle to mask them for privacy.
  bool _hidden = false;

  static const _maskedAmount = '₱ ********';

  String _amount(double value) => _hidden ? _maskedAmount : currencyFormat.format(value);

  @override
  Widget build(BuildContext context) {
    final summaries = widget.summaries;
    final latest = summaries.isEmpty ? null : summaries.last;
    final netWorth = latest?.netSavings ?? 0.0;
    final assets = latest?.totalAssets ?? 0.0;
    final reserved = latest?.totalReservedLiabilities ?? 0.0;
    final delta = latest?.currentMonthSaved;
    final pct = latest?.momChangePct;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppPalette.fabGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppPalette.blueDeep.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NET WORTH',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  fontFamily: uiFont,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _hidden = !_hidden),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    _hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _amount(netWorth),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              fontFamily: monoFont,
              color: Colors.white,
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${delta >= 0 ? '↑ +' : '↓ '}${currencyFormat.format(delta.abs())}'
                '${pct != null ? '  (${pct >= 0 ? '+' : ''}${percentFormat.format(pct)})' : ''}'
                ' vs last month',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  fontFamily: monoFont,
                  color: Colors.white,
                ),
              ),
            ),
          ],
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.25))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assets',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: uiFont,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _amount(assets),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          fontFamily: monoFont,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.25)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reserved & Liabilities',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: uiFont,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _amount(reserved),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          fontFamily: monoFont,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavCardRow extends StatelessWidget {
  const _NavCardRow({
    required this.activeAccountsCount,
    required this.snapshotsCount,
    required this.onOpenAccounts,
    required this.onOpenSnapshots,
  });

  final int activeAccountsCount;
  final int snapshotsCount;
  final VoidCallback onOpenAccounts;
  final VoidCallback onOpenSnapshots;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _NavCard(
            icon: Icons.account_balance_outlined,
            title: 'Accounts',
            subtitle: '$activeAccountsCount active account${activeAccountsCount == 1 ? '' : 's'}',
            onTap: onOpenAccounts,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _NavCard(
            icon: Icons.dashboard_outlined,
            title: 'Snapshots',
            subtitle: '$snapshotsCount snapshot${snapshotsCount == 1 ? '' : 's'} recorded',
            onTap: onOpenSnapshots,
          ),
        ),
      ],
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppPalette.blueDeep.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 18, color: AppPalette.blueDeep),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: uiFont,
                    color: palette.heading,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontFamily: uiFont, color: palette.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
