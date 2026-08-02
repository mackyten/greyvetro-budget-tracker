import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';
import '../../../core/format.dart';
import '../../../core/theme_controller.dart';
import '../../vault/ui/vault_entry.dart';
import '../data/budget_repository.dart';
import '../models/account.dart';
import '../models/month_summary.dart';
import '../models/monthly_entry.dart';
import '../models/streak.dart';
import 'export_screen.dart';
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
                icon: Icons.shield_outlined,
                label: 'Secure Vault',
                onTap: () async {
                  Navigator.of(context).pop();
                  final accounts = await repository.watchAccounts().first;
                  if (!context.mounted) return;
                  openVault(
                    context,
                    accounts: [for (final a in accounts) (id: a.id, name: a.name)],
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
                      builder: (_) => ExportScreen(repository: repository),
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
                      builder: (routeContext) => PlaceholderScreen(
                        headerTitle: 'Help & About',
                        icon: Icons.help_outline,
                        logo: Image.asset(
                          Theme.of(routeContext).brightness == Brightness.dark
                              ? 'assets/branding/lockup_dark.png'
                              : 'assets/branding/lockup_light.png',
                          height: 40,
                        ),
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
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset('assets/branding/app_mark.png', width: 28, height: 28),
              ),
              const SizedBox(width: 9),
              Text(
                'Net Worth Tracker',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  fontFamily: uiFont,
                  color: palette.heading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<Account>>(
            stream: repository.watchAccounts(),
            builder: (context, accountsSnap) {
              return StreamBuilder<List<MonthlyEntry>>(
                stream: repository.watchMonthlyEntries(),
                builder: (context, entriesSnap) {
                  final labelStyle = TextStyle(
                    fontSize: 12,
                    fontFamily: uiFont,
                    color: palette.muted,
                  );
                  final valueStyle = TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFamily: monoFont,
                    color: AppPalette.blueDeep,
                  );
                  final entries = entriesSnap.data ?? const <MonthlyEntry>[];
                  final loading = !accountsSnap.hasData || !entriesSnap.hasData;

                  final netSavingsText = loading
                      ? '…'
                      : entries.isEmpty
                          ? currencyFormat.format(0)
                          : currencyFormat.format(
                              computeMonthSummaries(
                                entries: entries,
                                accounts: accountsSnap.data!,
                              ).last.netSavings,
                            );
                  final streak = loading ? null : computeLoggedStreak(entries);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Net savings', style: labelStyle),
                            Text(netSavingsText, style: valueStyle),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Streak', style: labelStyle),
                          Text(
                            streak == null ? '…' : '$streak mo',
                            style: valueStyle.copyWith(fontSize: 15),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
