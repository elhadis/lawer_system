import 'package:flutter/material.dart';

import '../../db/database_helper.dart';
import '../../theme/app_theme.dart';
import '../app_shell.dart';
import '../cases/case_detail_screen.dart';
import '../common/money.dart';
import '../common/responsive.dart';
import '../common/section_header.dart';
import '../common/status_chip.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = DatabaseHelper.instance;
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final totals = await _db.getFinanceTotals();
    final counters = await _db.getCounters();
    final agenda = await _db.getAgenda(
      from: DateTime.now().subtract(const Duration(days: 1)),
    );
    return _DashboardData(
      totals: totals,
      counters: counters,
      upcoming: agenda.take(6).toList(),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  void _go(int tab) => AppShell.goTo(context, tab);

  Future<void> _openCase(int caseId) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CaseDetailScreen(caseId: caseId),
    ));
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data!;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              SectionHeader(
                title: 'الملخّص المالي',
                subtitle:
                    'إجمالي الأتعاب والمسدد والمتبقي عبر جميع القضايا',
                actions: [
                  TextButton.icon(
                    onPressed: () => _go(AppShellTab.finance),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('عرض الكل'),
                  ),
                ],
              ),
              _financeRow(d),
              SectionHeader(
                title: 'مؤشرات سريعة',
                subtitle: 'انقر على أي بطاقة للوصول إلى الوحدة المرتبطة',
              ),
              _countersRow(d),
              SectionHeader(
                title: 'الجلسات القادمة',
                subtitle: 'أقرب الجلسات في الأجندة',
                actions: [
                  TextButton.icon(
                    onPressed: () => _go(AppShellTab.agenda),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('فتح الأجندة'),
                  ),
                ],
              ),
              _upcomingList(d),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _financeRow(_DashboardData d) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final wide = c.maxWidth >= AppBreakpoints.mobile;
        final cards = [
          _StatCard(
            label: 'إجمالي الأتعاب',
            value: '${formatMoney(d.totals['fees'] ?? 0)} ر.س',
            color: AppColors.navy,
            icon: Icons.account_balance,
            onTap: () => _go(AppShellTab.finance),
          ),
          _StatCard(
            label: 'إجمالي المسدد',
            value: '${formatMoney(d.totals['paid'] ?? 0)} ر.س',
            color: AppColors.success,
            icon: Icons.payments_rounded,
            onTap: () => _go(AppShellTab.finance),
          ),
          _StatCard(
            label: 'إجمالي المتبقي',
            value: '${formatMoney(d.totals['outstanding'] ?? 0)} ر.س',
            color: AppColors.danger,
            icon: Icons.warning_amber_rounded,
            onTap: () => _go(AppShellTab.finance),
          ),
        ];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: wide
              ? Row(
                  children: cards
                      .map((w) => Expanded(child: w))
                      .toList(growable: false),
                )
              : Column(children: cards),
        );
      },
    );
  }

  Widget _countersRow(_DashboardData d) {
    final tiles = [
      _MiniTile(
        label: 'الموكّلون',
        value: '${d.counters['clients'] ?? 0}',
        icon: Icons.people_alt_rounded,
        onTap: () => _go(AppShellTab.clients),
        hint: 'فتح قائمة الموكّلين',
      ),
      _MiniTile(
        label: 'القضايا',
        value: '${d.counters['cases'] ?? 0}',
        icon: Icons.folder_open_rounded,
        onTap: () => _go(AppShellTab.finance),
        hint: 'عرض القضايا في وحدة الحسابات',
      ),
      _MiniTile(
        label: 'القضايا النشطة',
        value: '${d.counters['openCases'] ?? 0}',
        icon: Icons.gavel_rounded,
        onTap: () => _go(AppShellTab.finance),
        hint: 'متابعة القضايا غير المغلقة',
      ),
      _MiniTile(
        label: 'جلسات قادمة',
        value: '${d.counters['upcoming'] ?? 0}',
        icon: Icons.event_rounded,
        onTap: () => _go(AppShellTab.agenda),
        hint: 'فتح أجندة المحكمة',
      ),
      _MiniTile(
        label: 'العقود',
        value: '${d.counters['contracts'] ?? 0}',
        icon: Icons.description_rounded,
        onTap: () => _go(AppShellTab.contracts),
        hint: 'إدارة وصياغة العقود',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: tiles,
      ),
    );
  }

  Widget _upcomingList(_DashboardData d) {
    if (d.upcoming.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.event_available_rounded,
                color: AppColors.gold),
            title: const Text('لا توجد جلسات قادمة'),
            subtitle: const Text('فتح الأجندة لإضافة أو متابعة الجلسات.'),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => _go(AppShellTab.agenda),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: d.upcoming.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final r = d.upcoming[i];
            final caseId = (r['case_id'] ?? 0) as int;
            return ListTile(
              onTap: caseId == 0 ? null : () => _openCase(caseId),
              leading: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calendar_month, color: AppColors.navy),
              ),
              title: Text('${r['case_number']} • ${r['case_title']}'),
              subtitle: Text(
                '${r['client_name']} • ${formatDate(r['session_date'] as String? ?? '')}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusChip((r['status'] ?? '') as String),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_left_rounded,
                      color: Colors.black38),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardData {
  final Map<String, double> totals;
  final Map<String, int> counters;
  final List<Map<String, dynamic>> upcoming;
  _DashboardData({
    required this.totals,
    required this.counters,
    required this.upcoming,
  });
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_left_rounded,
                    color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final IconData icon;
  final VoidCallback? onTap;
  const _MiniTile({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54)),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_left_rounded,
                    color: Colors.black38, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: AppColors.navy,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return tile;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: tile,
      ),
    );
  }
}
