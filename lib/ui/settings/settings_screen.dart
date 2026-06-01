import 'dart:io';

import 'package:flutter/material.dart';

import '../../db/database_helper.dart';
import '../../license_service.dart';
import '../../models/office_settings.dart';
import '../../services/file_service.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseHelper.instance;

  final _lawyer = TextEditingController();
  final _office = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _license = TextEditingController();

  String? _logoPath;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _db.getSettings();
    _lawyer.text = s.lawyerName;
    _office.text = s.officeName;
    _phone.text = s.phone ?? '';
    _address.text = s.address ?? '';
    _license.text = s.license ?? '';
    _logoPath = s.logoPath;
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _lawyer.dispose();
    _office.dispose();
    _phone.dispose();
    _address.dispose();
    _license.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await FileService.instance.pickAndStoreLogo();
    if (picked != null) {
      setState(() => _logoPath = picked.localPath);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final s = OfficeSettings(
        lawyerName: _lawyer.text.trim(),
        officeName: _office.text.trim(),
        logoPath: _logoPath,
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        license: _license.text.trim().isEmpty ? null : _license.text.trim(),
      );
      await _db.updateSettings(s);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ إعدادات المكتب.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LogoBox(path: _logoPath),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'هوية المكتب',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'تظهر هذه البيانات في رأس كل عقد أو تقرير قانوني.',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickLogo,
                            icon: const Icon(Icons.image_rounded),
                            label: const Text('تحميل شعار المكتب'),
                          ),
                          if (_logoPath != null)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  setState(() => _logoPath = null),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('إزالة الشعار'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lawyer,
          decoration: const InputDecoration(labelText: 'اسم المحامي'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _office,
          decoration: const InputDecoration(labelText: 'اسم المكتب'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'الهاتف'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _license,
                decoration:
                    const InputDecoration(labelText: 'رقم رخصة المحاماة'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _address,
          decoration: const InputDecoration(labelText: 'العنوان'),
          maxLines: 2,
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
          label: const Text('حفظ الإعدادات'),
        ),
        const SizedBox(height: 32),
        _AboutSupportCard(),
      ],
    );
  }
}

class _AboutSupportCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'عن التطبيق والدعم',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'يُستخدم معرّف الجهاز أدناه عند طلب مفتاح التفعيل أو الدعم الفني.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FutureBuilder<String>(
              future: LicenseService.getUniqueDeviceId(),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator(minHeight: 2);
                }
                final id = snap.data ?? '—';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'معرّف الجهاز',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: SelectableText(
                        id,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoBox extends StatelessWidget {
  final String? path;
  const _LogoBox({this.path});

  @override
  Widget build(BuildContext context) {
    final hasFile = path != null && File(path!).existsSync();
    return Container(
      width: 110,
      height: 110,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        border: Border.all(color: AppColors.gold),
        borderRadius: BorderRadius.circular(12),
      ),
      child: hasFile
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(File(path!), fit: BoxFit.contain),
            )
          : const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_outlined,
                    color: AppColors.navy, size: 36),
                SizedBox(height: 6),
                Text('بدون شعار',
                    style:
                        TextStyle(color: AppColors.navy, fontSize: 12)),
              ],
            ),
    );
  }
}
