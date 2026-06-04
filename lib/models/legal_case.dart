enum CaseType { criminal, civil, family }

extension CaseTypeX on CaseType {
  String get nameAr {
    switch (this) {
      case CaseType.criminal:
        return 'قضية جنائية';
      case CaseType.civil:
        return 'قضية مدنية';
      case CaseType.family:
        return 'أحوال شخصية';
    }
  }
}

class LegalCase {
  static const String statusOpen = 'مفتوحة';
  static const String statusInProgress = 'قيد النظر';
  static const String statusClosed = 'مغلقة';
  static const String statusJudged = 'صدر فيها حكم';

  final int? id;
  final int clientId;
  final String caseNumber;
  final String title;
  final String? courtName;
  final CaseType? caseType;
  final String? opponent;
  final String status;
  final double fees;
  final double paid;
  final String? nextSessionDate;
  final String? notes;
  final String createdAt;

  LegalCase({
    this.id,
    required this.clientId,
    required this.caseNumber,
    required this.title,
    this.courtName,
    this.caseType,
    this.opponent,
    this.status = statusOpen,
    this.fees = 0,
    this.paid = 0,
    this.nextSessionDate,
    this.notes,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  double get outstanding => (fees - paid).clamp(0, double.infinity);

  Map<String, dynamic> toMap() => {
    'id': id,
    'client_id': clientId,
    'case_number': caseNumber,
    'title': title,
    'court_name': courtName,
    'case_type': caseType?.name,
    'opponent': opponent,
    'status': status,
    'fees': fees,
    'paid': paid,
    'next_session_date': nextSessionDate,
    'notes': notes,
    'created_at': createdAt,
  };

  factory LegalCase.fromMap(Map<String, dynamic> m) => LegalCase(
    id: m['id'] as int?,
    clientId: (m['client_id'] ?? 0) as int,
    caseNumber: (m['case_number'] ?? '') as String,
    title: (m['title'] ?? '') as String,
    courtName: m['court_name'] as String?,
    caseType: _caseTypeFromDb(m['case_type']),
    opponent: m['opponent'] as String?,
    status: (m['status'] ?? statusOpen) as String,
    fees: (m['fees'] as num?)?.toDouble() ?? 0,
    paid: (m['paid'] as num?)?.toDouble() ?? 0,
    nextSessionDate: m['next_session_date'] as String?,
    notes: m['notes'] as String?,
    createdAt: m['created_at'] as String?,
  );

  LegalCase copyWith({
    int? id,
    int? clientId,
    String? caseNumber,
    String? title,
    String? courtName,
    CaseType? caseType,
    String? opponent,
    String? status,
    double? fees,
    double? paid,
    String? nextSessionDate,
    String? notes,
  }) => LegalCase(
    id: id ?? this.id,
    clientId: clientId ?? this.clientId,
    caseNumber: caseNumber ?? this.caseNumber,
    title: title ?? this.title,
    courtName: courtName ?? this.courtName,
    caseType: caseType ?? this.caseType,
    opponent: opponent ?? this.opponent,
    status: status ?? this.status,
    fees: fees ?? this.fees,
    paid: paid ?? this.paid,
    nextSessionDate: nextSessionDate ?? this.nextSessionDate,
    notes: notes ?? this.notes,
    createdAt: createdAt,
  );
}

CaseType _caseTypeFromDb(dynamic raw) {
  if (raw is String && raw.trim().isNotEmpty) {
    for (final value in CaseType.values) {
      if (value.name == raw) return value;
    }
  }
  return CaseType.civil;
}
