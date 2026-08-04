import 'package:flutter/material.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/design_tokens.dart';
import '../../../core/format.dart';
import '../../../core/theme_controller.dart';
import '../../vault/ui/vault_entry.dart';
import '../data/budget_repository.dart';
import '../models/account.dart';
import '../models/month_summary.dart';
import '../models/monthly_entry.dart';
import 'design_chip.dart';

/// Which inline section of the wide main area is currently showing.
/// Dashboard, Snapshots, Accounts, Settings, Export, and Help all switch in
/// place inside the persistent sidebar shell — matching the verified
/// design's single-page `wideSection` state machine (no route push, no
/// transition). Secure Vault is the only sidebar destination that still
/// pushes a route, since it's a PIN/biometric-gated flow outside the design.
enum WideSection { dashboard, snapshots, accounts, settings, export, help }

/// Persistent left sidebar for the wide (web) layout — replaces the mobile
/// hamburger + end drawer with an always-visible nav, matching the verified
/// design's `sidebarStyle`/`navItemsWide`.
class SidebarNav extends StatelessWidget {
  const SidebarNav({
    super.key,
    required this.repository,
    required this.authService,
    required this.themeController,
    required this.selectedSection,
    required this.onSelectDashboard,
    required this.onSelectSnapshots,
    required this.onSelectAccounts,
    required this.onSelectSettings,
    required this.onSelectExport,
    required this.onSelectHelp,
  });

  final BudgetRepository repository;
  final AuthService authService;
  final ThemeController themeController;
  final WideSection selectedSection;
  final VoidCallback onSelectDashboard;
  final VoidCallback onSelectSnapshots;
  final VoidCallback onSelectAccounts;
  final VoidCallback onSelectSettings;
  final VoidCallback onSelectExport;
  final VoidCallback onSelectHelp;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(right: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SidebarBrand(repository: repository),
              const SizedBox(height: 8),
              _SidebarItem(
                icon: Icons.home_outlined,
                label: 'Dashboard',
                active: selectedSection == WideSection.dashboard,
                onTap: onSelectDashboard,
              ),
              _SidebarItem(
                icon: Icons.account_balance_outlined,
                label: 'Accounts',
                active: selectedSection == WideSection.accounts,
                onTap: onSelectAccounts,
              ),
              _SidebarItem(
                icon: Icons.dashboard_outlined,
                label: 'Snapshots',
                active: selectedSection == WideSection.snapshots,
                onTap: onSelectSnapshots,
              ),
              const SizedBox(height: 8),
              Container(height: 1, color: palette.border),
              const SizedBox(height: 8),
              _SidebarItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                active: selectedSection == WideSection.settings,
                onTap: onSelectSettings,
              ),
              _SidebarItem(
                icon: Icons.shield_outlined,
                label: 'Secure Vault',
                active: false,
                onTap: () async {
                  final accounts = await repository.watchAccounts().first;
                  if (!context.mounted) return;
                  openVault(
                    context,
                    accounts: [
                      for (final a in accounts) (id: a.id, name: a.name),
                    ],
                  );
                },
              ),
              _SidebarItem(
                icon: Icons.file_download_outlined,
                label: 'Export / Backup',
                active: selectedSection == WideSection.export,
                onTap: onSelectExport,
              ),
              _SidebarItem(
                icon: Icons.help_outline,
                label: 'Help / About',
                active: selectedSection == WideSection.help,
                onTap: onSelectHelp,
              ),
              const Spacer(),
              Container(height: 1, color: palette.border),
              const SizedBox(height: 12),
              Text(
                'APPEARANCE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  fontFamily: uiFont,
                  color: AppPalette.blueDeep,
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeController,
                builder: (context, mode, _) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    DesignChip(
                      label: 'Light',
                      active: mode == ThemeMode.light,
                      onTap: () => themeController.value = ThemeMode.light,
                    ),
                    DesignChip(
                      label: 'Dark',
                      active: mode == ThemeMode.dark,
                      onTap: () => themeController.value = ThemeMode.dark,
                    ),
                    DesignChip(
                      label: 'System',
                      active: mode == ThemeMode.system,
                      onTap: () => themeController.value = ThemeMode.system,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SidebarItem(
                icon: Icons.logout,
                label: 'Sign out',
                active: false,
                onTap: () async {
                  // AuthGate rebuilds from authStateChanges() once this
                  // completes; nothing else to do here.
                  await authService.signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: active
          ? AppPalette.blueDeep.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? AppPalette.blueDeep : palette.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                    fontFamily: uiFont,
                    color: active ? AppPalette.blueDeep : palette.text,
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

class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand({required this.repository});

  final BudgetRepository repository;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/branding/app_mark.png',
                  width: 28,
                  height: 28,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Net Worth Tracker',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    fontFamily: uiFont,
                    color: palette.heading,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Net worth',
            style: TextStyle(
              fontSize: 12,
              fontFamily: uiFont,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 2),
          StreamBuilder<List<Account>>(
            stream: repository.watchAccounts(),
            builder: (context, accountsSnap) {
              return StreamBuilder<List<MonthlyEntry>>(
                stream: repository.watchMonthlyEntries(),
                builder: (context, entriesSnap) {
                  final loading = !accountsSnap.hasData || !entriesSnap.hasData;
                  final entries = entriesSnap.data ?? const <MonthlyEntry>[];
                  final netWorthText = loading
                      ? '…'
                      : entries.isEmpty
                      ? currencyFormat.format(0)
                      : currencyFormat.format(
                          computeMonthSummaries(
                            entries: entries,
                            accounts: accountsSnap.data!,
                          ).last.netSavings,
                        );
                  return Text(
                    netWorthText,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      fontFamily: monoFont,
                      color: AppPalette.blueDeep,
                    ),
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
