import 'package:flutter/material.dart';

import '../../db/database_helper.dart';
import '../../models/client.dart';
import '../../theme/app_theme.dart';
import '../common/empty_state.dart';
import 'client_detail_screen.dart';
import 'client_form.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _db = DatabaseHelper.instance;
  final _searchCtrl = TextEditingController();
  late Future<List<Client>> _future;

  @override
  void initState() {
    super.initState();
    _future = _db.getClients();
  }

  void _reload() {
    setState(() {
      _future = _db.getClients(search: _searchCtrl.text.trim());
    });
  }

  Future<void> _openForm({Client? client}) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ClientFormScreen(initial: client),
    ));
    if (saved == true) _reload();
  }

  Future<void> _openDetail(Client client) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ClientDetailScreen(client: client),
    ));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('موكّل جديد'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _reload(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: AppColors.navy),
                hintText: 'ابحث بالاسم أو الهاتف أو رقم الهوية',
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _reload();
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Client>>(
              future: _future,
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final clients = snap.data!;
                if (clients.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_alt_rounded,
                    title: 'لا يوجد موكّلون بعد',
                    message: 'ابدأ بإضافة موكّلك الأول لإدارة قضاياه ومستنداته.',
                    action: ElevatedButton.icon(
                      onPressed: () => _openForm(),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('إضافة موكّل'),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                  itemCount: clients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final c = clients[i];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        onTap: () => _openDetail(c),
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.navy.withValues(alpha: 0.08),
                          foregroundColor: AppColors.navy,
                          child: Text(
                            c.fullName.isNotEmpty ? c.fullName[0] : '?',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        title: Text(c.fullName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text([
                          if ((c.phone ?? '').isNotEmpty) c.phone!,
                          if ((c.nationalId ?? '').isNotEmpty)
                            'هوية: ${c.nationalId}',
                          if ((c.email ?? '').isNotEmpty) c.email!,
                        ].join(' • ')),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_note_rounded,
                                  color: AppColors.navy),
                              onPressed: () => _openForm(client: c),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: AppColors.danger),
                              onPressed: () async {
                                final ok = await _confirmDelete(c);
                                if (ok == true) {
                                  await _db.deleteClient(c.id!);
                                  _reload();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(Client c) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
          'سيتم حذف الموكّل "${c.fullName}" مع جميع قضاياه ومستنداته.\nهل أنت متأكد؟',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
