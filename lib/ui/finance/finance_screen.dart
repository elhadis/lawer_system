import 'package:flutter/material.dart';

import '../../db/database_helper.dart';
import '../../models/legal_case.dart';

import '../../services/pdf_service.dart';

import '../../theme/app_theme.dart';

import '../cases/case_detail_screen.dart';

import '../common/empty_state.dart';

import '../common/money.dart';

import '../common/responsive.dart';

import '../common/section_header.dart';

import '../common/status_chip.dart';

import 'client_finance_detail.dart';

class FinanceScreen extends StatefulWidget {
  final CaseType? filterType;

  const FinanceScreen({super.key, this.filterType});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final _db = DatabaseHelper.instance;

  late Future<_FinanceData> _future;

  @override
  void initState() {
    super.initState();

    _future = _load();
  }

  Future<_FinanceData> _load() async {
    final allRows = await _db.getCasesWithClient();
    final rows = widget.filterType == null
        ? allRows
        : allRows.where((row) {
            final raw = row['case_type'];
            return raw is String && raw == widget.filterType!.name;
          }).toList();
    final totals = await _db.getFinanceTotals();

    return _FinanceData(
      rows: rows,
      totals: totals,
      filterType: widget.filterType,
    );
  }

  Future<void> _exportReport(_FinanceData data) async {
    final settings = await _db.getSettings();

    final bytes = await PdfService.instance.buildFinanceReportPdf(
      settings: settings,

      rows: data.rows,

      totals: data.totals,
    );

    await PdfService.instance.exportPdf(
      bytes,

      fileName: 'finance_report.pdf',

      jobName: 'تقرير مالي شامل',

      shareText: 'التقرير المالي الشامل للقضايا',
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mobile = AppBreakpoints.isMobile(context);

    return FutureBuilder<_FinanceData>(
      future: _future,

      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final d = snap.data!;

        return Scaffold(
          backgroundColor: Colors.transparent,

          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _exportReport(d),

            icon: Icon(
              mobile ? Icons.share_rounded : Icons.picture_as_pdf_rounded,
            ),

            label: Text(mobile ? 'مشاركة التقرير' : 'طباعة التقرير'),
          ),

          body: ListView(
            padding: const EdgeInsets.only(bottom: 90),

            children: [
              const SectionHeader(
                title: 'الإجماليات المالية',

                subtitle: 'مجموع الأتعاب والمسدد والمتبقي عبر كل القضايا',
              ),

              _totalsRow(d.totals, context),

              SectionHeader(
                title: d.filterType == null
                    ? 'الوضع المالي لكل قضية'
                    : 'الوضع المالي (${d.filterType!.nameAr})',
                subtitle: d.filterType == null
                    ? 'انقر على صف القضية لعرض سجل المدفوعات الكامل للموكّل'
                    : 'عرض القضايا المصفّاة حسب النوع المحدد',
                actions: d.filterType == null
                    ? []
                    : [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const FinanceScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.filter_alt_off_rounded),
                          label: const Text('إلغاء التصفية'),
                        ),
                      ],
              ),

              _rowsSection(d, context),
            ],
          ),
        );
      },
    );
  }

  Widget _totalsRow(Map<String, double> totals, BuildContext context) {
    final mobile = AppBreakpoints.isMobile(context);

    final cards = [
      _bigStat(
        'إجمالي الأتعاب',

        totals['fees'] ?? 0,

        AppColors.navy,

        Icons.account_balance,
      ),

      _bigStat(
        'إجمالي المسدد',

        totals['paid'] ?? 0,

        AppColors.success,

        Icons.payments_rounded,
      ),

      _bigStat(
        'إجمالي المتبقي',

        totals['outstanding'] ?? 0,

        AppColors.danger,

        Icons.warning_amber_rounded,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),

      child: mobile
          ? Column(children: cards)
          : Row(
              children: cards
                  .map((w) => Expanded(child: w))
                  .toList(growable: false),
            ),
    );
  }

  Widget _bigStat(String label, double value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                Icon(icon, color: color),

                const SizedBox(width: 8),

                Text(
                  label,

                  style: const TextStyle(
                    color: Colors.black54,

                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              '${formatMoney(value)} ر.س',

              style: TextStyle(
                fontSize: 20,

                fontWeight: FontWeight.w800,

                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowsSection(_FinanceData d, BuildContext context) {
    if (d.rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),

        child: EmptyState(
          icon: Icons.account_balance_wallet_rounded,

          title: 'لا توجد قضايا لعرض البيانات المالية',
        ),
      );
    }

    if (AppBreakpoints.isMobile(context)) {
      return _rowsAsCards(d);
    }

    return _rowsAsTable(d, context);
  }

  Widget _rowsAsCards(_FinanceData d) {
    return ListView.separated(
      shrinkWrap: true,

      physics: const NeverScrollableScrollPhysics(),

      padding: const EdgeInsets.symmetric(horizontal: 12),

      itemCount: d.rows.length,

      separatorBuilder: (_, __) => const SizedBox(height: 8),

      itemBuilder: (_, i) => _FinanceCaseCard(
        row: d.rows[i],

        onOpenClient: () => _openClient(d.rows[i]),

        onOpenCase: () => _openCase(d.rows[i]),
      ),
    );
  }

  Widget _rowsAsTable(_FinanceData d, BuildContext context) {
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

              rows: d.rows.map((r) => _tableRow(r)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _tableRow(Map<String, dynamic> r) {
    final fees = (r['fees'] as num?)?.toDouble() ?? 0;

    final paid = (r['paid'] as num?)?.toDouble() ?? 0;

    final outstanding = (fees - paid).clamp(0, double.infinity);

    final clientName = (r['client_name'] ?? '') as String;

    return DataRow(
      onSelectChanged: (_) => _openClient(r),

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

          onTap: () => _openClient(r),
        ),

        DataCell(
          Text(
            (r['case_number'] ?? '') as String,

            style: const TextStyle(
              color: AppColors.navy,

              fontWeight: FontWeight.w700,
            ),
          ),

          onTap: () => _openCase(r),
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

          onTap: () => _openCase(r),
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

                onPressed: () => _openCase(r),
              ),

              IconButton(
                tooltip: 'كشف حساب الموكّل',

                icon: const Icon(
                  Icons.account_balance_wallet_rounded,

                  color: AppColors.gold,
                ),

                onPressed: () => _openClient(r),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openClient(Map<String, dynamic> r) async {
    final clientId = (r['client_id'] ?? 0) as int;

    final clientName = (r['client_name'] ?? '') as String;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ClientFinanceDetail(clientId: clientId, clientName: clientName),
      ),
    );

    _reload();
  }

  Future<void> _openCase(Map<String, dynamic> r) async {
    final caseId = (r['id'] ?? 0) as int;

    if (caseId == 0) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: caseId)));

    _reload();
  }
}

class _FinanceCaseCard extends StatelessWidget {
  final Map<String, dynamic> row;

  final VoidCallback onOpenClient;

  final VoidCallback onOpenCase;

  const _FinanceCaseCard({
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

class _FinanceData {
  final List<Map<String, dynamic>> rows;
  final Map<String, double> totals;
  final CaseType? filterType;

  _FinanceData({
    required this.rows,
    required this.totals,
    required this.filterType,
  });
}
