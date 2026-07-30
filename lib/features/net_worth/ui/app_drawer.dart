import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';
import '../../../core/format.dart';
import '../../../core/theme_controller.dart';
import '../data/budget_repository.dart';
import '../models/account.dart';
import '../models/month_summary.dart';
import '../models/monthly_entry.dart';
import 'placeholder_screen.dart';
import 'settings_screen.dart';

/// Side drawer for secondary, lower-frequency destinations that don't belong
/// on the bottom nav (Home/Dashboard/Accounts already own that). Opened from
/// Home's app bar.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.repository, required this.themeController});

  final BudgetRepository repository;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Drawer(
      backgroundColor: palette.surface,
      width: 300,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DrawerHeader(repository: repository),
              _DrawerRow(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(themeController: themeController),
                    ),
                  );
                },
              ),
              _DrawerRow(
                icon: Icons.file_download_outlined,
                label: 'Export / Backup',
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PlaceholderScreen(
                        headerTitle: 'Export / Backup',
                        icon: Icons.file_download_outlined,
                        heading: 'Export & backup',
                        message: 'Download your data as a file, or back it up to the '
                            'cloud. Coming soon.',
                        trailing: _DisabledButton('Export data'),
                      ),
                    ),
                  );
                },
              ),
              _DrawerRow(
                icon: Icons.help_outline,
                label: 'Help / About',
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PlaceholderScreen(
                        headerTitle: 'Help & About',
                        icon: Icons.help_outline,
                        heading: 'Net Worth Tracker',
                        subtitle: 'Version 1.0.0',
                        message: 'Track assets, liabilities and savings across all your '
                            'accounts, month over month.',
                      ),
                    ),
                  );
                },
              ),
              const Spacer(),
              Container(height: 1, color: palette.border),
              _DrawerRow(
                icon: Icons.logout,
                label: 'Sign out',
                trailing: 'Soon',
                disabled: true,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerRow extends StatelessWidget {
  const _DrawerRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.disabled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = disabled ? palette.muted : palette.heading;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: InkWell(
        onTap: disabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: uiFont,
                    color: color,
                  ),
                ),
              ),
              if (trailing != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trailing!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: uiFont,
                      color: palette.muted,
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

class _DisabledButton extends StatelessWidget {
  const _DisabledButton(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: uiFont,
          color: palette.muted,
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.repository});

  final BudgetRepository repository;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.border))),
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
            'Net savings',
            style: TextStyle(fontSize: 12, fontFamily: uiFont, color: palette.muted),
          ),
          StreamBuilder<List<Account>>(
            stream: repository.watchAccounts(),
            builder: (context, accountsSnap) {
              return StreamBuilder<List<MonthlyEntry>>(
                stream: repository.watchMonthlyEntries(),
                builder: (context, entriesSnap) {
                  final style = TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFamily: monoFont,
                    color: AppPalette.blueDeep,
                  );
                  if (!accountsSnap.hasData || !entriesSnap.hasData) {
                    return Text('…', style: style);
                  }
                  final entries = entriesSnap.data!;
                  if (entries.isEmpty) {
                    return Text(currencyFormat.format(0), style: style);
                  }
                  final summaries = computeMonthSummaries(
                    entries: entries,
                    accounts: accountsSnap.data!,
                  );
                  final latest = summaries.last;
                  return Text(currencyFormat.format(latest.netSavings), style: style);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
