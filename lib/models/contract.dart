class Contract {
  final int? id;
  final int? clientId;
  final int? caseId;
  final String title;
  final String body;
  final double amount;
  final String contractDate;
  final String createdAt;
  final bool isCertification;

  Contract({
    this.id,
    this.clientId,
    this.caseId,
    required this.title,
    required this.body,
    this.amount = 0,
    this.isCertification = false,
    String? contractDate,
    String? createdAt,
  }) : contractDate = contractDate ?? DateTime.now().toIso8601String(),
       createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
    'id': id,
    'client_id': clientId,
    'case_id': caseId,
    'title': title,
    'body': body,
    'amount': amount,
    'contract_date': contractDate,
    'created_at': createdAt,
    'is_certification': isCertification ? 1 : 0,
  };

  factory Contract.fromMap(Map<String, dynamic> m) => Contract(
    id: m['id'] as int?,
    clientId: m['client_id'] as int?,
    caseId: m['case_id'] as int?,
    title: (m['title'] ?? '') as String,
    body: (m['body'] ?? '') as String,
    amount: (m['amount'] as num?)?.toDouble() ?? 0,
    isCertification: ((m['is_certification'] as num?)?.toInt() ?? 0) == 1,
    contractDate: m['contract_date'] as String?,
    createdAt: m['created_at'] as String?,
  );

  Contract copyWith({
    int? id,
    int? clientId,
    int? caseId,
    String? title,
    String? body,
    double? amount,
    String? contractDate,
    bool? isCertification,
  }) => Contract(
    id: id ?? this.id,
    clientId: clientId ?? this.clientId,
    caseId: caseId ?? this.caseId,
    title: title ?? this.title,
    body: body ?? this.body,
    amount: amount ?? this.amount,
    contractDate: contractDate ?? this.contractDate,
    createdAt: createdAt,
    isCertification: isCertification ?? this.isCertification,
  );
}
