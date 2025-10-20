class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'student' or 'courier'
  final String phoneNumber;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.phoneNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'phoneNumber': phoneNumber,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
    );
  }
}