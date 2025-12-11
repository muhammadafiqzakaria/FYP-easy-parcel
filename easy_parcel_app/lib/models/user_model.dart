class User {
  final String id;  
  final String email;
  final String name;
  final String role;
  final String phoneNumber;

  const User({
    required this.id, 
    required this.email,
    required this.name,
    required this.role,
    required this.phoneNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,  
      'email': email,
      'name': name,
      'role': role,
      'phoneNumber': phoneNumber,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '', 
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
    );
  }
}