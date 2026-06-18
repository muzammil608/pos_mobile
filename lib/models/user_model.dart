class UserModel {
  final String id;
  final String email;
  final String role;
  final String? adminId;
  final bool isActive;
  final String? name;
  final String? photoUrl;

  UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.adminId,
    this.isActive = true,
    this.name,
    this.photoUrl,
  });

  String get effectiveAdminId => role == 'admin' ? id : (adminId ?? id);

  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      email: data['email'] ?? '',
      role: data['role'] ?? 'cashier',
      adminId: data['adminId'],
      isActive: data['isActive'] ?? true,
      name: data['name'],
      photoUrl: data['photoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'isActive': isActive,
      if (adminId != null) 'adminId': adminId,
      if (name != null) 'name': name,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };
  }
}
