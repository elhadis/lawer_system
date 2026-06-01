import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Owns local file persistence for the system.
/// Every attached document is copied into:
///   {ApplicationDocumentsDirectory}/lawer_system_files/{subfolder}/<unique>_<name>
class FileService {
  FileService._();
  static final FileService instance = FileService._();

  static const _rootFolderName = 'lawer_system_files';

  Future<Directory> _ensureSubdir(String subfolder) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _rootFolderName, subfolder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Lets the user pick a file then copies it into the app documents folder.
  /// Returns null if the user cancels.
  Future<PickedDocument?> pickAndStoreDocument({String subfolder = 'docs'}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.first;
    if (picked.path == null) return null;
    return storeFile(File(picked.path!), subfolder: subfolder);
  }

  Future<PickedDocument> storeFile(
    File source, {
    String subfolder = 'docs',
  }) async {
    final dir = await _ensureSubdir(subfolder);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = p.basename(source.path).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final dest = File(p.join(dir.path, '${stamp}_$safeName'));
    await source.copy(dest.path);
    final size = await dest.length();
    return PickedDocument(
      fileName: safeName,
      localPath: dest.path,
      sizeBytes: size,
    );
  }

  /// Stores raw bytes (e.g. a generated PDF) under the given subfolder.
  Future<File> storeBytes(
    List<int> bytes,
    String fileName, {
    String subfolder = 'pdf',
  }) async {
    final dir = await _ensureSubdir(subfolder);
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<bool> deletePhysicalFile(String path) async {
    final f = File(path);
    if (await f.exists()) {
      await f.delete();
      return true;
    }
    return false;
  }

  /// Lets the user pick an image to use as office logo, copies it locally.
  Future<PickedDocument?> pickAndStoreLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.first;
    if (picked.path == null) return null;
    return storeFile(File(picked.path!), subfolder: 'logo');
  }
}

class PickedDocument {
  final String fileName;
  final String localPath;
  final int? sizeBytes;
  const PickedDocument({
    required this.fileName,
    required this.localPath,
    this.sizeBytes,
  });
}
