import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../db/database_helper.dart';
import '../../models/attachment.dart';
import '../../models/client.dart';
import '../../models/legal_case.dart';
import '../../services/file_service.dart';
import '../../theme/app_theme.dart';
import '../cases/case_detail_screen.dart';
import '../cases/case_form.dart';
import '../common/empty_state.dart';
import '../common/long_text_block.dart';
import '../common/money.dart';
import '../common/section_header.dart';
import '../common/status_chip.dart';

class ClientDetailScreen extends StatefulWidget {
  final Client client;
  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final _db = DatabaseHelper.instance;
  late Future<_ClientBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ClientBundle> _load() async {
    final cases = await _db.getCases(clientId: widget.client.id);
    final atts = await _db.getAttachments(clientId: widget.client.id);
    final payments = await _db.getPayments(clientId: widget.client.id);
    return _ClientBundle(cases: cases, attachments: atts, paymentsCount: payments.length);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _attachDocument() async {
    final picked =
        await FileService.instance.pickAndStoreDocument(subfolder: 'clients');
    if (picked == null) return;
    await _db.insertAttachment(Attachment(
      clientId: widget.client.id,
      fileName: picked.fileName,
      localPath: picked.localPath,
      sizeBytes: picked.sizeBytes,
    ));
    _reload();
  }

  Future<void> _addCase() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => CaseFormScreen(clientId: widget.client.id!),
    ));
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.client.fullName)),
      body: FutureBuilder<_ClientBundle>(
        future: _future,
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          final c = widget.client;
          return ListView(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        if ((c.phone ?? '').isNotEmpty)
                          _kv(Icons.phone, c.phone!),
                        if ((c.nationalId ?? '').isNotEmpty)
                          _kv(Icons.badge_outlined, c.nationalId!),
                        if ((c.email ?? '').isNotEmpty)
                          _kv(Icons.email_outlined, c.email!),
                        if ((c.address ?? '').isNotEmpty)
                          _kv(Icons.location_on_outlined, c.address!),
                      ],
                    ),
                  ],
                ),
              ),
              if ((c.notes ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: LongTextBlock(
                        label: 'ملاحظات الموكّل',
                        text: c.notes!,
                        collapsedLines: 4,
                      ),
                    ),
                  ),
                ),
              SectionHeader(
                title: 'القضايا',
                subtitle: '${data.cases.length} قضية',
                actions: [
                  ElevatedButton.icon(
                    onPressed: _addCase,
                    icon: const Icon(Icons.add),
                    label: const Text('قضية جديدة'),
                  ),
                ],
              ),
              if (data.cases.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لا توجد قضايا لهذا الموكّل بعد.',
                      style: TextStyle(color: Colors.black54)),
                )
              else
                ...data.cases.map(_caseTile),
              SectionHeader(
                title: 'المستندات',
                subtitle: '${data.attachments.length} ملف',
                actions: [
                  ElevatedButton.icon(
                    onPressed: _attachDocument,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('إرفاق مستند'),
                  ),
                ],
              ),
              if (data.attachments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لم يتم إرفاق مستندات.',
                      style: TextStyle(color: Colors.black54)),
                )
              else
                ...data.attachments.map(_attachmentTile),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _kv(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.gold, size: 16),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _caseTile(LegalCase c) {
    return Card(
      child: ListTile(
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CaseDetailScreen(caseId: c.id!),
          ));
          _reload();
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
        title: Text('${c.caseNumber} • ${c.title}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if ((c.courtName ?? '').isNotEmpty) c.courtName!,
            'أتعاب: ${formatMoney(c.fees)}',
            'متبقي: ${formatMoney(c.outstanding)}',
          ].join(' • '),
        ),
        trailing: StatusChip(c.status),
      ),
    );
  }

  Widget _attachmentTile(Attachment a) {
    return Card(
      child: ListTile(
        onTap: () => OpenFilex.open(a.localPath),
        leading: const Icon(Icons.insert_drive_file_rounded,
            color: AppColors.navy),
        title: Text(a.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text([
          if (a.sizeBytes != null)
            '${(a.sizeBytes! / 1024).toStringAsFixed(1)} KB',
          formatDateTime(a.createdAt),
        ].join(' • ')),
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

class _ClientBundle {
  final List<LegalCase> cases;
  final List<Attachment> attachments;
  final int paymentsCount;
  _ClientBundle({
    required this.cases,
    required this.attachments,
    required this.paymentsCount,
  });
}
