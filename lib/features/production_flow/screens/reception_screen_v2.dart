import 'package:flutter/material.dart';
import '../models/production_order_model.dart';
import '../services/production_services.dart';
import '../../../../widgets/order_card.dart';

class ReceptionScreenV2 extends StatefulWidget {
  const ReceptionScreenV2({super.key});

  @override
  State<ReceptionScreenV2> createState() => _ReceptionScreenV2State();
}

class _ReceptionScreenV2State extends State<ReceptionScreenV2> {
  final _clientCtrl = TextEditingController();
  final _scriptCtrl = TextEditingController();
  DateTime _deliveryDate = DateTime.now().add(const Duration(hours: 24));
  String? _uploadedDocUrl;
  bool _isUploading = false;
  final _service = ProductionService();
  
  String _searchQuery = "";
  ProductionStatus? _statusFilter;
  bool _sortByDelivery = false; // false = createdAt DESC, true = deliveryDate ASC

  Future<void> _pickFile() async {
    setState(() => _isUploading = true);
    final url = await _service.pickAndUploadFile('documents');
    setState(() {
      _uploadedDocUrl = url;
      _isUploading = false;
    });
  }

  Future<void> _submit() async {
    if (_clientCtrl.text.isEmpty) return;
    
    final order = ProductionOrderModel(
      clientName: _clientCtrl.text,
      scriptText: _scriptCtrl.text,
      documentUrl: _uploadedDocUrl,
      deliveryDate: _deliveryDate,
      createdAt: DateTime.now(),
      status: ProductionStatus.pendiente_calidad,
    );

    await _service.createOrder(order);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Orden Creada")));
      _clientCtrl.clear();
      _scriptCtrl.clear();
      setState(() => _uploadedDocUrl = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: const Text("Recepción y Pedidos"), backgroundColor: Colors.transparent),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                // Área del Formulario (Colapsable o fija)
                ExpansionTile(
                  title: const Text("Nueva Orden", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  initiallyExpanded: false,
                  iconColor: Colors.deepPurple,
                  collapsedIconColor: Colors.white70,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      color: Colors.white.withOpacity(0.05),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _clientCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDec("Nombre Cliente"),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _scriptCtrl,
                            maxLines: 3,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDec("Contenido / Guion"),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isUploading ? null : _pickFile,
                                  icon: _isUploading 
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                                      : const Icon(Icons.attach_file),
                                  label: Text(_uploadedDocUrl == null ? "Adjuntar Archivo" : "Archivo OK"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _uploadedDocUrl == null ? Colors.grey[800] : Colors.green[800],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: const Text("CREAR ORDEN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                _buildFilterBar(),

                // Lista de Órdenes
                Expanded(
                  child: StreamBuilder<List<ProductionOrderModel>>(
                    stream: _service.getOrdersStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      var orders = snapshot.data!;

                      // 1. Filtrado por Búsqueda
                      if (_searchQuery.isNotEmpty) {
                        orders = orders.where((o) => o.clientName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                      }

                      // 2. Filtrado por Estado
                      if (_statusFilter != null) {
                        orders = orders.where((o) => o.status == _statusFilter).toList();
                      }

                      // 3. Ordenamiento
                      if (_sortByDelivery) {
                        orders.sort((a, b) {
                          if (a.deliveryDate == null) return 1;
                          if (b.deliveryDate == null) return -1;
                          return a.deliveryDate!.compareTo(b.deliveryDate!);
                        });
                      } else {
                        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                      }

                      if (orders.isEmpty) {
                        return const Center(child: Text("No hay órdenes que coincidan", style: TextStyle(color: Colors.white54)));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return OrderCard(
                            order: order,
                            onEdit: () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Editar próximamente")));
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 200,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: "Buscar cliente...",
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.search, color: Colors.white24, size: 18),
                filled: true,
                fillColor: Colors.white10,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
          ),
          _filterChip("TODO", null),
          _filterChip("PENDIENTE", ProductionStatus.pendiente_calidad),
          _filterChip("GENERACIÓN", ProductionStatus.aprobado),
          _filterChip("EDICIÓN", ProductionStatus.listo_para_edicion),
          _filterChip("LISTO", ProductionStatus.audio_listo),
          
          const SizedBox(width: 8),
          
          IconButton(
            tooltip: "Más recientes",
            icon: Icon(Icons.history, color: !_sortByDelivery ? Colors.deepPurpleAccent : Colors.white38),
            onPressed: () => setState(() => _sortByDelivery = false),
          ),
          IconButton(
            tooltip: "Fecha entrega",
            icon: Icon(Icons.timer, color: _sortByDelivery ? Colors.orangeAccent : Colors.white38),
            onPressed: () => setState(() => _sortByDelivery = true),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, ProductionStatus? status) {
    final isSelected = _statusFilter == status;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 11)),
      selected: isSelected,
      onSelected: (v) => setState(() => _statusFilter = v ? status : null),
      selectedColor: Colors.deepPurple.withOpacity(0.4),
      backgroundColor: Colors.white10,
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    );
  }

  InputDecoration _inputDec(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white10,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: const TextStyle(color: Colors.white38),
    );
  }
}
