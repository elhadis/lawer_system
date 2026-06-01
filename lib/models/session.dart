class CaseSession {
  static const String statusPending = 'قيد الانتظار';
  static const String statusHeld = 'منعقدة';
  static const String statusAdjourned = 'مؤجلة';
  static const String statusCancelled = 'ملغاة';

  final int? id;
  final int caseId;
  final String sessionDate;
  final String? notes;
  final String? decision;
  final String status;
  final String createdAt;

  CaseSession({
    this.id,
    required this.caseId,
    required this.sessionDate,
    this.notes,
    this.decision,
    this.status = statusPending,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
        'id': id,
        'case_id': caseId,
        'session_date': sessionDate,
        'notes': notes,
        'decision': decision,
        'status': status,
        'created_at': createdAt,
      };

  factory CaseSession.fromMap(Map<String, dynamic> m) => CaseSession(
        id: m['id'] as int?,
        caseId: (m['case_id'] ?? 0) as int,
        sessionDate: (m['session_date'] ?? '') as String,
        notes: m['notes'] as String?,
        decision: m['decision'] as String?,
        status: (m['status'] ?? statusPending) as String,
        createdAt: m['created_at'] as String?,
      );

  CaseSession copyWith({
    int? id,
    int? caseId,
    String? sessionDate,
    String? notes,
    String? decision,
    String? status,
  }) =>
      CaseSession(
        id: id ?? this.id,
        caseId: caseId ?? this.caseId,
        sessionDate: sessionDate ?? this.sessionDate,
        notes: notes ?? this.notes,
        decision: decision ?? this.decision,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}
