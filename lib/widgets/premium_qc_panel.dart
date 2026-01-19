import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/order_service.dart';
import '../services/auth_service.dart';
import 'qc_order_card.dart'; // Nueva tarjeta especializada

class PremiumQCPanel extends StatefulWidget {
  const PremiumQCPanel({super.key});

  @override
  State<PremiumQCPanel> createState() => _PremiumQCPanelState();
}

class _PremiumQCPanelState extends State<PremiumQCPanel> {
  final OrderService _orderService = OrderService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  
  List<UserModel> _generators = [];
  List<UserModel> _editors = [];
  String _searchQuery = '';
  OrderStatus? _statusFilter;
  bool _sortByDelivery = false; // false = createdAt DESC, true = deliveryDueAt ASC

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final gens = await _authService.getUsersByRole(UserRole.generador);
    final eds = await _authService.getUsersByRole(UserRole.editor);
    if (mounted) {
      setState(() {
        _generators = gens;
        _editors = eds;
      });
    }
  }

  void _showDownloadOptions(String? url, String title) {
    if (url == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B21),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Descargar $title', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open, color: Colors.blueAccent),
              title: const Text('Explorador de Archivos', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Guardar en este dispositivo', style: TextStyle(color: Colors.white38, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _orderService.openUrl(url);
              },
            ),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.add_to_drive, color: Colors.greenAccent),
              title: const Text('Google Drive', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Subir a mi unidad de Drive', style: TextStyle(color: Colors.white38, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                // Abrimos la URL; en dispositivos con Drive instalado, el sistema suele preguntar o permitir guardarlo allí.
                _orderService.openUrl(url); 
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Abriendo archivo para guardar en Drive...'), backgroundColor: Colors.blueGrey)
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignmentDialog(OrderModel order) {
    UserModel? selectedGen = _generators.firstWhere((u) => u.id == order.generatorId, orElse: () => _generators.isNotEmpty ? _generators.first : UserModel(id: '', name: '', email: '', role: UserRole.generador));
    UserModel? selectedEd = _editors.firstWhere((u) => u.id == order.editorId, orElse: () => _editors.isNotEmpty ? _editors.first : UserModel(id: '', name: '', email: '', role: UserRole.editor));
    
    String? tempGenId = order.generatorId;
    String? tempEdId = order.editorId;
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF16161A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Gestionar Pedido #${order.id}', 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info del Cliente y Pedido
                  _buildDetailRow("CLIENTE", order.clientName),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                       Expanded(child: _buildDetailRow("INGRESO", DateFormat('dd/MM - HH:mm').format(order.createdAt))),
                       const SizedBox(width: 16),
                       Expanded(child: _buildDetailRow("ENTREGA", DateFormat('dd/MM - HH:mm').format(order.deliveryDueAt))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Texto / Guion
                  const Text("TEXTO / GUION", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      (order.scriptText != null && order.scriptText!.isNotEmpty) ? order.scriptText! : "Sin texto especificado", 
                      style: TextStyle(
                        color: (order.scriptText != null && order.scriptText!.isNotEmpty) ? Colors.white70 : Colors.white24, 
                        fontSize: 13,
                      ), 
                      maxLines: 6, 
                      overflow: TextOverflow.ellipsis
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // Audio Final (SI EXISTE)
                  if (order.finalAudioUrl != null) ...[
                    const Text("AUDIO FINAL CARGADO", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _orderService.openUrl(order.finalAudioUrl),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text("Descargar Audio Final"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent.withOpacity(0.1), 
                        foregroundColor: Colors.blueAccent,
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.blueAccent)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Archivo Adjunto
                  const Text("ARCHIVO ADJUNTO", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  if (order.scriptFileUrl != null && order.scriptFileUrl!.isNotEmpty)
<<<<<<< HEAD
                    ElevatedButton.icon(
                      onPressed: () => _orderService.openUrl(order.scriptFileUrl),
                      icon: const Icon(Icons.file_present_rounded),
                      label: const Text("Ver Documento Adjunto"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2A2A35), 
                        foregroundColor: Colors.blueAccent,
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        alignment: Alignment.centerLeft,
                      ),
=======
                    Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _orderService.openUrl(order.scriptFileUrl),
                          icon: const Icon(Icons.file_present_rounded),
                          label: const Text("Ver Documento Adjunto (PDF/Word)"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2A2A35), 
                            foregroundColor: Colors.blueAccent,
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 45),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.blueAccent.withOpacity(0.3))),
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _showDownloadOptions(order.scriptFileUrl, "Documento Adjunto"),
                          icon: const Icon(Icons.download_for_offline_outlined, color: Colors.blueAccent),
                          label: const Text("Descargar Documento"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blueAccent,
                            side: BorderSide(color: Colors.blueAccent.withOpacity(0.5)),
                            minimumSize: const Size(double.infinity, 45),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
>>>>>>> 19588d2 (feat: implementar filtros de estado y ordenamiento en Calidad, Recepción, Generación y Edición)
                    )
                  else
                    const Text("No hay archivo adjunto", style: TextStyle(color: Colors.white24, fontSize: 13, fontStyle: FontStyle.italic)),

                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 20),

                  // SECCIÓN DE AUDIOS (Si existen)
                  if (order.baseAudioUrl != null || order.finalAudioUrl != null) ...[
                    const Text("AUDIOS DISPONIBLES", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    
                    if (order.baseAudioUrl != null) ...[
                      const Text("LOCUCIÓN BASE", style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _orderService.openUrl(order.baseAudioUrl),
                              icon: const Icon(Icons.play_circle_fill),
                              label: const Text("Escuchar"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.withOpacity(0.1), foregroundColor: Colors.amber),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showDownloadOptions(order.baseAudioUrl, "Locución Base"),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text("Descargar"),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.amber, side: BorderSide(color: Colors.amber.withOpacity(0.5))),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (order.finalAudioUrl != null) ...[
                      const Text("PRODUCTO FINAL (EDITADO)", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _orderService.openUrl(order.finalAudioUrl),
                              icon: const Icon(Icons.play_circle_fill),
                              label: const Text("Escuchar"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent.withOpacity(0.1), foregroundColor: Colors.blueAccent),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showDownloadOptions(order.finalAudioUrl, "Producto Final"),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text("Descargar"),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.blueAccent, side: BorderSide(color: Colors.blueAccent.withOpacity(0.5))),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 20),
                  ],

                  // Asignación
                  const Text("ASIGNACIÓN DE PERSONAL", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  
<<<<<<< HEAD
                  _buildDropdown("Generador", _generators, tempGenId, (val) => setDialogState(() => tempGenId = val)),
                  const SizedBox(height: 12),
                  _buildDropdown("Editor", _editors, tempEdId, (val) => setDialogState(() => tempEdId = val)),
=======
                  // Dropdown Generador
                  _buildDropdown("Generador", _generators, tempGenId, (val) => setDialogState(() => tempGenId = val), 
                    enabled: (order.status == OrderStatus.PENDIENTE || order.status == OrderStatus.EN_GENERACION)),
                  const SizedBox(height: 12),
                  // Dropdown Editor
                  _buildDropdown("Editor", _editors, tempEdId, (val) => setDialogState(() => tempEdId = val),
                    enabled: (order.status == OrderStatus.PENDIENTE || order.status == OrderStatus.EN_GENERACION)),
>>>>>>> 19588d2 (feat: implementar filtros de estado y ordenamiento en Calidad, Recepción, Generación y Edición)

                  const SizedBox(height: 20),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (tempGenId != null && tempEdId != null && !isProcessing && (order.status == OrderStatus.PENDIENTE || order.status == OrderStatus.EN_GENERACION)) 
                          ? () async {
                              setDialogState(() => isProcessing = true);
                              try {
                                await _orderService.assignStaff(order.id!, tempGenId!, tempEdId!);
                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedido actualizado correctamente"), backgroundColor: Colors.green));
                                }
                              } catch (e) {
                                setDialogState(() => isProcessing = false);
                              }
                            } 
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
<<<<<<< HEAD
=======
                        disabledBackgroundColor: Colors.white.withOpacity(0.05),
>>>>>>> 19588d2 (feat: implementar filtros de estado y ordenamiento en Calidad, Recepción, Generación y Edición)
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isProcessing 
                          ? const CircularProgressIndicator(color: Colors.white) 
<<<<<<< HEAD
                          : const Text("ACTUALIZAR ASIGNACIÓN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
=======
                          : Text(
                              (order.status == OrderStatus.AUDIO_LISTO || order.status == OrderStatus.EDICION) 
                                ? "ORDEN PROCESADA" 
                                : "GENERAR ORDEN", 
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                color: (order.status == OrderStatus.AUDIO_LISTO || order.status == OrderStatus.EDICION) ? Colors.white24 : Colors.white
                              )
                            ),
>>>>>>> 19588d2 (feat: implementar filtros de estado y ordenamiento en Calidad, Recepción, Generación y Edición)
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<UserModel> users, String? selectedId, Function(String?) onChanged, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: enabled ? Colors.white.withOpacity(0.05) : Colors.black12,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: enabled ? Colors.white10 : Colors.white.withOpacity(0.02)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: users.any((u) => u.id == selectedId) ? selectedId : null,
              isExpanded: true,
              dropdownColor: const Color(0xFF222222),
              hint: Text("Seleccionar $label", style: const TextStyle(color: Colors.white24)),
              items: users.map((u) => DropdownMenuItem(
                value: u.id,
                child: Text(u.name, style: TextStyle(color: enabled ? Colors.white : Colors.white38)),
              )).toList(),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Panel de Calidad', 
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh, color: Colors.white24),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
<<<<<<< HEAD
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar por cliente...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
=======
            // Buscador y Filtros
            _buildFilterBar(),
>>>>>>> 19588d2 (feat: implementar filtros de estado y ordenamiento en Calidad, Recepción, Generación y Edición)
            
            const SizedBox(height: 16),
            
            Expanded(
              child: StreamBuilder<List<OrderModel>>(
                stream: _orderService.ordersStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
                  }
                  
<<<<<<< HEAD
                  final allOrders = snapshot.data ?? [];
                  final orders = allOrders.where((o) => 
                    (o.status == OrderStatus.PENDIENTE || 
                     o.status == OrderStatus.EN_GENERACION || 
                     o.status == OrderStatus.EDICION || 
                     o.status == OrderStatus.AUDIO_LISTO) &&
                    (o.clientName.toLowerCase().contains(_searchQuery) || (o.id?.toString().contains(_searchQuery) ?? false))
                  ).toList();
=======
                  var orders = snapshot.data ?? [];

                  // 1. Filtrado por Búsqueda
                  if (_searchQuery.isNotEmpty) {
                    orders = orders.where((o) => 
                      o.clientName.toLowerCase().contains(_searchQuery) || (o.id?.toString().contains(_searchQuery) ?? false)
                    ).toList();
                  }

                  // 2. Filtrado por Estado
                  if (_statusFilter != null) {
                    orders = orders.where((o) => o.status == _statusFilter).toList();
                  } else {
                    // Por defecto quitamos los anulados si no hay filtro activo
                    orders = orders.where((o) => o.status != OrderStatus.ANULADO).toList();
                  }

                  // 3. Ordenamiento
                  if (_sortByDelivery) {
                    orders.sort((a, b) => a.deliveryDueAt.compareTo(b.deliveryDueAt));
                  } else {
                    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  }
>>>>>>> 19588d2 (feat: implementar filtros de estado y ordenamiento en Calidad, Recepción, Generación y Edición)

                  if (orders.isEmpty) {
                    return const Center(child: Text('No hay pedidos activos.', style: TextStyle(color: Colors.white38)));
                  }

                  return ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final gen = _generators.firstWhere((u) => u.id == order.generatorId, orElse: () => UserModel(id: '', name: 'Pendiente', email: '', role: UserRole.generador));
                      final edi = _editors.firstWhere((u) => u.id == order.editorId, orElse: () => UserModel(id: '', name: 'Pendiente', email: '', role: UserRole.editor));
                      
                      return QCOrderCard(
                        order: order,
                        generator: order.generatorId != null ? gen : null,
                        editor: order.editorId != null ? edi : null,
                        onTap: () => _showAssignmentDialog(order),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Buscador
        SizedBox(
          width: 250,
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar por cliente...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.3), size: 18),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        
        // Chips de Estado
        _filterChip("TODO", null),
        _filterChip("GENERACIÓN", OrderStatus.EN_GENERACION),
        _filterChip("EDICIÓN", OrderStatus.EDICION),
        _filterChip("LISTO", OrderStatus.AUDIO_LISTO),

        const VerticalDivider(color: Colors.white10, width: 10),

        // Botones de Ordenamiento
        IconButton(
          tooltip: "Más recientes",
          icon: Icon(Icons.history, color: !_sortByDelivery ? Colors.deepPurpleAccent : Colors.white24),
          onPressed: () => setState(() => _sortByDelivery = false),
        ),
        IconButton(
          tooltip: "Fecha entrega",
          icon: Icon(Icons.timer, color: _sortByDelivery ? Colors.orangeAccent : Colors.white24),
          onPressed: () => setState(() => _sortByDelivery = true),
        ),
      ],
    );
  }

  Widget _filterChip(String label, OrderStatus? status) {
    final isSelected = _statusFilter == status;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 11)),
      selected: isSelected,
      onSelected: (v) => setState(() => _statusFilter = v ? status : null),
      selectedColor: const Color(0xFF7C3AED).withOpacity(0.4),
      backgroundColor: Colors.white.withOpacity(0.05),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    );
  }
}
