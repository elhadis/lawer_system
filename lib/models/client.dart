class Client {
  final int? id;
  final String fullName;
  final String? nationalId;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final String createdAt;

  Client({
    this.id,
    required this.fullName,
    this.nationalId,
    this.phone,
    this.email,
    this.address,
    this.notes,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
        'id': id,
        'full_name': fullName,
        'national_id': nationalId,
        'phone': phone,
        'email': email,
        'address': address,
        'notes': notes,
        'created_at': createdAt,
      };

  factory Client.fromMap(Map<String, dynamic> m) => Client(
        id: m['id'] as int?,
        fullName: (m['full_name'] ?? '') as String,
        nationalId: m['national_id'] as String?,
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        address: m['address'] as String?,
        notes: m['notes'] as String?,
        createdAt: m['created_at'] as String?,
      );

  Client copyWith({
    int? id,
    String? fullName,
    String? nationalId,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) =>
      Client(
        id: id ?? this.id,
        fullName: fullName ?? this.fullName,
        nationalId: nationalId ?? this.nationalId,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}
