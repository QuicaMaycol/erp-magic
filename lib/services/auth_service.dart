import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../supabase_config.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  // Obtener el perfil del usuario actual desde el esquema erp_magicvoice
  Future<UserModel?> getCurrentProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final data = await _supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .single();

    return UserModel.fromJson(data);
  }

  // Iniciar sesión
  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Crear nuevo usuario (Solo para Admin)
  Future<AuthResponse> createNewUser({
    required String email,
    required String password,
    required String role,
    required String name,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'sistema': 'erp_magicvoice',
        'role': role,
        'full_name': name,
      },
    );
  }

  // Obtener todos los usuarios (Solo para Admin)
  Future<List<UserModel>> getAllUsers() async {
    final data = await _supabase
        .from('users')
        .select()
        .order('role', ascending: true);
    
    return (data as List).map((json) => UserModel.fromJson(json)).toList();
  }

  // Actualizar un usuario
  Future<void> updateUser(String id, Map<String, dynamic> updates) async {
    await _supabase
        .from('users')
        .update(updates)
        .eq('id', id);
  }

  // Eliminar usuario de la tabla
  Future<void> deleteUser(String id) async {
    await _supabase
        .from('users')
        .delete()
        .eq('id', id);
  }

  // Obtener usuarios por rol (Para asignaciones de QC)
  Future<List<UserModel>> getUsersByRole(UserRole role) async {
    final data = await _supabase
        .from('users')
        .select()
        .eq('role', role.name)
        .eq('active', true);
    
    return (data as List).map((json) => UserModel.fromJson(json)).toList();
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Stream del estado de autenticación
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}
