class OfficeSettings {
  final int? id;
  final String lawyerName;
  final String officeName;
  final String? logoPath;
  final String? phone;
  final String? address;
  final String? license;

  const OfficeSettings({
    this.id = 1,
    this.lawyerName = 'الأستاذ / اسم المحامي',
    this.officeName = 'مكتب المحاماة والاستشارات القانونية',
    this.logoPath,
    this.phone,
    this.address,
    this.license,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'lawyer_name': lawyerName,
        'office_name': officeName,
        'logo_path': logoPath,
        'phone': phone,
        'address': address,
        'license': license,
      };

  factory OfficeSettings.fromMap(Map<String, dynamic> m) => OfficeSettings(
        id: (m['id'] ?? 1) as int,
        lawyerName:
            (m['lawyer_name'] ?? 'الأستاذ / اسم المحامي') as String,
        officeName: (m['office_name'] ??
            'مكتب المحاماة والاستشارات القانونية') as String,
        logoPath: m['logo_path'] as String?,
        phone: m['phone'] as String?,
        address: m['address'] as String?,
        license: m['license'] as String?,
      );

  OfficeSettings copyWith({
    String? lawyerName,
    String? officeName,
    String? logoPath,
    String? phone,
    String? address,
    String? license,
  }) =>
      OfficeSettings(
        id: id,
        lawyerName: lawyerName ?? this.lawyerName,
        officeName: officeName ?? this.officeName,
        logoPath: logoPath ?? this.logoPath,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        license: license ?? this.license,
      );
}
