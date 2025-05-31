class UserModel {
  final String name;
  final String email;
  final String phoneNumber;
  final String garudId;
  final bool enableAlerts;
  final DateTime createdAt;
  final DateTime lastLogin;
  final String status;

  UserModel({
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.garudId,
    required this.enableAlerts,
    required this.createdAt,
    required this.lastLogin,
    required this.status,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      garudId: map['garudId'] ?? '',
      enableAlerts: map['enableAlerts'] ?? false,
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      lastLogin: map['lastLogin']?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'inactive',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'garudId': garudId,
      'enableAlerts': enableAlerts,
      'createdAt': createdAt,
      'lastLogin': lastLogin,
      'status': status,
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? phoneNumber,
    String? garudId,
    bool? enableAlerts,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? status,
  }) {
    return UserModel(
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      garudId: garudId ?? this.garudId,
      enableAlerts: enableAlerts ?? this.enableAlerts,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      status: status ?? this.status,
    );
  }
}