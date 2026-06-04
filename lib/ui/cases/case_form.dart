import 'package:flutter/material.dart';

import '../../db/database_helper.dart';
import '../../models/client.dart';
import '../../models/legal_case.dart';
import '../../theme/app_theme.dart';
import '../common/bidi_text_field.dart';
import '../common/money.dart';

class CaseFormScreen extends StatefulWidget {
  final int? clientId;
  final LegalCase? initial;
  const CaseFormScreen({super.key, this.clientId, this.initial});

  @override
  State<CaseFormScreen> createState() => _CaseFormScreenState();
}

class _CaseFormScreenState extends State<CaseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper.instance;

  late final TextEditingController _number;
  late final TextEditingController _title;
  late final TextEditingController _court;
  late final TextEditingController _opponent;
  late final TextEditingController _fees;
  late final TextEditingController _notes;

  int? _clientId;
  String _status = LegalCase.statusOpen;
  CaseType? _selectedCaseType;
  DateTime? _nextSession;

  List<Client> _clients = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _number = TextEditingController(text: c?.caseNumber ?? '');
    _title = TextEditingController(text: c?.title ?? '');
    _court = TextEditingController(text: c?.courtName ?? '');
    _selectedCaseType = c?.caseType;
    _opponent = TextEditingController(text: c?.opponent ?? '');
    _fees = TextEditingController(text: c == null ? '' : c.fees.toString());
    _notes = TextEditingController(text: c?.notes ?? '');
    _clientId = c?.clientId ?? widget.clientId;
    _status = c?.status ?? LegalCase.statusOpen;
    if ((c?.nextSessionDate ?? '').isNotEmpty) {
      _nextSession = DateTime.tryParse(c!.nextSessionDate!);
    }
    _loadClients();
  }

  Future<void> _loadClients() async {
    final list = await _db.getClients();
    if (!mounted) return;
    setState(() => _clients = list);
  }

  @override
  void dispose() {
    _number.dispose();
    _title.dispose();
    _court.dispose();
    _opponent.dispose();
    _fees.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickNextSession() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextSession ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _nextSession = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clientId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى اختيار الموكّل.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final fees = double.tryParse(_fees.text.replaceAll(',', '')) ?? 0;
      final c = LegalCase(
        id: widget.initial?.id,
        clientId: _clientId!,
        caseNumber: _number.text.trim(),
        title: _title.text.trim(),
        courtName: _court.text.trim().isEmpty ? null : _court.text.trim(),
        caseType: _selectedCaseType,
        opponent: _opponent.text.trim().isEmpty ? null : _opponent.text.trim(),
        status: _status,
        fees: fees,
        paid: widget.initial?.paid ?? 0,
        nextSessionDate: _nextSession?.toIso8601String(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        createdAt: widget.initial?.createdAt,
      );
      if (c.id == null) {
        await _db.insertCase(c);
      } else {
        await _db.updateCase(c);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'تعديل قضية' : 'قضية جديدة')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<int>(
                initialValue: _clients.any((c) => c.id == _clientId)
                    ? _clientId
                    : null,
                decoration: const InputDecoration(labelText: 'الموكّل *'),
                items: _clients
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.fullName),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _clientId = v),
                validator: (v) => v == null ? 'اختر الموكّل' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _number,
                      decoration: const InputDecoration(
                        labelText: 'رقم القضية *',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'رقم القضية مطلوب'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<CaseType>(
                      initialValue: _selectedCaseType,
                      decoration: const InputDecoration(
                        labelText: 'نوع القضية *',
                      ),
                      items: CaseType.values
                          .map(
                            (type) => DropdownMenuItem<CaseType>(
                              value: type,
                              child: Text(type.nameAr),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedCaseType = value),
                      validator: (value) =>
                          value == null ? 'اختر نوع القضية' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'عنوان القضية *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'العنوان مطلوب' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _court,
                      decoration: const InputDecoration(labelText: 'المحكمة'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _opponent,
                      decoration: const InputDecoration(
                        labelText: 'الخصم / الطرف الآخر',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'حالة القضية',
                      ),
                      items:
                          const [
                                LegalCase.statusOpen,
                                LegalCase.statusInProgress,
                                LegalCase.statusJudged,
                                LegalCase.statusClosed,
                              ]
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                      onChanged: (v) =>
                          setState(() => _status = v ?? LegalCase.statusOpen),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fees,
                      decoration: const InputDecoration(
                        labelText: 'أتعاب المحاماة',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickNextSession,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'الجلسة القادمة',
                    suffixIcon: Icon(
                      Icons.calendar_today_rounded,
                      color: AppColors.navy,
                    ),
                  ),
                  child: Text(
                    _nextSession == null
                        ? 'لم يتم تحديدها'
                        : formatDate(_nextSession!.toIso8601String()),
                  ),
                ),
              ),
              if (_nextSession != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _nextSession = null),
                    icon: const Icon(Icons.clear),
                    label: const Text('مسح التاريخ'),
                  ),
                ),
              const SizedBox(height: 12),
              BidiTextField(
                controller: _notes,
                label: 'ملاحظات القضية',
                hint:
                    'وصف القضية، الأطراف، الإجراءات السابقة، أو أي تفاصيل قانونية مهمة',
                minLines: 5,
                maxLines: 14,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(isEdit ? 'حفظ التعديلات' : 'حفظ القضية'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
