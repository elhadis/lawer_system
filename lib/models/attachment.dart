class Attachment {
  final int? id;
  final int? clientId;
  final int? caseId;
  final String fileName;
  final String localPath;
  final String? mimeType;
  final int? sizeBytes;
  final String createdAt;

  Attachment({
    this.id,
    this.clientId,
    this.caseId,
    required this.fileName,
    required this.localPath,
    this.mimeType,
    this.sizeBytes,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
        'id': id,
        'client_id': clientId,
        'case_id': caseId,
        'file_name': fileName,
        'local_path': localPath,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
        'created_at': createdAt,
      };

  factory Attachment.fromMap(Map<String, dynamic> m) => Attachment(
        id: m['id'] as int?,
        clientId: m['client_id'] as int?,
        caseId: m['case_id'] as int?,
        fileName: (m['file_name'] ?? '') as String,
        localPath: (m['local_path'] ?? '') as String,
        mimeType: m['mime_type'] as String?,
        sizeBytes: m['size_bytes'] as int?,
        createdAt: m['created_at'] as String?,
      );
}
