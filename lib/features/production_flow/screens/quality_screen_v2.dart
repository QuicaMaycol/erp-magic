import 'package:flutter/material.dart';
import '../models/production_order_model.dart';
import '../services/production_services.dart';
import '../widgets/production_table.dart';

class QualityScreenV2 extends StatefulWidget {
  const QualityScreenV2({super.key});

  @override
  State<QualityScreenV2> createState() => _QualityScreenV2State();
}

class _QualityScreenV2State extends State<QualityScreenV2> {
  final _service = ProductionService();
  String _searchQuery = "";
  ProductionStatus? _statusFilter;
  bool _sortByDelivery = false; // false = createdAt DESC, true = deliveryDate ASC

  void _showDetail(ProductionOrderModel order) {
    showDialog(context: context, builder: (ctx) => _QCDetailDialog(order: order, service: _service));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: const Text("Calidad V2"), backgroundColor: Colors.transparent),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<List<ProductionOrderModel>>(
              stream: _service.getOrdersStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
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
                
                return ProductionTable(
                  orders: orders,
                  extraColumns: const [
                    DataColumn(label: Text('Doc', style: TextStyle(color: Colors.white))),
                    DataColumn(label: Text('Revisar', style: TextStyle(color: Colors.white))),
                  ],
                  cellBuilder: (order) => [
                    DataCell(
                      order.documentUrl != null 
                      ? IconButton(icon: const Icon(Icons.description, color: Colors.blue), onPressed: () => _service.openUrl(order.documentUrl))
                      : const Icon(Icons.close, color: Colors.grey)
                    ),
                    DataCell(
                      IconButton(icon: const Icon(Icons.visibility, color: Colors.orange), onPressed: () => _showDetail(order))
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Buscador
          SizedBox(
            width: 250,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Buscar cliente...",
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
              ),
            ),
          ),
          
          // Filtros de Estado
          _filterChip("TODO", null),
          _filterChip("GENERACIÓN", ProductionStatus.aprobado),
          _filterChip("EDICIÓN", ProductionStatus.listo_para_edicion),
          _filterChip("LISTO", ProductionStatus.audio_listo),
          
          const VerticalDivider(color: Colors.white24, width: 20),

          // Ordenamiento
          TextButton.icon(
            onPressed: () => setState(() => _sortByDelivery = false),
            icon: Icon(Icons.history, color: !_sortByDelivery ? Colors.deepPurpleAccent : Colors.white54),
            label: Text("Recientes", style: TextStyle(color: !_sortByDelivery ? Colors.deepPurpleAccent : Colors.white54, fontSize: 12)),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _sortByDelivery = true),
            icon: Icon(Icons.timer, color: _sortByDelivery ? Colors.orangeAccent : Colors.white54),
            label: Text("Entrega", style: TextStyle(color: _sortByDelivery ? Colors.orangeAccent : Colors.white54, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, ProductionStatus? status) {
    final isSelected = _statusFilter == status;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 12)),
      selected: isSelected,
      onSelected: (v) => setState(() => _statusFilter = v ? status : null),
      selectedColor: Colors.deepPurple,
      backgroundColor: Colors.white10,
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _QCDetailDialog extends StatefulWidget {
  final ProductionOrderModel order;
  final ProductionService service;
  const _QCDetailDialog({required this.order, required this.service});

  @override
  State<_QCDetailDialog> createState() => _QCDetailDialogState();
}

class _QCDetailDialogState extends State<_QCDetailDialog> {
  final _obsCtrl = TextEditingController();

  @override
  void initState() {
    _obsCtrl.text = widget.order.observations ?? '';
    super.initState();
  }

  void _updateStatus(ProductionStatus status) {
    widget.service.updateQualityStatus(widget.order.id!, status, observations: _obsCtrl.text);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF222222),
      title: Text("Revisión #${widget.order.id} - ${widget.order.clientName}", style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.order.scriptText ?? "Sin texto", style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            TextField(
              controller: _obsCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Observaciones de Calidad", 
                filled: true, 
                fillColor: Colors.black12
              ),
            ),
            const SizedBox(height: 20),
            if (widget.order.finalAudioUrl != null)
               ElevatedButton.icon(
                 onPressed: () => widget.service.openUrl(widget.order.finalAudioUrl),
                 icon: const Icon(Icons.play_arrow),
                 label: const Text("Escuchar Audio Final"),
               )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => _updateStatus(ProductionStatus.rechazado), child: const Text("RECHAZAR", style: TextStyle(color: Colors.red))),
        TextButton(onPressed: () => _updateStatus(ProductionStatus.en_revision), child: const Text("EN REVISIÓN", style: TextStyle(color: Colors.orange))),
        ElevatedButton(onPressed: () => _updateStatus(ProductionStatus.aprobado), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("APROBAR")),
      ],
    );
  }
}
