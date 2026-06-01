import 'package:flutter/material.dart';

import '../../db/database_helper.dart';
import '../../models/contract.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../common/empty_state.dart';
import '../common/money.dart';
import 'contract_builder_screen.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  final _db = DatabaseHelper.instance;
  late Future<List<Contract>> _future;

  @override
  void initState() {
    super.initState();
    _future = _db.getContracts();
  }

  void _reload() {
    setState(() {
      _future = _db.getContracts();
    });
  }

  Future<void> _new() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const ContractBuilderScreen(),
    ));
    if (saved == true) _reload();
  }

  Future<void> _edit(Contract c) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ContractBuilderScreen(initial: c),
    ));
    if (saved == true) _reload();
  }

  Future<void> _print(Contract c) async {
    final settings = await _db.getSettings();
    final client = c.clientId == null ? null : await _db.getClient(c.clientId!);
    final legalCase =
        c.caseId == null ? null : await _db.getCase(c.caseId!);
    final bytes = await PdfService.instance.buildContractPdf(
      settings: settings,
      contract: c,
      client: client,
      legalCase: legalCase,
    );
    await PdfService.instance.exportPdf(
      bytes,
      fileName: '${c.title}.pdf',
      jobName: c.title,
      shareText: c.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _new,
        icon: const Icon(Icons.note_add_rounded),
        label: const Text('عقد جديد'),
      ),
      body: FutureBuilder<List<Contract>>(
        future: _future,
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.description_rounded,
              title: 'لا توجد عقود محفوظة',
              message:
                  'استخدم منشئ العقود لصياغة وحفظ وطباعة العقود القانونية بشعار المكتب.',
              action: ElevatedButton.icon(
                onPressed: _new,
                icon: const Icon(Icons.note_add_rounded),
                label: const Text('عقد جديد'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final c = list[i];
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  onTap: () => _edit(c),
                  leading: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.description_rounded,
                        color: AppColors.navy),
                  ),
                  title: Text(c.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([
                    formatDate(c.contractDate),
                    if (c.amount > 0) '${formatMoney(c.amount)} ر.س',
                  ].join(' • ')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.print_rounded,
                            color: AppColors.navy),
                        tooltip: 'طباعة',
                        onPressed: () => _print(c),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.danger),
                        onPressed: () async {
                          await _db.deleteContract(c.id!);
                          _reload();
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
    );
  }
}
