enum UserRole {
  admin,
  qc,
  recepcion,
  generador,
  editor,
}

class UserModel {
  final String id;
  final String email;
  final UserRole role;
  final String name;
  final bool active;

  UserModel({
    required this.id,
    required this.email,
    required this.role,
    required this.name,
    required this.active,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      role: _parseRole(json['role']),
      name: json['full_name'] ?? json['name'] ?? '',
      active: json['active'] ?? true,
    );
  }

  static UserRole _parseRole(String? roleName) {
    if (roleName == null) return UserRole.recepcion;
    try {
      return UserRole.values.firstWhere(
        (e) => e.name.toLowerCase() == roleName.toLowerCase(),
        orElse: () => UserRole.recepcion,
      );
    } catch (_) {
      return UserRole.recepcion;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role.name,
      'name': name,
      'active': active,
    };
  }
}
