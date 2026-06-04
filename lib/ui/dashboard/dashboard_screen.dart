import 'package:flutter/material.dart';

import '../../db/database_helper.dart';
import '../../models/legal_case.dart';
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
  _DashboardCaseFilter _selectedCaseFilter = _DashboardCaseFilter.open;

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
    final allCases = await _db.getCases();
    final caseFinanceRows = await _db.getCasesWithClient();
    return _DashboardData(
      totals: totals,
      counters: counters,
      upcoming: agenda.take(6).toList(),
      allCases: allCases,
      caseFinanceRows: caseFinanceRows,
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
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: caseId)));
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
                subtitle: 'إجمالي الأتعاب والمسدد والمتبقي عبر جميع القضايا',
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
                title: 'إحصائيات تصنيفات القضايا',
                subtitle: 'إجمالي القضايا مقابل القضايا المفتوحة لكل تصنيف',
              ),
              _caseCategoryStats(d),
              SectionHeader(
                title: _selectedCaseFilter.title,
                subtitle:
                    'انقر على صف القضية لعرض التفاصيل أو كشف حساب الموكّل',
              ),
              _filteredCaseFinanceSection(d),
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
        onTap: () {
          setState(() {
            _selectedCaseFilter = _DashboardCaseFilter.open;
          });
        },
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
      child: Wrap(spacing: 12, runSpacing: 12, children: tiles),
    );
  }

  Widget _caseCategoryStats(_DashboardData d) {
    final civilTotal = d.allCases
        .where((c) => c.caseType == CaseType.civil)
        .length;
    final civilActive = d.allCases
        .where(
          (c) =>
              c.caseType == CaseType.civil && c.status == LegalCase.statusOpen,
        )
        .length;

    final criminalTotal = d.allCases
        .where((c) => c.caseType == CaseType.criminal)
        .length;
    final criminalActive = d.allCases
        .where(
          (c) =>
              c.caseType == CaseType.criminal &&
              c.status == LegalCase.statusOpen,
        )
        .length;

    final familyTotal = d.allCases
        .where((c) => c.caseType == CaseType.family)
        .length;
    final familyActive = d.allCases
        .where(
          (c) =>
              c.caseType == CaseType.family && c.status == LegalCase.statusOpen,
        )
        .length;

    final cards = [
      _CaseCategoryCard(
        title: CaseType.civil.nameAr,
        accentColor: Colors.blue,
        total: civilTotal,
        active: civilActive,
        onTap: () {
          setState(() {
            _selectedCaseFilter = _DashboardCaseFilter.civil;
          });
        },
      ),
      _CaseCategoryCard(
        title: CaseType.criminal.nameAr,
        accentColor: Colors.red,
        total: criminalTotal,
        active: criminalActive,
        onTap: () {
          setState(() {
            _selectedCaseFilter = _DashboardCaseFilter.criminal;
          });
        },
      ),
      _CaseCategoryCard(
        title: CaseType.family.nameAr,
        accentColor: Colors.teal,
        total: familyTotal,
        active: familyActive,
        onTap: () {
          setState(() {
            _selectedCaseFilter = _DashboardCaseFilter.family;
          });
        },
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth >= 1024
              ? (constraints.maxWidth - 24) / 3
              : constraints.maxWidth >= 700
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards
                .map((card) => SizedBox(width: cardWidth, child: card))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _filteredCaseFinanceSection(_DashboardData d) {
    final rows = _selectedCaseFilter.filterRows(d.caseFinanceRows);

    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            'لا توجد قضايا مطابقة للتصفية المحددة',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    if (AppBreakpoints.isMobile(context)) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: rows.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _DashboardFinanceCaseCard(
          row: rows[i],
          onOpenClient: () => _openClientFinance(rows[i]),
          onOpenCase: () => _openCaseFromFinance(rows[i]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.sizeOf(context).width - 48,
            ),
            child: DataTable(
              showCheckboxColumn: false,
              columnSpacing: 22,
              dataRowMaxHeight: 64,
              columns: const [
                DataColumn(label: Text('الموكّل')),
                DataColumn(label: Text('رقم القضية')),
                DataColumn(label: Text('العنوان')),
                DataColumn(label: Text('الحالة')),
                DataColumn(label: Text('الأتعاب'), numeric: true),
                DataColumn(label: Text('المسدد'), numeric: true),
                DataColumn(label: Text('المتبقي'), numeric: true),
                DataColumn(label: Text('إجراءات')),
              ],
              rows: rows.map((r) => _dashboardTableRow(r)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _dashboardTableRow(Map<String, dynamic> r) {
    final fees = (r['fees'] as num?)?.toDouble() ?? 0;
    final paid = (r['paid'] as num?)?.toDouble() ?? 0;
    final outstanding = (fees - paid).clamp(0, double.infinity);
    final clientName = (r['client_name'] ?? '') as String;

    return DataRow(
      onSelectChanged: (_) => _openClientFinance(r),
      cells: [
        DataCell(
          Text(
            clientName,
            style: const TextStyle(
              decoration: TextDecoration.underline,
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          onTap: () => _openClientFinance(r),
        ),
        DataCell(
          Text(
            (r['case_number'] ?? '') as String,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          onTap: () => _openCaseFromFinance(r),
        ),
        DataCell(
          SizedBox(
            width: 220,
            child: Text(
              (r['title'] ?? '') as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          onTap: () => _openCaseFromFinance(r),
        ),
        DataCell(StatusChip((r['status'] ?? '') as String)),
        DataCell(Text(formatMoney(fees))),
        DataCell(
          Text(
            formatMoney(paid),
            style: const TextStyle(color: AppColors.success),
          ),
        ),
        DataCell(
          Text(
            formatMoney(outstanding.toDouble()),
            style: TextStyle(
              color: outstanding > 0 ? AppColors.danger : AppColors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'تفاصيل القضية',
                icon: const Icon(Icons.gavel_rounded, color: AppColors.navy),
                onPressed: () => _openCaseFromFinance(r),
              ),
              IconButton(
                tooltip: 'كشف حساب الموكّل',
                icon: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.gold,
                ),
                onPressed: () => _openClientFinance(r),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openClientFinance(Map<String, dynamic> r) async {
    final clientId = (r['client_id'] ?? 0) as int;
    if (clientId == 0) return;
    _go(AppShellTab.finance);
  }

  Future<void> _openCaseFromFinance(Map<String, dynamic> r) async {
    final caseId = (r['id'] ?? 0) as int;
    if (caseId == 0) return;
    await _openCase(caseId);
  }

  Widget _upcomingList(_DashboardData d) {
    if (d.upcoming.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(
              Icons.event_available_rounded,
              color: AppColors.gold,
            ),
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
          separatorBuilder: (context, index) => const Divider(height: 1),
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
                  const Icon(Icons.chevron_left_rounded, color: Colors.black38),
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
  final List<LegalCase> allCases;
  final List<Map<String, dynamic>> caseFinanceRows;
  _DashboardData({
    required this.totals,
    required this.counters,
    required this.upcoming,
    required this.allCases,
    required this.caseFinanceRows,
  });
}

enum _DashboardCaseFilter {
  open('الوضع المالي لكل قضية'),
  civil('الوضع المالي (مدني)'),
  criminal('الوضع المالي (جنائي)'),
  family('الوضع المالي (أحوال شخصية)');

  const _DashboardCaseFilter(this.title);
  final String title;

  List<Map<String, dynamic>> filterRows(List<Map<String, dynamic>> rows) {
    return rows.where((row) {
      final status = (row['status'] ?? '') as String;
      final rawType = row['case_type'];
      final caseType = rawType is String ? rawType : '';
      switch (this) {
        case _DashboardCaseFilter.open:
          return status == LegalCase.statusOpen;
        case _DashboardCaseFilter.civil:
          return caseType == CaseType.civil.name;
        case _DashboardCaseFilter.criminal:
          return caseType == CaseType.criminal.name;
        case _DashboardCaseFilter.family:
          return caseType == CaseType.family.name;
      }
    }).toList();
  }
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
                const Icon(Icons.chevron_left_rounded, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaseCategoryCard extends StatelessWidget {
  final String title;
  final int total;
  final int active;
  final Color accentColor;
  final VoidCallback? onTap;

  const _CaseCategoryCard({
    required this.title,
    required this.total,
    required this.active,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCell(
                      label: 'إجمالي القضايا',
                      value: '$total',
                    ),
                  ),
                  Container(width: 1, height: 40, color: AppColors.divider),
                  Expanded(
                    child: _MetricCell(
                      label: 'القضايا المفتوحة',
                      value: '$active',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _DashboardFinanceCaseCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onOpenClient;
  final VoidCallback onOpenCase;

  const _DashboardFinanceCaseCard({
    required this.row,
    required this.onOpenClient,
    required this.onOpenCase,
  });

  @override
  Widget build(BuildContext context) {
    final fees = (row['fees'] as num?)?.toDouble() ?? 0;
    final paid = (row['paid'] as num?)?.toDouble() ?? 0;
    final outstanding = (fees - paid).clamp(0, double.infinity);
    final clientName = (row['client_name'] ?? '') as String;
    final caseNumber = (row['case_number'] ?? '') as String;
    final title = (row['title'] ?? '') as String;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpenClient,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      clientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  StatusChip((row['status'] ?? '') as String),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$caseNumber • $title',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _amountChip('الأتعاب', fees, AppColors.navy)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _amountChip('المسدد', paid, AppColors.success),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _amountChip(
                      'المتبقي',
                      outstanding.toDouble(),
                      outstanding > 0 ? AppColors.danger : AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onOpenCase,
                    icon: const Icon(Icons.gavel_rounded, size: 20),
                    label: const Text('القضية'),
                  ),
                  TextButton.icon(
                    onPressed: onOpenClient,
                    icon: const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 20,
                    ),
                    label: const Text('كشف الحساب'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountChip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 2),
          Text(
            formatMoney(value),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 13,
            ),
          ),
        ],
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
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.black38,
                  size: 18,
                ),
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
