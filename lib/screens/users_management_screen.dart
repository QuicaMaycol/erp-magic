import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final AuthService _authService = AuthService();
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _authService.getAllUsers();
      setState(() => _users = users);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar usuarios: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    UserRole selectedRole = UserRole.editor;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1B1B21),
          title: const Text('Crear Nuevo Usuario', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Nombre Completo', labelStyle: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Correo Electrónico', labelStyle: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña', labelStyle: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<UserRole>(
                  dropdownColor: const Color(0xFF1B1B21),
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Rol', labelStyle: TextStyle(color: Colors.white70)),
                  style: const TextStyle(color: Colors.white),
                  items: UserRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedRole = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (nameController.text.isEmpty || emailController.text.isEmpty || passwordController.text.isEmpty) {
                  return;
                }
                setDialogState(() => isSaving = true);
                try {
                  await _authService.createNewUser(
                    email: emailController.text.trim(),
                    password: passwordController.text.trim(),
                    role: selectedRole.name,
                    name: nameController.text.trim(),
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    _loadUsers();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Usuario creado con éxito'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al crear usuario: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
              child: isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('CREAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(UserModel user) {
    final nameController = TextEditingController(text: user.name);
    UserRole selectedRole = user.role;
    bool isActive = user.active;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1B1B21),
          title: Text('Editar Usuario: ${user.name}', style: const TextStyle(color: Colors.white, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nombre Completo',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                dropdownColor: const Color(0xFF1B1B21),
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Cambiar Rol', labelStyle: TextStyle(color: Colors.white70)),
                style: const TextStyle(color: Colors.white),
                items: UserRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) => setDialogState(() => selectedRole = val!),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Usuario Activo', style: TextStyle(color: Colors.white)),
                value: isActive,
                activeColor: const Color(0xFF7C3AED),
                onChanged: (val) => setDialogState(() => isActive = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (nameController.text.isEmpty) return;
                setDialogState(() => isSaving = true);
                try {
                  await _authService.updateUser(user.id, {
                    'name': nameController.text.trim(),
                    'role': selectedRole.name,
                    'active': isActive,
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    _loadUsers();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Usuario actualizado con éxito'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al actualizar usuario: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
              child: isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121216),
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        backgroundColor: const Color(0xFF16161A),
        actions: [
          IconButton(onPressed: _loadUsers, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              return Card(
                color: const Color(0xFF1B1B21),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF7C3AED).withOpacity(0.2),
                    child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U', 
                      style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold)),
                  ),
                  title: Text(user.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.email, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getRoleColor(user.role).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _getRoleColor(user.role).withOpacity(0.3)),
                            ),
                            child: Text(user.role.name.toUpperCase(), 
                              style: TextStyle(color: _getRoleColor(user.role), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          if (!user.confirmed) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: const Text("PENDIENTE", 
                                style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(user.active ? Icons.check_circle : Icons.cancel, 
                        color: user.active ? Colors.greenAccent : Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white70),
                        onPressed: () => _showEditUserDialog(user),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        backgroundColor: const Color(0xFF7C3AED),
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin: return Colors.redAccent;
      case UserRole.control_calidad: return Colors.orangeAccent;
      case UserRole.recepcion: return Colors.blueAccent;
      case UserRole.generador: return Colors.greenAccent;
      case UserRole.editor: return Colors.purpleAccent;
      default: return Colors.grey;
    }
  }
}
