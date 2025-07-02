class PublicUserModel {
  final String uid;
  final String name;
  final String email;
  final String phoneNumber;
  final String garudId;
  final String status;

  PublicUserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.garudId,
    required this.status,
  });

  factory PublicUserModel.fromMap(Map<String, dynamic> map) {
    return PublicUserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      garudId: map['garudId'] ?? '',
      status: map['status'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'garudId': garudId,
      'status': status,
    };
  }
}
