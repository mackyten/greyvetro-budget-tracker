import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';
import '../../../core/theme_controller.dart';
import '../data/budget_repository.dart';
import '../data/home_widget_sync.dart';
import '../data/net_worth_preferences.dart';
import '../data/reminder_scheduler.dart';
import '../models/month_summary.dart';
import '../models/monthly_entry.dart';
import 'dashboard_screen.dart';
import 'manage_accounts_screen.dart';
import 'milestone_celebration_dialog.dart';
import 'month_list_screen.dart';

/// Top-level navigation shell: a persistent bottom nav bar with three
/// always-reachable destinations, each preserving its own navigation/scroll
/// state via [IndexedStack] rather than being pushed as a separate route.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.repository, required this.themeController});

  final BudgetRepository repository;
  final ThemeController themeController;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  StreamSubscription<List<MonthlyEntry>>? _launchCheckSub;

  @override
  void initState() {
    super.initState();
    // Runs once, after the first snapshot of entries is available. Shared
    // by Phase 5 (reminder), Phase 6 (milestones), and Phase 7 (home-widget
    // sync) rather than each adding a separate launch-time listener.
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

  @override
  Widget build(BuildContext context) {
    final tabs = [
      MonthListScreen(repository: widget.repository, themeController: widget.themeController),
      DashboardScreen(repository: widget.repository),
      ManageAccountsScreen(repository: widget.repository),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onChanged: (index) => setState(() => _index = index),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const _navItems = [
  _NavItem(Icons.home_outlined, Icons.home, 'Home'),
  _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
  _NavItem(Icons.account_balance_outlined, Icons.account_balance, 'Accounts'),
];

/// Flat color-only active state (icon + label switch to [AppPalette.blueDeep])
/// — deliberately no Material3 pill/indicator background behind the selected
/// item, matching the verified design.
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          child: Row(
            children: [
              for (var i = 0; i < _navItems.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            i == index ? _navItems[i].activeIcon : _navItems[i].icon,
                            size: 22,
                            color: i == index ? AppPalette.blueDeep : palette.muted,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _navItems[i].label,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              fontFamily: uiFont,
                              color: i == index ? AppPalette.blueDeep : palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
