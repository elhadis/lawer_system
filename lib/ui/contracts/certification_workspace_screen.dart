import 'package:flutter/material.dart';

import '../../db/database_helper.dart';
import '../../models/contract.dart';
import '../../services/pdf_service.dart';

class CertificationWorkspaceScreen extends StatefulWidget {
  const CertificationWorkspaceScreen({super.key, this.initial});

  final Contract? initial;

  @override
  State<CertificationWorkspaceScreen> createState() =>
      _CertificationWorkspaceScreenState();
}

class _CertificationWorkspaceScreenState
    extends State<CertificationWorkspaceScreen> {
  final _db = DatabaseHelper.instance;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _busy = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _titleController.text = initial.title;
      _bodyController.text = initial.body;
    } else {
      _titleController.text = 'توثيق جديد';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save({bool popAfterSave = false}) async {
    if (_busy) return;
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء كتابة نص التوثيق قبل الحفظ')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final title = _titleController.text.trim().isEmpty
          ? 'توثيق ${DateTime.now().toLocal()}'
          : _titleController.text.trim();
      final initial = widget.initial;
      final model = Contract(
        id: initial?.id,
        clientId: initial?.clientId,
        caseId: initial?.caseId,
        title: title,
        body: body,
        amount: 0,
        contractDate: initial?.contractDate ?? DateTime.now().toIso8601String(),
        createdAt: initial?.createdAt,
        isCertification: true,
      );

      if (_isEdit) {
        await _db.updateContract(model);
      } else {
        await _db.insertContract(model);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التوثيق محليًا بنجاح')),
      );

      if (popAfterSave) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _print() async {
    if (_busy) return;
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('لا يمكن الطباعة بدون نص')));
      return;
    }

    setState(() => _busy = true);
    try {
      final bytes = await PdfService.instance.buildCertificationPdf(
        title: _titleController.text.trim().isEmpty
            ? 'توثيق قانوني'
            : _titleController.text.trim(),
        body: body,
      );
      await PdfService.instance.exportPdf(
        bytes,
        fileName:
            '${_titleController.text.trim().isEmpty ? 'certification' : _titleController.text.trim()}.pdf',
        jobName: _titleController.text.trim().isEmpty
            ? 'توثيق قانوني'
            : _titleController.text.trim(),
        shareText: 'توثيق قانوني',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(_isEdit ? 'تعديل توثيق' : 'توثيق جديد')),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  TextField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'عنوان التوثيق',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bodyController,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    minLines: 18,
                    textAlign: TextAlign.start,
                    decoration: const InputDecoration(
                      alignLabelWithHint: true,
                      hintText: 'اكتب نص التوثيق هنا...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _save(popAfterSave: true),
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('حفظ'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _print,
                        icon: const Icon(Icons.print_rounded),
                        label: const Text('طباعة'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
