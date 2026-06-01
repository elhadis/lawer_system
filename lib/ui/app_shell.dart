import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'app_security_gate.dart';
import 'common/responsive.dart';
import 'dashboard/dashboard_screen.dart';
import 'clients/clients_screen.dart';
import 'agenda/agenda_screen.dart';
import 'finance/finance_screen.dart';
import 'contracts/contracts_screen.dart';
import 'settings/settings_screen.dart';

/// Logical index for the [AppShell] modules. Use with [AppShellState.goTo]
/// to jump between modules from anywhere inside the shell.
class AppShellTab {
  static const int dashboard = 0;
  static const int clients = 1;
  static const int agenda = 2;
  static const int finance = 3;
  static const int contracts = 4;
  static const int settings = 5;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static void goTo(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<AppShellState>();
    state?.goTo(index);
  }

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _index = 0;
  bool _tabletSidebarOpen = true;

  void goTo(int index) {
    if (!mounted) return;
    setState(() => _index = index);
  }

  static const _items = <_NavItem>[
    _NavItem('لوحة التحكم', Icons.dashboard_rounded),
    _NavItem('الموكّلون', Icons.people_alt_rounded),
    _NavItem('أجندة المحكمة', Icons.event_available_rounded),
    _NavItem('الحسابات', Icons.account_balance_wallet_rounded),
    _NavItem('صياغة العقود', Icons.description_rounded),
    _NavItem('إعدادات المكتب', Icons.business_rounded),
  ];

  Widget _buildBody() {
    switch (_index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const ClientsScreen();
      case 2:
        return const AgendaScreen();
      case 3:
        return const FinanceScreen();
      case 4:
        return const ContractsScreen();
      case 5:
        return const SettingsScreen();
    }
    return const DashboardScreen();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= AppBreakpoints.tablet) {
          return _buildDesktopShell(context);
        }
        if (width >= AppBreakpoints.mobile) {
          return _buildTabletShell(context);
        }
        return _buildMobileShell(context);
      },
    );
  }

  /// Windows desktop (> 1000px): fixed sidebar + content (unchanged wide layout).
  Widget _buildDesktopShell(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: 260, child: _buildSidePanel(context, compact: false)),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Column(
              children: [
                _moduleAppBar(context),
                Expanded(
                  child: SafeArea(top: false, child: _buildBody()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tablet (600–1000px): collapsible sidebar for landscape-friendly hybrid UI.
  Widget _buildTabletShell(BuildContext context) {
    return Scaffold(
      appBar: _moduleAppBar(
        context,
        leading: IconButton(
          icon: Icon(
            _tabletSidebarOpen
                ? Icons.menu_open_rounded
                : Icons.menu_rounded,
          ),
          tooltip: _tabletSidebarOpen ? 'إخفاء القائمة' : 'إظهار القائمة',
          onPressed: () =>
              setState(() => _tabletSidebarOpen = !_tabletSidebarOpen),
        ),
      ),
      drawer: _buildDrawer(),
      body: Row(
        children: [
          if (_tabletSidebarOpen)
            SizedBox(
              width: 220,
              child: _buildSidePanel(context, compact: true),
            ),
          if (_tabletSidebarOpen)
            const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: SafeArea(child: _buildBody())),
        ],
      ),
    );
  }

  /// Phone (< 600px): AppBar + drawer; no persistent sidebar.
  Widget _buildMobileShell(BuildContext context) {
    return Scaffold(
      appBar: _moduleAppBar(
        context,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'القائمة',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      drawer: _buildDrawer(),
      body: SafeArea(child: _buildBody()),
    );
  }

  PreferredSizeWidget _moduleAppBar(
    BuildContext context, {
    Widget? leading,
  }) {
    return AppBar(
      leading: leading,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          const Icon(Icons.gavel, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _items[_index].label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(child: _buildSidePanel(context, compact: false));
  }

  Widget _buildSidePanel(BuildContext context, {required bool compact}) {
    return ColoredBox(
      color: AppColors.navyDark,
      child: Column(
        children: [
          _buildDrawerHeader(compact: compact),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final item = _items[i];
                final selected = i == _index;
                return _DrawerTile(
                  item: item,
                  selected: selected,
                  compact: compact,
                  onTap: () {
                    setState(() => _index = i);
                    Navigator.of(context).maybePop();
                  },
                );
              },
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8, vertical: 4),
            child: ListTile(
              dense: compact,
              minVerticalPadding: compact ? 8 : 12,
              leading: const Icon(Icons.lock_outline_rounded,
                  color: AppColors.gold),
              title: Text(
                'قفل التطبيق',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 13 : 14,
                ),
              ),
              subtitle: compact
                  ? null
                  : Text(
                      'يتطلب رمز الأمان لفتحه مجدداً',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                      ),
                    ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onTap: () {
                Navigator.of(context).maybePop();
                AppSecurityGate.lock(context);
              },
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 14,
              12,
              compact ? 10 : 14,
              14,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'images/logo.png',
                    width: compact ? 32 : 40,
                    height: compact ? 32 : 40,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'HT Digital Software Solutions',
                    textAlign: TextAlign.start,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: compact ? 10 : 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader({required bool compact}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, compact ? 24 : 32, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.navyDark,
        border: Border(
          bottom: BorderSide(color: AppColors.gold, width: 1.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: compact ? 48 : 56,
            height: compact ? 48 : 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.balance_rounded,
              color: AppColors.navy,
              size: compact ? 26 : 30,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'نظام المكتب القانوني',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 14 : 16,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 4),
            Text(
              'إدارة الموكّلين والقضايا والعقود',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem(this.label, this.icon);
}

class _DrawerTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;
  const _DrawerTile({
    required this.item,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected
            ? AppColors.gold.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: compact ? 10 : 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? const Border(
                      right: BorderSide(color: AppColors.gold, width: 3),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: selected ? AppColors.gold : Colors.white70,
                  size: compact ? 20 : 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: compact ? 13 : 14,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.chevron_left_rounded,
                      color: AppColors.gold),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
