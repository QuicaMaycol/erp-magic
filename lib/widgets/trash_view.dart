import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';

class TrashView extends StatelessWidget {
  final OrderService _orderService = OrderService();

  TrashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Papelera de Reciclaje', 
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('Los pedidos aquí no son visibles para generadores ni editores.', 
            style: TextStyle(color: Colors.white24, fontSize: 13)),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<List<OrderModel>>(
              stream: _orderService.ordersStream,
              builder: (context, snapshot) {
                final orders = (snapshot.data ?? []).where((o) => o.status == OrderStatus.ANULADO).toList();
                
                if (orders.isEmpty) {
                  return const Center(child: Text('La papelera está vacía', style: TextStyle(color: Colors.white12)));
                }

                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(order.clientName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                Text('ID: #${order.id} · Eliminado recientemente', 
                                  style: const TextStyle(color: Colors.white24, fontSize: 11)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.restore_from_trash, color: Colors.greenAccent),
                            tooltip: 'Restaurar',
                            onPressed: () async {
                              await _orderService.updateOrderStatus(order.id!, OrderStatus.PENDIENTE);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedido restaurado")));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                            tooltip: 'Eliminar Permanentemente',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: const Color(0xFF16161A),
                                  title: const Text('¿Eliminar definitivamente?', style: TextStyle(color: Colors.white)),
                                  content: const Text('Esta acción no se puede deshacer.', style: TextStyle(color: Colors.white70)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ELIMINAR', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _orderService.deleteOrderPermanently(order.id!);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedido eliminado definitivamente")));
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
