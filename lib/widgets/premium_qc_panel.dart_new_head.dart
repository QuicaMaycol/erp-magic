import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/order_service.dart';
import '../services/auth_service.dart';
import '../services/n8n_service.dart';
import 'qc_order_card.dart'; // Nueva tarjeta especializada

class PremiumQCPanel extends StatefulWidget {
  const PremiumQCPanel({super.key});

  @override
  State<PremiumQCPanel> createState() => _PremiumQCPanelState();
}

class _PremiumQCPanelState extends State<PremiumQCPanel> {
  final OrderService _orderService = OrderService();
  final AuthService _authService = AuthService();
  final N8nService _n8nService = N8nService();
  final TextEditingController _searchController = TextEditingController();
  
  List<UserModel> _generators = [];
  List<UserModel> _editors = [];
  UserModel? _currentUser;
  String _searchQuery = '';
  OrderStatus? _statusFilter;
  
  // Estado para selección masiva
  final Set<int> _selectedOrderIds = {};
  bool _isBulkLoading = false;
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
    final user = await _authService.getCurrentProfile();
    if (mounted) {
      setState(() {
        _generators = gens;
        _editors = eds;
        _currentUser = user;
      });
    }
  }

  Future<void> _handleBulkDownload() async {
    if (_selectedOrderIds.isEmpty) return;

    setState(() => _isBulkLoading = true);
    
    try {
      final List<Map<String, String>> filesToZip = [];
      
      // Obtenemos las órdenes actuales para extraer URLs y nombres
      final allOrders = await _orderService.fetchOrders();
      
      for (var id in _selectedOrderIds) {
        final order = allOrders.firstWhere((o) => o.id == id, orElse: () => throw Exception("Orden no encontrada"));
        if (order.finalAudioUrl != null) {
          filesToZip.add({
            'name': '${order.id}_${order.clientName.replaceAll(' ', '_')}.mp3',
            'url': order.finalAudioUrl!,
          });
        }
      }

      if (filesToZip.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ninguna orden seleccionada tiene audio final"), backgroundColor: Colors.orangeAccent)
          );
        }
        return;
      }

      final zipUrl = await _n8nService.generateBulkZip(filesToZip);
      
      if (zipUrl != null) {
        await _orderService.openUrl(zipUrl);
        setState(() {
          _selectedOrderIds.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ ZIP generado con éxito"), backgroundColor: Colors.green)
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Error al generar el ZIP"), backgroundColor: Colors.redAccent)
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBulkLoading = false);
      }
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
