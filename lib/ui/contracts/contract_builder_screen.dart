import 'package:flutter/material.dart';

import '../../db/database_helper.dart';
import '../../models/client.dart';
import '../../models/contract.dart';
import '../../models/legal_case.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../common/bidi_text_field.dart';
import '../common/money.dart';

const _wakalaTemplate = '''إنه في يوم ........ الموافق ........

تم الاتفاق بين كل من:
- الطرف الأول (الموكّل): ................................................
- الطرف الثاني (المحامي): ................................................

تمهيد:
لما كان الطرف الأول راغبًا في توكيل الطرف الثاني للقيام بإجراءات قانونية، فقد اتفق الطرفان وهما بكامل الأهلية المعتبرة شرعًا وقانونًا على ما يلي:

البند الأول: محل العقد
يلتزم الطرف الثاني (المحامي) بمتابعة القضية المذكورة أعلاه أمام الجهات القضائية المختصة وتقديم كل ما يلزم من مرافعات ومذكرات ومستندات.

البند الثاني: الأتعاب
اتفق الطرفان على أن يكون مجموع الأتعاب قدره (......) يُسدَّد وفق الجدول الزمني المتفق عليه.

البند الثالث: التزامات الطرف الأول
يلتزم الطرف الأول بتزويد المحامي بكافة المستندات والمعلومات اللازمة، والحضور عند الاقتضاء.

البند الرابع: السرية
يلتزم الطرفان بسرية المعلومات المتبادلة، ولا يجوز إفشاؤها إلا بموافقة كتابية مسبقة.

البند الخامس: المنازعات
عند نشوء أي خلاف يُحال إلى الجهات القضائية المختصة في مكان مزاولة المهنة.

البند السادس: نسخ العقد
حُرِّر هذا العقد من نسختين أصليتين، استلم كل طرف نسخة منهما للعمل بمقتضاها.''';

class ContractBuilderScreen extends StatefulWidget {
  final Contract? initial;
  const ContractBuilderScreen({super.key, this.initial});

  @override
  State<ContractBuilderScreen> createState() => _ContractBuilderScreenState();
}

class _ContractBuilderScreenState extends State<ContractBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper.instance;

  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _body;

  DateTime _date = DateTime.now();
  int? _clientId;
  int? _caseId;

  List<Client> _clients = [];
  List<LegalCase> _cases = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _title =
        TextEditingController(text: c?.title ?? 'عقد توكيل ومتابعة قضية');
    _amount =
        TextEditingController(text: c == null ? '' : c.amount.toString());
    _body = TextEditingController(text: c?.body ?? _wakalaTemplate);
    _date = c == null ? DateTime.now() : DateTime.parse(c.contractDate);
    _clientId = c?.clientId;
    _caseId = c?.caseId;
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    final clients = await _db.getClients();
    final cases = await _db.getCases();
    if (!mounted) return;
    setState(() {
      _clients = clients;
      _cases = cases;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save({bool printAfter = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final amount = double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;
      final c = Contract(
        id: widget.initial?.id,
        clientId: _clientId,
        caseId: _caseId,
        title: _title.text.trim(),
        body: _body.text,
        amount: amount,
        contractDate: _date.toIso8601String(),
        createdAt: widget.initial?.createdAt,
      );
      int id;
      if (c.id == null) {
        id = await _db.insertContract(c);
      } else {
        await _db.updateContract(c);
        id = c.id!;
      }

      if (printAfter) {
        final saved = await _db.getContract(id);
        if (saved != null) {
          final settings = await _db.getSettings();
          final client = saved.clientId == null
              ? null
              : await _db.getClient(saved.clientId!);
          final legalCase = saved.caseId == null
              ? null
              : await _db.getCase(saved.caseId!);
          final bytes = await PdfService.instance.buildContractPdf(
            settings: settings,
            contract: saved,
            client: client,
            legalCase: legalCase,
          );
          await PdfService.instance.exportPdf(
            bytes,
            fileName: '${saved.title}.pdf',
            jobName: saved.title,
            shareText: saved.title,
          );
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCases = _clientId == null
        ? _cases
        : _cases.where((c) => c.clientId == _clientId).toList();

    final clientDropdownValue =
        _clients.any((c) => c.id == _clientId) ? _clientId : null;
    final caseDropdownValue =
        filteredCases.any((c) => c.id == _caseId) ? _caseId : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.initial == null ? 'منشئ العقود' : 'تعديل العقد'),
        actions: [
          IconButton(
            tooltip: 'حفظ وطباعة',
            icon: const Icon(Icons.print_rounded),
            onPressed:
                _saving ? null : () => _save(printAfter: true),
          ),
          IconButton(
            tooltip: 'حفظ',
            icon: const Icon(Icons.save_rounded),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'عنوان العقد *'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'العنوان مطلوب'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: clientDropdownValue,
                      decoration:
                          const InputDecoration(labelText: 'الموكّل (اختياري)'),
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('—')),
                        ..._clients.map((c) => DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text(c.fullName),
                            )),
                      ],
                      onChanged: (v) => setState(() {
                        _clientId = v;
                        _caseId = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: caseDropdownValue,
                      decoration: const InputDecoration(
                          labelText: 'القضية (اختياري)'),
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('—')),
                        ...filteredCases.map((c) => DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text('${c.caseNumber} • ${c.title}'),
                            )),
                      ],
                      onChanged: (v) => setState(() => _caseId = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amount,
                      decoration: const InputDecoration(
                          labelText: 'قيمة العقد (اختياري)'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
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
                          labelText: 'تاريخ العقد',
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(formatDate(_date.toIso8601String())),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _body.text = _wakalaTemplate),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('استخدام قالب التوكيل'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              BidiTextField(
                controller: _body,
                label: 'نص العقد',
                hint:
                    'حرّر نص العقد هنا. كل فقرة تبدأ بكلمة "البند" أو "تمهيد" ستُعرض كعنوان مميَّز عند الطباعة.',
                document: true,
                minLines: 18,
                maxLines: 40,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'نص العقد مطلوب' : null,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('حفظ'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _saving ? null : () => _save(printAfter: true),
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('حفظ وطباعة PDF'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
