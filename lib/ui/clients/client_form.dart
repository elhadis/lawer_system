import 'package:flutter/material.dart';

import '../../db/database_helper.dart';
import '../../models/client.dart';
import '../common/bidi_text_field.dart';

class ClientFormScreen extends StatefulWidget {
  final Client? initial;
  const ClientFormScreen({super.key, this.initial});

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper.instance;

  late final TextEditingController _name;
  late final TextEditingController _id;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _notes;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _name = TextEditingController(text: c?.fullName ?? '');
    _id = TextEditingController(text: c?.nationalId ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _address = TextEditingController(text: c?.address ?? '');
    _notes = TextEditingController(text: c?.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _id.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final c = Client(
        id: widget.initial?.id,
        fullName: _name.text.trim(),
        nationalId: _id.text.trim().isEmpty ? null : _id.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        createdAt: widget.initial?.createdAt,
      );
      if (c.id == null) {
        await _db.insertClient(c);
      } else {
        await _db.updateClient(c);
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
      appBar: AppBar(
        title: Text(isEdit ? 'تعديل بيانات الموكّل' : 'موكّل جديد'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'الاسم الكامل *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _id,
                decoration: const InputDecoration(labelText: 'رقم الهوية'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'الهاتف'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              BidiTextField(
                controller: _address,
                label: 'العنوان',
                hint: 'المدينة، الحي، الشارع',
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              BidiTextField(
                controller: _notes,
                label: 'ملاحظات',
                hint: 'أي ملاحظات إضافية عن الموكّل، ظروف القضية، أو معلومات تواصل بديلة',
                minLines: 5,
                maxLines: 12,
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
                label: Text(isEdit ? 'حفظ التغييرات' : 'حفظ الموكّل'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
