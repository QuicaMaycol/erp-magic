import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dashboard_screen.dart';
import 'users_management_screen.dart';
import '../models/user_model.dart';
import '../models/order_model.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../widgets/premium_qc_panel.dart';
import '../widgets/generator_view.dart';
import '../widgets/editor_view.dart';
import '../widgets/trash_view.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey<DashboardScreenState>();
  List<_TabItem>? _cachedTabs;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _authService.getCurrentProfile();
    if (mounted) {
      setState(() {
        _currentUser = user;
        if (user != null) {
          _initTabs(user);
        }
      });
    }
  }

  void _initTabs(UserModel user) {
    _cachedTabs = [
      _TabItem(
        title: 'Inicio',
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        view: _InicioView(user: user),
        roles: [UserRole.admin, UserRole.qc, UserRole.recepcion, UserRole.generador, UserRole.editor],
      ),
      _TabItem(
        title: 'Recepción',
        icon: const Icon(Icons.receipt_long_outlined),
        selectedIcon: const Icon(Icons.receipt_long),
        view: DashboardScreen(key: _dashboardKey),
        roles: [UserRole.admin, UserRole.qc, UserRole.recepcion],
      ),
      _TabItem(
        title: 'Calidad',
        icon: const Icon(Icons.high_quality_outlined),
        selectedIcon: const Icon(Icons.high_quality),
        view: const PremiumQCPanel(),
        roles: [UserRole.admin, UserRole.qc],
      ),
      _TabItem(
        title: 'Generar',
        icon: const Icon(Icons.bolt_outlined),
        selectedIcon: const Icon(Icons.bolt),
        view: GeneratorView(currentUser: user),
        roles: [UserRole.admin, UserRole.qc, UserRole.generador],
      ),
      _TabItem(
        title: 'Editar',
        icon: const Icon(Icons.music_note_outlined),
        selectedIcon: const Icon(Icons.music_note),
        view: EditorView(currentUser: user),
        roles: [UserRole.admin, UserRole.qc, UserRole.editor],
      ),
      _TabItem(
        title: 'Papelera',
        icon: const Icon(Icons.delete_outline),
        selectedIcon: const Icon(Icons.delete),
        view: TrashView(),
        roles: [UserRole.admin, UserRole.qc],
      ),
    ].where((tab) => tab.roles.contains(user.role)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null || _cachedTabs == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userTabs = _cachedTabs!;
    final size = MediaQuery.of(context).size;
    final isWeb = size.width > 800;

    Widget buildProfileAvatar({double radius = 20, double fontSize = 16}) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF7C3AED),
        child: Text(
          _currentUser?.name.isNotEmpty == true 
              ? _currentUser!.name[0].toUpperCase() 
              : 'U',
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
          ),
        ),
      );
    }

<<<<<<< HEAD
=======
    Widget buildProfileAvatar({double radius = 20, double fontSize = 16}) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF7C3AED),
        child: Text(
          _currentUser?.name.isNotEmpty == true 
              ? _currentUser!.name[0].toUpperCase() 
              : 'U',
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
          ),
        ),
      );
    }

    // Asegurar que el índice no se salga de rango si cambia el rol
>>>>>>> 19588d2 (feat: implementar filtros de estado y ordenamiento en Calidad, Recepción, Generación y Edición)
    if (_selectedIndex >= userTabs.length) {
      _selectedIndex = 0;
    }

    final isAdmin = _currentUser!.role == UserRole.admin;
    final isQC = _currentUser!.role == UserRole.qc;
    final isRecepcion = _currentUser!.role == UserRole.recepcion;

    return Scaffold(
      backgroundColor: const Color(0xFF121216),
      appBar: AppBar(
        leading: !isWeb ? Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Center(child: buildProfileAvatar(radius: 16, fontSize: 12)),
        ) : null,
        title: Text(userTabs[_selectedIndex].title),
        elevation: isWeb ? 1 : 0,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.people_outline),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UsersManagementScreen()),
              ),
            ),
          IconButton(icon: const Icon(Icons.notifications_none_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.logout_outlined), onPressed: () => _authService.signOut()),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (isWeb)
            NavigationRail(
              backgroundColor: const Color(0xFF1B1B21),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  children: [
<<<<<<< HEAD
                    buildProfileAvatar(radius: 32, fontSize: 24),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 120, // Un poco más ancho para el nombre
                      child: Column(
                        children: [
                          Text(
                            _currentUser?.name ?? 'Usuario',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentUser?.role.name.toUpperCase() ?? '',
                            style: const TextStyle(
                              color: Color(0xFF7C3AED),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
=======
                    buildProfileAvatar(radius: 28, fontSize: 22),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 90,
                      child: Text(
                        _currentUser?.name ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
>>>>>>> 19588d2 (feat: implementar filtros de estado y ordenamiento en Calidad, Recepción, Generación y Edición)
                      ),
                    ),
                  ],
                ),
              ),
<<<<<<< HEAD
              minWidth: 100,
=======
              minWidth: 100, // Menú más ancho
>>>>>>> 19588d2 (feat: implementar filtros de estado y ordenamiento en Calidad, Recepción, Generación y Edición)
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
                if (userTabs[index].title == 'Recepción') {
                  _dashboardKey.currentState?.refreshData();
                }
              },
              labelType: NavigationRailLabelType.all,
              indicatorColor: const Color(0xFF7C3AED).withOpacity(0.2),
              unselectedIconTheme: const IconThemeData(color: Colors.white24, size: 28),
              selectedIconTheme: const IconThemeData(color: Color(0xFF7C3AED), size: 28),
              selectedLabelTextStyle: const TextStyle(color: Color(0xFF7C3AED), fontSize: 13, fontWeight: FontWeight.bold),
              unselectedLabelTextStyle: const TextStyle(color: Colors.white24, fontSize: 13),
              destinations: userTabs.map((tab) => NavigationRailDestination(
                icon: tab.icon,
                selectedIcon: tab.selectedIcon,
                label: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(tab.title),
                ),
              )).toList(),
            ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: userTabs.map((tab) => tab.view).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: (userTabs[_selectedIndex].title == 'Recepción' && (isAdmin || isQC || isRecepcion))
          ? FloatingActionButton.extended(
              onPressed: () => _dashboardKey.currentState?.showOrderForm(),
              icon: const Icon(Icons.add),
              label: const Text('Nueva Orden'),
            )
          : null,
      bottomNavigationBar: (!isWeb) 
        ? Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B21),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
              border: const Border(top: BorderSide(color: Colors.white10, width: 0.5)),
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
                if (userTabs[index].title == 'Recepción') {
                  _dashboardKey.currentState?.refreshData();
                }
              },
              destinations: userTabs.map((tab) => NavigationDestination(
                icon: tab.icon,
                selectedIcon: tab.selectedIcon,
                label: tab.title,
              )).toList(),
            ),
          )
        : null,
    );
  }
}

class _TabItem {
  final String title;
  final Widget icon;
  final Widget selectedIcon;
  final Widget view;
  final List<UserRole> roles;

  _TabItem({
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.view,
    required this.roles,
  });
}

class _InicioView extends StatelessWidget {
  final UserModel user;
  const _InicioView({required this.user});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('¡Hola, ${user.name}!', 
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Text(user.role.name.toUpperCase(), 
            style: const TextStyle(fontSize: 12, color: Colors.deepPurpleAccent, letterSpacing: 2)),
          const SizedBox(height: 40),
          const Icon(Icons.assessment_outlined, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          const Text('Resumen de Hoy', style: TextStyle(fontSize: 18, color: Colors.white38)),
        ],
      ),
    );
  }
}

