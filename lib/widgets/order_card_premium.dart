import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';

class OrderCardPremium extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onEdit;
  final VoidCallback? onTap;
  final Function(OrderModel)? onDelete; // Nueva función de eliminación
  final bool showEditButton;

  const OrderCardPremium({
    super.key, 
    required this.order, 
    required this.onEdit,
    this.onTap,
    this.onDelete,
    this.showEditButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final style = order.statusStyle;
    final Color mainColor = style['color'] as Color;
    
    final size = MediaQuery.of(context).size;
    final isWebGrid = size.width > 800;
    
    final timeFormat = DateFormat('h:mm', 'es');
    final periodFormat = DateFormat('a', 'es');
    final dateFormat = DateFormat('d/M', 'es');
    final fullTimeFormat = DateFormat('hh:mm a', 'es');

    return InkWell(
      onTap: onTap,
      onLongPress: onDelete != null ? () => onDelete!(order) : null, // Gesto para móvil
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Container(
            margin: EdgeInsets.only(bottom: isWebGrid ? 0 : 20),
            decoration: BoxDecoration(
              color: const Color(0xFF111111), // Negro mate
              borderRadius: BorderRadius.circular(24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Barra de Estado Vertical (Izquierda)
                    Container(width: 8, color: mainColor),
                    
                    // 2. Bloque Central de Información
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(isWebGrid ? 16.0 : 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nombre del Cliente
                            Text(
                              order.clientName.toLowerCase(), 
                              style: TextStyle(
                                color: Colors.white, 
                                fontSize: isWebGrid ? 24 : 32, 
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            
                            // Badges (Audio + Estado)
                            Row(
                              children: [
                                _buildBadge('AUDIO', const Color(0xFF7C3AED).withOpacity(0.2), const Color(0xFF7C3AED)),
                                const SizedBox(width: 8),
                                _buildBadge(style['label'] as String, mainColor.withOpacity(0.1), mainColor),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Metadato Ingreso
                            Text(
                              'INGRESO: ${fullTimeFormat.format(order.createdAt).toUpperCase()} · ${dateFormat.format(order.createdAt)}',
                              style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            
                            // Botón Editar
                            if (showEditButton)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: InkWell(
                                  onTap: onEdit,
                                  child: Row(
                                    children: const [
                                      Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF7C3AED)),
                                      SizedBox(width: 4),
                                      Text('EDITAR DATOS', 
                                        style: TextStyle(color: Color(0xFF7C3AED), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                    ],
                                  ),
                                ),
                              ),
                            
                            const SizedBox(height: 12),
                            
                            // Caja de Observaciones
                            if (order.observations != null && order.observations!.isNotEmpty)
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('OBSERVACIONES', style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                        const SizedBox(height: 4),
                                        Text(
                                          order.observations!, 
                                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // 3. Bloque de Entrega (Derecha)
                    Container(
                      width: isWebGrid ? 80 : 100,
                      padding: const EdgeInsets.fromLTRB(8, 40, 8, 20), // Más espacio arriba para el botón de opciones
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('ENTREGA', style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text(dateFormat.format(order.deliveryDueAt), 
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
                          const Spacer(),
                          Text(timeFormat.format(order.deliveryDueAt), 
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: isWebGrid ? 22 : 28, height: 1)),
                          Text(periodFormat.format(order.deliveryDueAt).toUpperCase(), 
                            style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w900, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Botón de 3 puntos para Web (Esquina Superior Derecha)
          if (onDelete != null)
            Positioned(
              top: 10,
              right: 10,
              child: PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_horiz, color: Colors.white54, size: 18),
                ),
                color: const Color(0xFF1B1B21), // Cambiado de backgroundColor a color
                onSelected: (val) {
                  if (val == 'delete') onDelete!(order);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                        SizedBox(width: 8),
                        Text('Mover a Papelera', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, 
        style: TextStyle(color: textCol, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }
}
