class Payment {
  final int? id;
  final int caseId;
  final double amount;
  final String paymentDate;
  final String? method;
  final String? notes;
  final String createdAt;

  Payment({
    this.id,
    required this.caseId,
    required this.amount,
    String? paymentDate,
    this.method,
    this.notes,
    String? createdAt,
  })  : paymentDate = paymentDate ?? DateTime.now().toIso8601String(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
        'id': id,
        'case_id': caseId,
        'amount': amount,
        'payment_date': paymentDate,
        'method': method,
        'notes': notes,
        'created_at': createdAt,
      };

  factory Payment.fromMap(Map<String, dynamic> m) => Payment(
        id: m['id'] as int?,
        caseId: (m['case_id'] ?? 0) as int,
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        paymentDate: m['payment_date'] as String?,
        method: m['method'] as String?,
        notes: m['notes'] as String?,
        createdAt: m['created_at'] as String?,
      );
}
