import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../db/database_helper.dart';
import '../../models/attachment.dart';
import '../../models/client.dart';
import '../../models/legal_case.dart';
import '../../models/payment.dart';
import '../../models/session.dart';
import '../../services/file_service.dart';
import '../../theme/app_theme.dart';
import '../clients/client_detail_screen.dart';
import '../common/bidi_text_field.dart';
import '../common/long_text_block.dart';
import '../common/money.dart';
import '../common/section_header.dart';
import '../common/status_chip.dart';
import 'case_form.dart';

class CaseDetailScreen extends StatefulWidget {
  final int caseId;
  const CaseDetailScreen({super.key, required this.caseId});

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  final _db = DatabaseHelper.instance;
  late Future<_CaseBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_CaseBundle> _load() async {
    final c = await _db.getCase(widget.caseId);
    if (c == null) throw Exception('Case not found');
    final client = await _db.getClient(c.clientId);
    final sessions = await _db.getSessions(caseId: widget.caseId);
    final payments = await _db.getPayments(caseId: widget.caseId);
    final atts = await _db.getAttachments(caseId: widget.caseId);
    return _CaseBundle(
      legalCase: c,
      client: client,
      sessions: sessions,
      payments: payments,
      attachments: atts,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _editCase(LegalCase c) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => CaseFormScreen(initial: c),
    ));
    if (saved == true) _reload();
  }

  Future<void> _addPayment(LegalCase c) async {
    await showDialog(
      context: context,
      builder: (_) => _PaymentDialog(legalCase: c, onSaved: _reload),
    );
  }

  Future<void> _addSession(LegalCase c) async {
    await showDialog(
      context: context,
      builder: (_) => _SessionDialog(legalCase: c, onSaved: _reload),
    );
  }

  Future<void> _editSession(CaseSession s) async {
    final c = (await _db.getCase(s.caseId))!;
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _SessionDialog(
        legalCase: c,
        existing: s,
        onSaved: _reload,
      ),
    );
  }

  Future<void> _attachDocument() async {
    final picked =
        await FileService.instance.pickAndStoreDocument(subfolder: 'cases');
    if (picked == null) return;
    await _db.insertAttachment(Attachment(
      caseId: widget.caseId,
      fileName: picked.fileName,
      localPath: picked.localPath,
      sizeBytes: picked.sizeBytes,
    ));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل القضية')),
      body: FutureBuilder<_CaseBundle>(
        future: _future,
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final b = snap.data!;
          final c = b.legalCase;
          return ListView(
            children: [
              _header(b),
              if ((c.notes ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: LongTextBlock(
                        label: 'ملاحظات القضية',
                        text: c.notes!,
                        collapsedLines: 4,
                      ),
                    ),
                  ),
                ),
              SectionHeader(
                title: 'الجلسات',
                subtitle: '${b.sessions.length} جلسة',
                actions: [
                  ElevatedButton.icon(
                    onPressed: () => _addSession(c),
                    icon: const Icon(Icons.add),
                    label: const Text('جلسة'),
                  ),
                ],
              ),
              if (b.sessions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لا توجد جلسات.',
                      style: TextStyle(color: Colors.black54)),
                )
              else
                ...b.sessions.map(_sessionTile),
              SectionHeader(
                title: 'المدفوعات',
                subtitle: '${b.payments.length} عملية',
                actions: [
                  ElevatedButton.icon(
                    onPressed: () => _addPayment(c),
                    icon: const Icon(Icons.payments_rounded),
                    label: const Text('دفعة'),
                  ),
                ],
              ),
              if (b.payments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لم يتم تسجيل أي دفعات.',
                      style: TextStyle(color: Colors.black54)),
                )
              else
                ...b.payments.map((p) => _paymentTile(p, c)),
              SectionHeader(
                title: 'مستندات القضية',
                subtitle: '${b.attachments.length} ملف',
                actions: [
                  ElevatedButton.icon(
                    onPressed: _attachDocument,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('إرفاق'),
                  ),
                ],
              ),
              if (b.attachments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لا توجد مستندات.',
                      style: TextStyle(color: Colors.black54)),
                )
              else
                ...b.attachments.map(_attachmentTile),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _header(_CaseBundle b) {
    final c = b.legalCase;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.navy, AppColors.navySoft],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${c.caseNumber} • ${c.title}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _editCase(c),
                icon: const Icon(Icons.edit_note_rounded,
                    color: AppColors.gold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              StatusChip(c.status),
              if (b.client != null)
                _kv(
                  Icons.person_outline,
                  b.client!.fullName,
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          ClientDetailScreen(client: b.client!),
                    ));
                    _reload();
                  },
                ),
              if ((c.courtName ?? '').isNotEmpty)
                _kv(Icons.account_balance, c.courtName!),
              if ((c.caseType ?? '').isNotEmpty)
                _kv(Icons.category_outlined, c.caseType!),
              if ((c.opponent ?? '').isNotEmpty)
                _kv(Icons.swap_horiz, 'الخصم: ${c.opponent!}'),
              if ((c.nextSessionDate ?? '').isNotEmpty)
                _kv(Icons.event,
                    'الجلسة القادمة: ${formatDate(c.nextSessionDate!)}'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _miniMoney(
                    'الأتعاب', c.fees, AppColors.gold.withValues(alpha: 0.95)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniMoney('المسدد', c.paid, AppColors.success),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniMoney('المتبقي', c.outstanding, AppColors.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(IconData i, String s, {VoidCallback? onTap}) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(i, color: AppColors.gold, size: 16),
        const SizedBox(width: 6),
        Text(
          s,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            decoration: onTap != null ? TextDecoration.underline : null,
            decorationColor: AppColors.gold,
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 4),
          const Icon(Icons.open_in_new_rounded,
              color: AppColors.gold, size: 12),
        ],
      ],
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: row,
      ),
    );
  }

  Widget _miniMoney(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            formatMoney(value),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionTile(CaseSession s) {
    final hasBody = (s.notes ?? '').isNotEmpty || (s.decision ?? '').isNotEmpty;
    return Card(
      child: InkWell(
        onTap: () => _editSession(s),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_available, color: AppColors.navy),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      formatDate(s.sessionDate),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  StatusChip(s.status),
                ],
              ),
              if (hasBody) const SizedBox(height: 8),
              if ((s.notes ?? '').isNotEmpty)
                LongTextBlock(label: 'وقائع الجلسة', text: s.notes!),
              if ((s.decision ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                LongTextBlock(
                  label: 'القرار',
                  text: s.decision!,
                  accent: AppColors.gold,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentTile(Payment p, LegalCase c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Row(
          children: [
            const Icon(Icons.payments_rounded, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${formatMoney(p.amount)} ر.س',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(formatDate(p.paymentDate),
                          style: const TextStyle(color: Colors.black54)),
                      if ((p.method ?? '').isNotEmpty) ...[
                        const Text('  •  ', style: TextStyle(color: Colors.black38)),
                        Text(p.method!,
                            style: const TextStyle(color: Colors.black54)),
                      ],
                    ],
                  ),
                  if ((p.notes ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    LongTextBlock(label: 'ملاحظات', text: p.notes!),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: () async {
                await _db.deletePayment(p);
                _reload();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentTile(Attachment a) {
    return Card(
      child: ListTile(
        onTap: () => OpenFilex.open(a.localPath),
        leading: const Icon(Icons.insert_drive_file_rounded,
            color: AppColors.navy),
        title: Text(a.fileName),
        subtitle: Text(formatDateTime(a.createdAt)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          onPressed: () async {
            await _db.deleteAttachment(a.id!);
            await FileService.instance.deletePhysicalFile(a.localPath);
            _reload();
          },
        ),
      ),
    );
  }
}

class _CaseBundle {
  final LegalCase legalCase;
  final Client? client;
  final List<CaseSession> sessions;
  final List<Payment> payments;
  final List<Attachment> attachments;
  _CaseBundle({
    required this.legalCase,
    required this.client,
    required this.sessions,
    required this.payments,
    required this.attachments,
  });
}

class _PaymentDialog extends StatefulWidget {
  final LegalCase legalCase;
  final VoidCallback onSaved;
  const _PaymentDialog({required this.legalCase, required this.onSaved});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _amount = TextEditingController();
  final _method = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تسجيل دفعة'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            TextField(
              controller: _amount,
              decoration: const InputDecoration(labelText: 'المبلغ *'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _method,
              decoration:
                  const InputDecoration(labelText: 'طريقة الدفع (نقدي / تحويل ...)'),
            ),
            const SizedBox(height: 8),
            BidiTextField(
              controller: _notes,
              label: 'ملاحظات الدفعة',
              hint: 'رقم الإيصال أو تفاصيل إضافية',
              minLines: 3,
              maxLines: 6,
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'تاريخ الدفعة',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(formatDate(_date.toIso8601String())),
              ),
            ),
          ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () async {
            final v = double.tryParse(_amount.text.replaceAll(',', ''));
            if (v == null || v <= 0) return;
            await DatabaseHelper.instance.insertPayment(Payment(
              caseId: widget.legalCase.id!,
              amount: v,
              paymentDate: _date.toIso8601String(),
              method: _method.text.trim().isEmpty ? null : _method.text.trim(),
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            ));
            widget.onSaved();
            if (mounted) Navigator.pop(context);
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _SessionDialog extends StatefulWidget {
  final LegalCase legalCase;
  final CaseSession? existing;
  final VoidCallback onSaved;
  const _SessionDialog({
    required this.legalCase,
    this.existing,
    required this.onSaved,
  });

  @override
  State<_SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends State<_SessionDialog> {
  late DateTime _date;
  late TextEditingController _notes;
  late TextEditingController _decision;
  late String _status;
  late TextEditingController _nextDate;
  DateTime? _nextDateValue;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _date = s != null ? DateTime.parse(s.sessionDate) : DateTime.now();
    _notes = TextEditingController(text: s?.notes ?? '');
    _decision = TextEditingController(text: s?.decision ?? '');
    _status = s?.status ?? CaseSession.statusPending;
    _nextDate = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'إضافة جلسة' : 'تعديل جلسة'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'تاريخ الجلسة *',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(formatDate(_date.toIso8601String())),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'الحالة'),
                items: const [
                  CaseSession.statusPending,
                  CaseSession.statusHeld,
                  CaseSession.statusAdjourned,
                  CaseSession.statusCancelled,
                ]
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(
                    () => _status = v ?? CaseSession.statusPending),
              ),
              const SizedBox(height: 8),
              BidiTextField(
                controller: _notes,
                label: 'وقائع الجلسة',
                hint: 'ملخص ما دار في الجلسة، الحاضرون، ومستندات قُدِّمت',
                minLines: 4,
                maxLines: 10,
              ),
              const SizedBox(height: 8),
              BidiTextField(
                controller: _decision,
                label: 'القرار / الحكم',
                hint: 'منطوق القرار أو الحكم الصادر',
                minLines: 3,
                maxLines: 8,
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _nextDateValue ??
                        _date.add(const Duration(days: 14)),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _nextDateValue = picked;
                      _nextDate.text = formatDate(picked.toIso8601String());
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'الجلسة القادمة (اختياري)',
                    helperText: 'سيتم إنشاء جلسة جديدة قيد الانتظار تلقائيًا',
                    suffixIcon: Icon(Icons.event),
                  ),
                  child: Text(_nextDateValue == null
                      ? 'لم تُحدَّد'
                      : formatDate(_nextDateValue!.toIso8601String())),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () async {
            final db = DatabaseHelper.instance;
            final session = CaseSession(
              id: widget.existing?.id,
              caseId: widget.legalCase.id!,
              sessionDate: _date.toIso8601String(),
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
              decision: _decision.text.trim().isEmpty
                  ? null
                  : _decision.text.trim(),
              status: _status,
              createdAt: widget.existing?.createdAt,
            );
            if (widget.existing == null) {
              await db.insertSession(session);
            } else {
              await db.updateSession(session);
            }

            if (_nextDateValue != null) {
              final updatedCase = widget.legalCase.copyWith(
                nextSessionDate: _nextDateValue!.toIso8601String(),
              );
              await db.updateCase(updatedCase);
            }
            widget.onSaved();
            if (mounted) Navigator.pop(context);
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
