import 'package:flutter/material.dart';

import '../../db/database_helper.dart';
import '../../models/client.dart';
import '../../models/legal_case.dart';
import '../../models/payment.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../cases/case_detail_screen.dart';
import '../common/empty_state.dart';
import '../common/money.dart';
import '../common/responsive.dart';
import '../common/section_header.dart';
import '../common/status_chip.dart';

class ClientFinanceDetail extends StatefulWidget {
  final int clientId;
  final String clientName;
  const ClientFinanceDetail({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<ClientFinanceDetail> createState() => _ClientFinanceDetailState();
}

class _ClientFinanceDetailState extends State<ClientFinanceDetail> {
  final _db = DatabaseHelper.instance;
  late Future<_Bundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Bundle> _load() async {
    final client = await _db.getClient(widget.clientId);
    final cases = await _db.getCases(clientId: widget.clientId);
    final payments = await _db.getPayments(clientId: widget.clientId);
    return _Bundle(client: client, cases: cases, payments: payments);
  }

  Future<void> _printStatement(_Bundle b) async {
    if (b.client == null) return;
    final settings = await _db.getSettings();
    final bytes = await PdfService.instance.buildClientStatementPdf(
      settings: settings,
      client: b.client!,
      cases: b.cases,
      payments: b.payments,
    );
    final name = b.client!.fullName;
    await PdfService.instance.exportPdf(
      bytes,
      fileName: 'statement_$name.pdf',
      jobName: 'كشف حساب - $name',
      shareText: 'كشف حساب موكّل - $name',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('سجل ${widget.clientName} المالي'),
      ),
      body: FutureBuilder<_Bundle>(
        future: _future,
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final b = snap.data!;
          final totalFees = b.cases.fold<double>(0, (s, c) => s + c.fees);
          final totalPaid = b.cases.fold<double>(0, (s, c) => s + c.paid);
          final totalOutstanding =
              (totalFees - totalPaid).clamp(0, double.infinity);
          final mobile = AppBreakpoints.isMobile(context);

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.only(bottom: 90),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [AppColors.navy, AppColors.navySoft],
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_circle_rounded,
                            size: 48, color: AppColors.gold),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.client?.fullName ?? widget.clientName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18)),
                              const SizedBox(height: 4),
                              Text(
                                'عدد القضايا: ${b.cases.length} • عدد المدفوعات: ${b.payments.length}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: mobile
                        ? Column(
                            children: [
                              _miniStat('الأتعاب', totalFees, AppColors.navy),
                              _miniStat('المسدد', totalPaid, AppColors.success),
                              _miniStat('المتبقي',
                                  totalOutstanding.toDouble(), AppColors.danger),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _miniStat(
                                    'الأتعاب', totalFees, AppColors.navy),
                              ),
                              Expanded(
                                child: _miniStat(
                                    'المسدد', totalPaid, AppColors.success),
                              ),
                              Expanded(
                                child: _miniStat(
                                    'المتبقي',
                                    totalOutstanding.toDouble(),
                                    AppColors.danger),
                              ),
                            ],
                          ),
                  ),
                  const SectionHeader(title: 'القضايا'),
                  if (b.cases.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('لا توجد قضايا.',
                          style: TextStyle(color: Colors.black54)),
                    )
                  else
                    ...b.cases.map(_caseTile),
                  const SectionHeader(
                    title: 'سجل المدفوعات الكامل',
                    subtitle: 'يشمل كل دفعات الموكّل عبر جميع قضاياه',
                  ),
                  if (b.payments.isEmpty)
                    const EmptyState(
                      icon: Icons.payments_outlined,
                      title: 'لم يتم تسجيل أي مدفوعات بعد',
                    )
                  else if (mobile)
                    ...b.payments.map(
                      (p) => _paymentCard(p, b.cases, context),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Card(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: MediaQuery.sizeOf(context).width - 48,
                            ),
                            child: DataTable(
                              columnSpacing: 28,
                              columns: const [
                                DataColumn(label: Text('التاريخ')),
                                DataColumn(label: Text('المبلغ'), numeric: true),
                                DataColumn(label: Text('طريقة الدفع')),
                                DataColumn(label: Text('ملاحظات')),
                                DataColumn(label: Text('القضية')),
                              ],
                              rows: b.payments
                                  .map((p) => _paymentRow(p, b.cases, context))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Positioned(
                left: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  onPressed: () => _printStatement(b),
                  icon: Icon(
                    mobile ? Icons.share_rounded : Icons.picture_as_pdf_rounded,
                  ),
                  label: Text(mobile ? 'مشاركة كشف الحساب' : 'كشف حساب PDF'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _paymentCard(
      Payment p, List<LegalCase> cases, BuildContext context) {
    final c = cases.firstWhere(
      (e) => e.id == p.caseId,
      orElse: () => LegalCase(
          id: p.caseId, clientId: 0, caseNumber: '-', title: '-'),
    );
    Future<void> openCase() async {
      if (c.id == null) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CaseDetailScreen(caseId: c.id!),
      ));
      if (mounted) setState(() => _future = _load());
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minVerticalPadding: 12,
        onTap: openCase,
        title: Text(
          formatMoney(p.amount),
          style: const TextStyle(
            color: AppColors.success,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatDate(p.paymentDate)),
            if ((p.method ?? '').isNotEmpty) Text('الطريقة: ${p.method}'),
            if ((p.notes ?? '').isNotEmpty) Text(p.notes!),
            Text(
              '${c.caseNumber} - ${c.title}',
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_left_rounded),
      ),
    );
  }

  DataRow _paymentRow(Payment p, List<LegalCase> cases, BuildContext context) {
    final c = cases.firstWhere(
      (e) => e.id == p.caseId,
      orElse: () => LegalCase(
          id: p.caseId, clientId: 0, caseNumber: '-', title: '-'),
    );
    Future<void> openCase() async {
      if (c.id == null) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CaseDetailScreen(caseId: c.id!),
      ));
      if (mounted) {
        setState(() {
          _future = _load();
        });
      }
    }

    return DataRow(
      onSelectChanged: (_) => openCase(),
      cells: [
        DataCell(Text(formatDate(p.paymentDate))),
        DataCell(Text(
          formatMoney(p.amount),
          style: const TextStyle(
              color: AppColors.success, fontWeight: FontWeight.w700),
        )),
        DataCell(Text(p.method ?? '-')),
        DataCell(SizedBox(
          width: 200,
          child: Text(p.notes ?? '-',
              maxLines: 1, overflow: TextOverflow.ellipsis),
        )),
        DataCell(
          Text(
            '${c.caseNumber} - ${c.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
            ),
          ),
          onTap: openCase,
        ),
      ],
    );
  }

  Widget _miniStat(String label, double value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.black54, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              '${formatMoney(value)} ر.س',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _caseTile(LegalCase c) {
    return Card(
      child: ListTile(
        onTap: c.id == null
            ? null
            : () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CaseDetailScreen(caseId: c.id!),
                ));
                if (mounted) {
                  setState(() {
                    _future = _load();
                  });
                }
              },
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.gavel, color: AppColors.navy),
        ),
        title: Text('${c.caseNumber} • ${c.title}'),
        subtitle: Text(
          'أتعاب: ${formatMoney(c.fees)}  •  مسدد: ${formatMoney(c.paid)}  •  متبقي: ${formatMoney(c.outstanding)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusChip(c.status),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_left_rounded,
                color: Colors.black38),
          ],
        ),
      ),
    );
  }
}

class _Bundle {
  final Client? client;
  final List<LegalCase> cases;
  final List<Payment> payments;
  _Bundle({
    required this.client,
    required this.cases,
    required this.payments,
  });
}
