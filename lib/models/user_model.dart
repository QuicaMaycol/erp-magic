enum UserRole {
  admin,
  control_calidad,
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
  final bool confirmed;

  UserModel({
    required this.id,
    required this.email,
    required this.role,
    required this.name,
    required this.active,
    this.confirmed = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      role: _parseRole(json['role']),
      name: json['full_name'] ?? json['name'] ?? '',
      active: json['active'] ?? true,
      confirmed: json['confirmed'] ?? (json['email_confirmed_at'] != null),
    );
  }

  static UserRole _parseRole(String? roleName) {
    if (roleName == null) return UserRole.recepcion;
    final normalized = roleName.toLowerCase();
    
    // Mapeo especial para compatibilidad si viene como 'qc'
    if (normalized == 'qc') return UserRole.control_calidad;
    
    try {
      return UserRole.values.firstWhere(
        (e) => e.name.toLowerCase() == normalized,
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
      'confirmed': confirmed,
    };
  }
}
