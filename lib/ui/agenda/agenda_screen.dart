import 'package:flutter/material.dart';

import '../../db/database_helper.dart';
import '../../models/session.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../cases/case_detail_screen.dart';
import '../common/empty_state.dart';
import '../common/money.dart';
import '../common/responsive.dart';
import '../common/section_header.dart';
import '../common/status_chip.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final _db = DatabaseHelper.instance;

  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 1)),
    end: DateTime.now().add(const Duration(days: 60)),
  );
  String? _statusFilter;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() => _db.getAgenda(
        from: _range.start,
        to: _range.end,
        statusFilter: _statusFilter,
      );

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _printAgenda() async {
    final rows = await _future;
    final settings = await _db.getSettings();
    final bytes = await PdfService.instance
        .buildAgendaPdf(settings: settings, agenda: rows);
    await PdfService.instance.exportPdf(
      bytes,
      fileName: 'agenda.pdf',
      jobName: 'أجندة المحكمة',
      shareText: 'أجندة جلسات المحكمة',
    );
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _range = picked);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _printAgenda,
        icon: const Icon(Icons.print_rounded),
        label: const Text('طباعة الأجندة'),
      ),
      body: Column(
        children: [
          _filters(),
          const SectionHeader(
            title: 'جلسات المحكمة',
            subtitle: 'مرتبة من الأقرب إلى الأبعد',
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snap.data!;
                if (rows.isEmpty) {
                  return const EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'لا توجد جلسات في النطاق المحدد',
                    message:
                        'جرّب توسيع النطاق الزمني أو تعديل عامل التصفية.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _agendaTile(rows[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    final rangeField = InkWell(
      onTap: _pickRange,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'النطاق الزمني',
          prefixIcon: Icon(Icons.date_range, color: AppColors.navy),
        ),
        child: Text(
          '${formatDate(_range.start.toIso8601String())} - ${formatDate(_range.end.toIso8601String())}',
        ),
      ),
    );
    final statusField = DropdownButtonFormField<String?>(
      initialValue: _statusFilter,
      decoration: const InputDecoration(labelText: 'الحالة'),
      items: const [
        DropdownMenuItem(value: null, child: Text('كل الحالات')),
        DropdownMenuItem(
            value: CaseSession.statusPending,
            child: Text(CaseSession.statusPending)),
        DropdownMenuItem(
            value: CaseSession.statusHeld,
            child: Text(CaseSession.statusHeld)),
        DropdownMenuItem(
            value: CaseSession.statusAdjourned,
            child: Text(CaseSession.statusAdjourned)),
        DropdownMenuItem(
            value: CaseSession.statusCancelled,
            child: Text(CaseSession.statusCancelled)),
      ],
      onChanged: (v) {
        setState(() => _statusFilter = v);
        _reload();
      },
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < AppBreakpoints.mobile) {
            return Column(
              children: [
                rangeField,
                const SizedBox(height: 10),
                statusField,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: rangeField),
              const SizedBox(width: 10),
              SizedBox(width: 200, child: statusField),
            ],
          );
        },
      ),
    );
  }

  Widget _agendaTile(Map<String, dynamic> r) {
    final caseId = r['case_id'] as int;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CaseDetailScreen(caseId: caseId),
          ));
          _reload();
        },
        leading: Container(
          width: 56,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.navy.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month, color: AppColors.navy),
              const SizedBox(height: 2),
              Text(
                formatDate((r['session_date'] ?? '') as String, pattern: 'MM/dd'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        ),
        title: Text('${r['case_number']} • ${r['case_title']}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text([
          (r['client_name'] ?? '') as String,
          if (((r['court_name'] ?? '') as String).isNotEmpty)
            r['court_name'] as String,
          formatDate((r['session_date'] ?? '') as String),
        ].where((e) => e.toString().isNotEmpty).join(' • ')),
        trailing: StatusChip((r['status'] ?? '') as String),
      ),
    );
  }
}
