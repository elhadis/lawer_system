import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../db/database_helper.dart';
import '../../models/attachment.dart';
import '../../models/contract.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../common/empty_state.dart';
import '../common/money.dart';
import 'certification_workspace_screen.dart';
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
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ContractBuilderScreen()),
    );
    if (saved == true) _reload();
  }

  Future<void> _newCertification() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CertificationWorkspaceScreen()),
    );
    if (saved == true) _reload();
  }

  Future<void> _edit(Contract c) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => c.isCertification
            ? CertificationWorkspaceScreen(initial: c)
            : ContractBuilderScreen(initial: c),
      ),
    );
    if (saved == true) _reload();
  }

  Future<void> _print(Contract c) async {
    final bytes = c.isCertification
        ? await PdfService.instance.buildCertificationPdf(
            title: c.title,
            body: c.body,
          )
        : await () async {
            final settings = await _db.getSettings();
            final client = c.clientId == null
                ? null
                : await _db.getClient(c.clientId!);
            final legalCase = c.caseId == null
                ? null
                : await _db.getCase(c.caseId!);
            return PdfService.instance.buildContractPdf(
              settings: settings,
              contract: c,
              client: client,
              legalCase: legalCase,
            );
          }();
    await PdfService.instance.exportPdf(
      bytes,
      fileName: '${c.title}.pdf',
      jobName: c.title,
      shareText: c.title,
    );
  }

  Future<void> _uploadDocument() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    if (picked.path == null) return;

    final source = File(picked.path!);
    if (!await source.exists()) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final contractsDocsDir = Directory(
      p.join(docsDir.path, 'contracts_documents'),
    );
    if (!await contractsDocsDir.exists()) {
      await contractsDocsDir.create(recursive: true);
    }

    final extension = p.extension(source.path);
    final sanitizedBaseName =
        p.basenameWithoutExtension(picked.name).trim().isEmpty
        ? 'document'
        : p.basenameWithoutExtension(picked.name).trim();
    final uniqueName =
        '${DateTime.now().millisecondsSinceEpoch}_$sanitizedBaseName$extension';
    final destinationPath = p.join(contractsDocsDir.path, uniqueName);

    final copiedFile = await source.copy(destinationPath);
    final sizeBytes = await copiedFile.length();

    await _db.insertAttachment(
      Attachment(
        fileName: picked.name,
        localPath: destinationPath,
        sizeBytes: sizeBytes,
        mimeType: _guessMimeType(extension),
      ),
    );

    await _db.insertContract(
      Contract(
        title: picked.name,
        body: _uploadedDocumentBody(destinationPath),
      ),
    );

    _reload();
  }

  String _uploadedDocumentBody(String path) => 'مرفق مستند محلي|$path';

  bool _isUploadedDocumentContract(Contract c) {
    return !c.isCertification && c.body.startsWith('مرفق مستند محلي');
  }

  String? _extractUploadedPath(Contract c) {
    if (!_isUploadedDocumentContract(c)) return null;
    final parts = c.body.split('|');
    if (parts.length >= 2 && parts[1].trim().isNotEmpty) {
      return parts[1].trim();
    }
    return null;
  }

  bool _isImageExtension(String extension) {
    final ext = extension.toLowerCase();
    return ext == '.png' || ext == '.jpg' || ext == '.jpeg';
  }

  Future<void> _showImagePreview(String path, String title) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            insetPadding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black12)),
                  ),
                  child: Text(
                    title,
                    textAlign: TextAlign.start,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Flexible(
                  child: InteractiveViewer(
                    child: Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('تعذر عرض الصورة'),
                        );
                      },
                    ),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('إغلاق'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openUploadedDocument(Contract c) async {
    try {
      String? path = _extractUploadedPath(c);

      if (path == null || path.isEmpty) {
        final attachments = await _db.getAttachments();
        final matchedByName = attachments
            .where((a) => a.fileName == c.title && a.localPath.isNotEmpty)
            .toList();
        if (matchedByName.isNotEmpty) {
          path = matchedByName.first.localPath;
        }
      }

      if (path == null || path.trim().isEmpty) {
        throw Exception('Empty path');
      }

      final normalizedPath = path.trim();
      final file = File(normalizedPath);
      if (!await file.exists()) {
        throw Exception('File missing');
      }

      final extension = p.extension(normalizedPath).toLowerCase();
      if (_isImageExtension(extension)) {
        if (!mounted) return;
        await _showImagePreview(normalizedPath, c.title);
        return;
      }

      final result = await OpenFilex.open(normalizedPath);
      if (result.type != ResultType.done) {
        throw Exception('Open failed');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عذراً، تعذر فتح هذا الملف أو المسار غير موجود.'),
        ),
      );
    }
  }

  String? _guessMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case '.pdf':
        return 'application/pdf';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Contract>>(
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
                        'استخدم منشئ العقود أو التوثيقات لصياغة وحفظ وطباعة المستندات القانونية.',
                    action: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _new,
                          icon: const Icon(Icons.note_add_rounded),
                          label: const Text('عقد جديد'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _newCertification,
                          icon: const Icon(Icons.verified_rounded),
                          label: const Text('توثيق جديد'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _uploadDocument,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('تحميل وثائق'),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: list.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final c = list[i];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: InkWell(
                        onTap: () {
                          if (_isUploadedDocumentContract(c)) {
                            _openUploadedDocument(c);
                            return;
                          }
                          _edit(c);
                        },
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.navy.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              c.isCertification
                                  ? Icons.verified_rounded
                                  : Icons.description_rounded,
                              color: AppColors.navy,
                            ),
                          ),
                          title: Text(
                            c.title,
                            textAlign: TextAlign.start,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [
                              c.isCertification
                                  ? 'توثيق'
                                  : _isUploadedDocumentContract(c)
                                  ? 'مستند مرفوع'
                                  : 'عقد',
                              formatDate(c.contractDate),
                              if (!c.isCertification && c.amount > 0)
                                '${formatMoney(c.amount)} ر.س',
                            ].join(' • '),
                            textAlign: TextAlign.start,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isUploadedDocumentContract(c))
                                IconButton(
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    color: AppColors.navy,
                                  ),
                                  tooltip: 'عرض',
                                  onPressed: () => _openUploadedDocument(c),
                                )
                              else
                                IconButton(
                                  icon: const Icon(
                                    Icons.print_rounded,
                                    color: AppColors.navy,
                                  ),
                                  tooltip: 'طباعة',
                                  onPressed: () => _print(c),
                                ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.danger,
                                ),
                                onPressed: () async {
                                  await _db.deleteContract(c.id!);
                                  _reload();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _new,
                      icon: const Icon(Icons.note_add_rounded),
                      label: const Text('عقد جديد'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _newCertification,
                      icon: const Icon(Icons.verified_rounded),
                      label: const Text('توثيق جديد'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _uploadDocument,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('تحميل وثائق'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
