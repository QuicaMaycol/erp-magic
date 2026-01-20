import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';

class QCOrderCard extends StatelessWidget {
  final OrderModel order;
  final UserModel? generator;
  final UserModel? editor;
  final VoidCallback onTap;
  final bool showAssigners;

  const QCOrderCard({
    super.key,
    required this.order,
    this.generator,
    this.editor,
    required this.onTap,
    this.showAssigners = true,
  });

  @override
  Widget build(BuildContext context) {
    // Basic implementation mimicking OrderCardPremium but with Gen/Edit info
    // For now, I'll keep it simple to fix compilation.
    // The user can refine the UI later.
    
    final style = order.statusStyle;
    final Color mainColor = style['color'] as Color;
    final dateFormat = DateFormat('d/M - HH:mm', 'es');

    return Card(
      color: const Color(0xFF1B1B21),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.clientName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: mainColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      style['label'] as String,
                      style: TextStyle(
                        color: mainColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Entrega: ${dateFormat.format(order.deliveryDueAt)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (showAssigners) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildRoleBadge('GEN', generator?.name),
                    const SizedBox(width: 8),
                    _buildRoleBadge('EDT', editor?.name),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String label, String? name) {
    final hasUser = name != null && name.isNotEmpty && name != 'Pendiente';
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hasUser ? Colors.green.withOpacity(0.3) : Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
              hasUser ? name! : '---',
              style: TextStyle(
                color: hasUser ? Colors.white : Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
