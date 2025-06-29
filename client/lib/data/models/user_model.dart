import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phoneNumber;
  final String garudId;
  final bool enableAlerts;
  final DateTime createdAt;
  final DateTime lastLogin;
  final String status;
  final List<String> guardians;
  final List<String> proteges;
  final String? token;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.garudId,
    required this.enableAlerts,
    required this.createdAt,
    required this.lastLogin,
    required this.status,
    required this.guardians,
    required this.proteges,
    this.token,
  });

  /// Factory constructor to create UserModel from DocumentSnapshot
  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    return UserModel(
      uid: doc.id,
      name: data?['name'] ?? '',
      email: data?['email'] ?? '',
      phoneNumber: data?['phoneNumber'] ?? '',
      garudId: data?['garudId'] ?? '',
      enableAlerts: data?['enableAlerts'] ?? false,
      createdAt: (data?['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogin: (data?['lastLogin'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data?['status'] ?? 'inactive',
      guardians: List<String>.from(data?['guardians'] ?? []),
      proteges: List<String>.from(data?['proteges'] ?? []),
      token: data?['token'],
    );
  }

  /// Convert model to Firestore map
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
      'guardians': guardians,
      'proteges': proteges,
      'token': token,
    };
  }

  /// Create a modified copy of the current user model
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phoneNumber,
    String? garudId,
    bool? enableAlerts,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? status,
    List<String>? guardians,
    List<String>? proteges,
    String? token,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      garudId: garudId ?? this.garudId,
      enableAlerts: enableAlerts ?? this.enableAlerts,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      status: status ?? this.status,
      guardians: guardians ?? this.guardians,
      proteges: proteges ?? this.proteges,
      token: token ?? this.token,
    );
  }
}
