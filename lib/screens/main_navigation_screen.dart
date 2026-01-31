import 'package:flutter/material.dart';
import 'dart:ui';
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
    try {
      final user = await _authService.getCurrentProfile().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw 'Timeout loading profile',
      );
      
      if (mounted) {
        if (user == null) {
          setState(() => _cachedTabs = []); // Bandera para indicar que terminó pero no hay perfil
        } else {
          setState(() {
            _currentUser = user;
            _initTabs(user);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cachedTabs = []); // Bandera de error/fin
      }
    }
  }

  void _initTabs(UserModel user) {
    _cachedTabs = [
      _TabItem(
        title: 'Inicio',
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        view: _InicioView(
          user: user,
          onOrderTap: (order) {
            final role = user.role;
            if (role == UserRole.admin || role == UserRole.recepcion) {
              final index = _cachedTabs?.indexWhere((t) => t.title == 'Recepción') ?? -1;
              if (index != -1) {
                setState(() => _selectedIndex = index);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _dashboardKey.currentState?.showOrderDetail(order, viewingUser: user);
                });
              }
            } else if (role == UserRole.control_calidad) {
              // Ver detalles menos precio (redirigimos a recepción que ya tiene la lógica)
              final index = _cachedTabs?.indexWhere((t) => t.title == 'Recepción') ?? -1;
              if (index != -1) {
                setState(() => _selectedIndex = index);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _dashboardKey.currentState?.showOrderDetail(order, viewingUser: user);
                });
              }
            } else if (role == UserRole.generador) {
              final index = _cachedTabs?.indexWhere((t) => t.title == 'Generar') ?? -1;
              if (index != -1) setState(() => _selectedIndex = index);
            } else if (role == UserRole.editor) {
              final index = _cachedTabs?.indexWhere((t) => t.title == 'Editar') ?? -1;
              if (index != -1) setState(() => _selectedIndex = index);
            }
          },
        ),
        roles: [UserRole.admin, UserRole.control_calidad, UserRole.recepcion, UserRole.generador, UserRole.editor],
      ),
      _TabItem(
        title: 'Recepción',
        icon: const Icon(Icons.receipt_long_outlined),
        selectedIcon: const Icon(Icons.receipt_long),
        view: DashboardScreen(key: _dashboardKey),
        roles: [UserRole.admin, UserRole.control_calidad, UserRole.recepcion],
      ),
      _TabItem(
        title: 'Calidad',
        icon: const Icon(Icons.high_quality_outlined),
        selectedIcon: const Icon(Icons.high_quality),
        view: const PremiumQCPanel(),
        roles: [UserRole.admin, UserRole.control_calidad],
      ),
      _TabItem(
        title: 'Generar',
        icon: const Icon(Icons.bolt_outlined),
        selectedIcon: const Icon(Icons.bolt),
        view: GeneratorView(currentUser: user),
        roles: [UserRole.admin, UserRole.control_calidad, UserRole.generador],
      ),
      _TabItem(
        title: 'Editar',
        icon: const Icon(Icons.music_note_outlined),
        selectedIcon: const Icon(Icons.music_note),
        view: EditorView(currentUser: user),
        roles: [UserRole.admin, UserRole.control_calidad, UserRole.editor],
      ),
    ].where((tab) {
      final userRoleName = user.role.name.toLowerCase();
      return tab.roles.any((r) => r.name.toLowerCase() == userRoleName);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null || _cachedTabs == null) {
      // Si el caché está vacío pero no es null, significa que falló la carga del perfil
      if (_cachedTabs != null && _cachedTabs!.isEmpty) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
                const SizedBox(height: 16),
                const Text('No se pudo cargar tu perfil de usuario', 
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Verifica tu conexión o reintenta ingresar.', 
                  style: TextStyle(color: Colors.white38)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _authService.signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('CERRAR SESIÓN Y REINTENTAR'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                ),
              ],
            ),
          ),
        );
      }
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

    // Asegurar que el índice no se salga de rango si cambia el rol
    if (_selectedIndex >= userTabs.length) {

      _selectedIndex = 0;
    }

    // Usar nombres para mayor robustez ante Hot Reload y cambios de enum
    final roleName = _currentUser!.role.name.toLowerCase();
    final isAdmin = roleName == 'admin';
    final isQC = roleName == 'control_calidad';
    final isRecepcion = roleName == 'recepcion';

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
          if (isQC || isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Papelera',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Scaffold(
                  appBar: AppBar(title: const Text('Papelera')),
                  body: TrashView(),
                )),
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
                    Image.asset('img/logo.png', height: 40),
                    const SizedBox(height: 20),
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
                      ),
                    ),
                  ],
                ),
              ),
              minWidth: 100, // Menú más ancho
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

enum InicioViewMode { list, planner }

class _InicioView extends StatefulWidget {
  final UserModel user;
  final Function(OrderModel) onOrderTap;
  const _InicioView({required this.user, required this.onOrderTap});

  @override
  State<_InicioView> createState() => _InicioViewState();
}

class _InicioViewState extends State<_InicioView> {
  final OrderService _orderService = OrderService();
  final TextEditingController _searchController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = "";
  InicioViewMode _viewMode = InicioViewMode.planner;
  String _activeFilter = 'TODOS'; // Filtro por métrica (TODOS, URGENTES, LISTOS, ENTREGADOS)
  int _weekOffset = 0; // Desplazamiento por semanas (0 = actual, -1 = pasada, +1 = siguiente)

  final List<String> _days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderModel>>(
      stream: _orderService.ordersStream,
      builder: (context, snapshot) {
        final allOrders = snapshot.data ?? [];
        
        // Métricas
        final today = DateTime.now();
        final ordersToday = allOrders.where((o) => 
          o.createdAt.year == today.year && 
          o.createdAt.month == today.month && 
          o.createdAt.day == today.day).length;
        
        final urgentToday = allOrders.where((o) => 
          o.status != OrderStatus.AUDIO_LISTO && 
          o.status != OrderStatus.ENTREGADO &&
          o.status != OrderStatus.ANULADO &&
          o.deliveryDueAt.difference(o.createdAt).inHours < 24).length;
          
        final deliveredCount = allOrders.where((o) => o.status == OrderStatus.ENTREGADO).length;
        final deliveredToday = allOrders.where((o) => 
          o.status == OrderStatus.AUDIO_LISTO && 
          o.editionEndedAt != null &&
          o.editionEndedAt!.day == today.day).length;

        // Filtrar por día seleccionado (según día de ingreso / createdAt)
        var filteredOrders = allOrders.where((o) {
          final isSameDay = o.createdAt.year == _selectedDate.year &&
                            o.createdAt.month == _selectedDate.month &&
                            o.createdAt.day == _selectedDate.day;
          
          final matchesSearch = o.clientName.toLowerCase().contains(_searchQuery.toLowerCase());
          return isSameDay && matchesSearch;
        }).toList();

        // Aplicar Filtro de Métricas
        if (_activeFilter == 'URGENTES') {
          filteredOrders = filteredOrders.where((o) => 
            o.status != OrderStatus.AUDIO_LISTO && 
            o.status != OrderStatus.ENTREGADO &&
            o.status != OrderStatus.ANULADO &&
            o.deliveryDueAt.difference(o.createdAt).inHours < 24
          ).toList();
        } else if (_activeFilter == 'LISTOS') {
          filteredOrders = filteredOrders.where((o) => o.status == OrderStatus.AUDIO_LISTO).toList();
        } else if (_activeFilter == 'ENTREGADOS') {
          filteredOrders = filteredOrders.where((o) => o.status == OrderStatus.ENTREGADO).toList();
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Hola, ${widget.user.name.isNotEmpty ? widget.user.name.split(' ')[0] : 'Usuario'}',
                              style: TextStyle(
                                fontSize: MediaQuery.of(context).size.width > 800 ? 36 : 28, 
                                fontWeight: FontWeight.bold, 
                                color: Colors.white, 
                                letterSpacing: -0.5
                              ),
                            ),
                            // Selector de Vista
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  _buildViewToggleButton(InicioViewMode.list, Icons.view_headline),
                                  const SizedBox(width: 4),
                                  _buildViewToggleButton(InicioViewMode.planner, Icons.grid_view_rounded),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'Este es el pulso de tu negocio hoy.',
                          style: TextStyle(fontSize: 16, color: Colors.white38),
                        ),
                        const SizedBox(height: 35),
                        
                        // Dashboard Superior (Glassmorphism)
                        if (MediaQuery.of(context).size.width > 800)
                          Row(
                            children: [
                              Expanded(child: _buildMetricCard('Pedidos Hoy', ordersToday.toString(), Icons.analytics_outlined, const Color(0xFF7C3AED), onTap: () => setState(() => _activeFilter = 'TODOS'))),
                              Expanded(child: _buildMetricCard('Urgentes Hoy', urgentToday.toString(), Icons.notification_important_rounded, Colors.orangeAccent, onTap: () => setState(() => _activeFilter = 'URGENTES'))),
                              Expanded(child: _buildMetricCard('Listos Hoy', deliveredToday.toString(), Icons.check_circle_outline, Colors.greenAccent, onTap: () => setState(() => _activeFilter = 'LISTOS'))),
                              Expanded(child: _buildMetricCard('Entregados', deliveredCount.toString(), Icons.handshake_outlined, Colors.yellowAccent, onTap: () => setState(() => _activeFilter = 'ENTREGADOS'))),
                            ],
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildMetricCard('Pedidos Hoy', ordersToday.toString(), Icons.analytics_outlined, const Color(0xFF7C3AED), onTap: () => setState(() => _activeFilter = 'TODOS')),
                                _buildMetricCard('Urgentes Hoy', urgentToday.toString(), Icons.notification_important_rounded, Colors.orangeAccent, onTap: () => setState(() => _activeFilter = 'URGENTES')),
                                _buildMetricCard('Listos Hoy', deliveredToday.toString(), Icons.check_circle_outline, Colors.greenAccent, onTap: () => setState(() => _activeFilter = 'LISTOS')),
                              ],
                            ),
                          ),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
                
                if (_viewMode == InicioViewMode.planner)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Builder(
                                builder: (context) {
                                  final now = DateTime.now();
                                  final monday = now.subtract(Duration(days: now.weekday - 1)).add(Duration(days: _weekOffset * 7));
                                  final sunday = monday.add(const Duration(days: 6));
                                  return Text(
                                    '${DateFormat('dd MMM', 'es').format(monday)} - ${DateFormat('dd MMM', 'es').format(sunday)}'.toUpperCase(),
                                    style: const TextStyle(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                                  );
                                }
                              ),
                              Row(
                                children: [
                                  if (_weekOffset != 0)
                                    TextButton(
                                      onPressed: () => setState(() => _weekOffset = 0),
                                      child: const Text('HOY', style: TextStyle(color: Color(0xFF7C3AED), fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left, color: Colors.white38),
                                    onPressed: () => setState(() => _weekOffset--),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right, color: Colors.white38),
                                    onPressed: () => setState(() => _weekOffset++),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          _buildWeeklyPlanner(allOrders),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // Buscador y Selector en Web pueden ir en una fila
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        children: [
                          if (MediaQuery.of(context).size.width > 800)
                            Row(
                              children: [
                                Expanded(flex: 3, child: _buildSearchBar()),
                                const SizedBox(width: 20),
                                Expanded(flex: 2, child: _buildDaySelector()),
                              ],
                            )
                          else ...[
                            _buildSearchBar(),
                            const SizedBox(height: 25),
                            _buildDaySelector(),
                          ],
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                  
                  // Lista de Pedidos
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: filteredOrders.isEmpty 
                      ? const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: Text('No hay pedidos para este criterio', style: TextStyle(color: Colors.white24))),
                        )
                      : MediaQuery.of(context).size.width > 1000 
                        ? SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisExtent: 100,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 5,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildOrderCard(filteredOrders[index]),
                              childCount: filteredOrders.length,
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildOrderCard(filteredOrders[index]),
                              childCount: filteredOrders.length,
                            ),
                          ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Buscar cliente...',
          hintStyle: TextStyle(color: Colors.white24),
          prefixIcon: Icon(Icons.search, color: Colors.white38),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _days.length,
        itemBuilder: (context, index) {
          final isSelected = index == (_selectedDate.weekday - 1);
          return GestureDetector(
            onTap: () => setState(() => _selectedDate = DateTime.now().add(Duration(days: index - (DateTime.now().weekday - 1)))),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF7C3AED) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: isSelected ? Colors.white24 : Colors.transparent),
              ),
              child: Center(
                child: Text(
                  _days[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white38,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: () {
        if (onTap != null) onTap();
        // Si estamos en planificador y se pulsa una métrica, volver a lista para ver resultados
        if (_viewMode == InicioViewMode.planner) {
          setState(() => _viewMode = InicioViewMode.list);
        }
      },
      child: Container(
        constraints: const BoxConstraints(minWidth: 140),
        margin: const EdgeInsets.only(right: 15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _activeFilter == (title.contains('URGENTE') ? 'URGENTES' : title.contains('LISTO') ? 'LISTOS' : title.contains('ENTREGADO') ? 'ENTREGADOS' : 'TODOS') 
                   ? color.withOpacity(0.3) 
                   : Colors.white.withOpacity(0.05)
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(height: 12),
                  Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1)),
                  const SizedBox(height: 4),
                  Text(
                    title.toUpperCase(), 
                    style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final bool hasScript = (order.scriptText != null && order.scriptText!.isNotEmpty) || 
                           (order.scriptFileUrl != null && order.scriptFileUrl!.isNotEmpty);

    final style = order.statusStyle;
    Color statusColor = style['color'] as Color;
    String statusLabel = style['label'] as String;

    // Solo sobreescribimos si falta texto y no está listo ni entregado
    if (!hasScript && order.status != OrderStatus.AUDIO_LISTO && order.status != OrderStatus.ENTREGADO && order.status != OrderStatus.ANULADO) {
      statusColor = Colors.orangeAccent;
      statusLabel = 'FALTA TEXTO';
    }

    // Caso especial VANEDY (ejemplo basado en nombre o campo si existiera)
    if (order.clientName.toUpperCase().contains('VANEDY')) {
      statusColor = const Color(0xFFFF00FF); // Magenta
      statusLabel = 'VANEDY';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: () => widget.onOrderTap(order),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Indicador lateral de color
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(color: statusColor.withOpacity(0.5), blurRadius: 8, spreadRadius: 1),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.clientName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.product ?? 'Servicio General',
                      style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('HH:mm').format(order.deliveryDueAt),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggleButton(InicioViewMode mode, IconData icon) {
    final isSelected = _viewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white38,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildWeeklyPlanner(List<OrderModel> allOrders) {
    // Calculamos el inicio de la semana (Lunes) según el offset
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1)).add(Duration(days: _weekOffset * 7));
    
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: List.generate(7, (index) {
          final dayDate = monday.add(Duration(days: index));
          final isToday = dayDate.day == now.day && dayDate.month == now.month && dayDate.year == now.year;
          
          final dayOrders = allOrders.where((o) => 
            o.createdAt.day == dayDate.day && 
            o.createdAt.month == dayDate.month && 
            o.createdAt.year == dayDate.year
          ).toList();

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = dayDate;
                  _viewMode = InicioViewMode.list;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: index < 6 ? BorderSide(color: Colors.white.withOpacity(0.05)) : BorderSide.none,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _days[index],
                      style: TextStyle(
                        color: isToday ? const Color(0xFF7C3AED) : Colors.white38,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: dayOrders.map((order) {
                            return Container(
                              width: double.infinity,
                              height: 12,
                              decoration: BoxDecoration(
                                color: order.statusStyle['color'],
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: (order.statusStyle['color'] as Color).withOpacity(0.3),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

