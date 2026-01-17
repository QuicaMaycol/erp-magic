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
                    )
                  else
                    const Text("No hay archivo adjunto", style: TextStyle(color: Colors.white24, fontSize: 13, fontStyle: FontStyle.italic)),

                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 20),

                  // Asignación
                  const Text("ASIGNACIÓN DE PERSONAL", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  
                  _buildDropdown("Generador", _generators, tempGenId, (val) => setDialogState(() => tempGenId = val)),
                  const SizedBox(height: 12),
                  _buildDropdown("Editor", _editors, tempEdId, (val) => setDialogState(() => tempEdId = val)),

                  const SizedBox(height: 20),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (tempGenId != null && tempEdId != null && !isProcessing) 
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isProcessing 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text("ACTUALIZAR ASIGNACIÓN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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

  Widget _buildDropdown(String label, List<UserModel> users, String? selectedId, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: users.any((u) => u.id == selectedId) ? selectedId : null,
              isExpanded: true,
              dropdownColor: const Color(0xFF222222),
              hint: Text("Seleccionar $label", style: const TextStyle(color: Colors.white24)),
              items: users.map((u) => DropdownMenuItem(
                value: u.id,
                child: Text(u.name, style: const TextStyle(color: Colors.white)),
              )).toList(),
              onChanged: onChanged,
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
            
            const SizedBox(height: 24),
            
            Expanded(
              child: StreamBuilder<List<OrderModel>>(
                stream: _orderService.ordersStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
                  }
                  
                  final allOrders = snapshot.data ?? [];
                  final orders = allOrders.where((o) => 
                    (o.status == OrderStatus.PENDIENTE || 
                     o.status == OrderStatus.EN_GENERACION || 
                     o.status == OrderStatus.EDICION || 
                     o.status == OrderStatus.AUDIO_LISTO) &&
                    (o.clientName.toLowerCase().contains(_searchQuery) || (o.id?.toString().contains(_searchQuery) ?? false))
                  ).toList();

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
}
