import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/order_service.dart';
import '../services/auth_service.dart';
import '../services/n8n_service.dart';
import '../services/upload_service.dart';
import '../widgets/order_card_premium.dart';
import '../widgets/intelligent_phone_field.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final OrderService _orderService = OrderService();
  final AuthService _authService = AuthService();
  final N8nService _n8nService = N8nService();
  final TextEditingController _searchController = TextEditingController();
  
  UserModel? _currentUser;
  bool _isLoading = true;
  List<OrderModel> _orders = [];
  String _searchQuery = '';
  String? _errorMessage;

  // Nuevos estados para filtros y ordenamiento
  OrderStatus? _statusFilter;
  bool _sortByDelivery = true; // true: Entrega, false: Ingreso

  // Estado para selección masiva
  final Set<int> _selectedOrderIds = {};
  bool _isBulkLoading = false;

  // Estado para mantenimiento
  bool _isRescuing = false;
  bool _isCleaning = false; // Estado para limpieza de storage
  int _rescueOrderCount = 0;
  int _maintenanceDays = 60; // Periodo de mantenimiento (30 o 60 días)
  bool _showMaintenanceOnly = false;

  // Estado para secciones colapsables
  final Set<String> _collapsedGroups = {'✅ ENTREGADOS'};

  // Controlador de dropzone persistente
  DropzoneViewController? _dropzoneController;

  @override
  void initState() {
    super.initState();
    _initialLoad();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  void _toggleSort() {
    setState(() {
      _sortByDelivery = !_sortByDelivery;
    });
  }

  Widget _buildFilterChip() {
    return PopupMenuButton<OrderStatus?>(
      initialValue: _statusFilter,
      tooltip: 'Filtrar por estado',
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _statusFilter != null ? const Color(0xFF7C3AED).withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.filter_list_rounded, 
          color: _statusFilter != null ? const Color(0xFF7C3AED) : Colors.white38,
          size: 20,
        ),
      ),
      onSelected: (OrderStatus? value) {
        setState(() => _statusFilter = value);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('Todos los estados')),
        const PopupMenuItem(value: OrderStatus.PENDIENTE, child: Text('Pendiente')),
        const PopupMenuItem(value: OrderStatus.EN_GENERACION, child: Text('En Generación')),
        const PopupMenuItem(value: OrderStatus.EDICION, child: Text('En Edición')),
        const PopupMenuItem(value: OrderStatus.EN_REVISION, child: Text('En Revisión')),
        const PopupMenuItem(value: OrderStatus.AUDIO_LISTO, child: Text('Listo')),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _authService.getCurrentProfile(),
        _orderService.fetchOrders(),
      ]);
      
      if (mounted) {
        setState(() {
          _currentUser = results[0] as UserModel?;
          _orders = results[1] as List<OrderModel>;
          _isLoading = false;
          _errorMessage = null;
        });
        _calculateRescueCount();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Error de conexión. Intente refrescar.";
        });
      }
    }
  }

  void refreshData() {
    _initialLoad();
  }

  // Métodos Públicos para control desde Navegación
  void toggleMaintenanceFilter(bool active, {int? days}) {
    setState(() {
      _showMaintenanceOnly = active;
      if (days != null) _maintenanceDays = days;
      if (active) _selectedOrderIds.clear();
    });
  }
  Future<void> handleManualCleanup() async {
    await _handleMaintenanceCleanup();
  }

  Future<void> handleMaintenanceRescue() async {
    await _handleMaintenanceRescue();
  }

  void _calculateRescueCount() {
    if (_currentUser?.role != UserRole.admin) return;
    
    final now = DateTime.now();
    // Empezar a alertar a la mitad del periodo para dar margen de maniobra
    // Si es 60 días, alerta a los 30. Si es 30 días, alerta a los 15.
    final alertDays = (_maintenanceDays / 2).floor();
    final rescueThreshold = now.subtract(Duration(days: alertDays));
    
    final count = _orders.where((o) => 
      o.createdAt.isBefore(rescueThreshold) && 
      (o.scriptFileUrl != null || o.finalAudioUrl != null) &&
      o.status != OrderStatus.ANULADO
    ).length;
    
    setState(() {
      _rescueOrderCount = count;
    });
  }

  Future<void> _handleMaintenanceRescue() async {
    if (_isRescuing) return;
    
    setState(() => _isRescuing = true);
    
    try {
      final driveUrl = await _n8nService.triggerMaintenanceRescue();
      
      if (driveUrl != null) {
        await _orderService.openUrl(driveUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Rescate completado. Carpeta de Drive abierta."),
              backgroundColor: Colors.green,
            )
          );
        }
      } else {
        throw Exception("No se recibió URL de Drive");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ Error al iniciar el rescate masivo"),
            backgroundColor: Colors.redAccent,
          )
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRescuing = false);
      }
    }
  }

  Future<void> _handleMaintenanceCleanup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16161A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('⚠️ LIMPIEZA DE STORAGE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text('¿Estás seguro de querer LIBERAR ESPACIO?\n\n- Se borrarán los ARCHIVOS de hace $_maintenanceDays días.\n- Los REGISTROS (nombres, guiones, estados) NO se borrarán.\n\nASEGÚRATE de haber hecho Rescate primero.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('LIMPIAR AHORA', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCleaning = true);
    try {
      final count = await _orderService.cleanupOldStorageFiles(_maintenanceDays);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✨ Limpieza completada: $count pedidos liberados del servidor."),
            backgroundColor: Colors.green,
          )
        );
        refreshData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error en limpieza: $e"), backgroundColor: Colors.redAccent)
        );
      }
    } finally {
      if (mounted) setState(() => _isCleaning = false);
    }
  }

  Future<void> _handleBulkDownload() async {
    if (_selectedOrderIds.isEmpty) return;

    setState(() => _isBulkLoading = true);
    
    try {
      final List<Map<String, String>> filesToZip = [];
      
      // Obtenemos las órdenes actuales para extraer URLs y nombres
      // Usamos _orders que ya está cargado o fetchOrders si queremos lo último
      final allOrders = await _orderService.fetchOrders();
      
      for (var id in _selectedOrderIds) {
        final order = allOrders.firstWhere((o) => o.id == id, orElse: () => throw Exception("Orden no encontrada"));
        final safeName = order.clientName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        
        // Audio Final
        if (order.finalAudioUrl != null && order.finalAudioUrl!.isNotEmpty) {
          filesToZip.add({
            'name': '${order.id}_${safeName}_FINAL.mp3',
            'url': order.finalAudioUrl!,
            'client_name': order.clientName,
            'order_id': order.id.toString(),
          });
        }

        // Audio Muestra
        if (order.audioMuestraUrl != null && order.audioMuestraUrl!.isNotEmpty) {
          filesToZip.add({
            'name': '${order.id}_${safeName}_MUESTRA.mp3',
            'url': order.audioMuestraUrl!,
            'client_name': order.clientName,
            'order_id': order.id.toString(),
          });
        }
      }

      if (filesToZip.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ninguna orden seleccionada tiene archivos para descargar"), backgroundColor: Colors.orangeAccent)
          );
        }
        return;
      }

      final zipUrl = await _n8nService.generateBulkZip(filesToZip);
      
      if (zipUrl != null) {
        print("📥 ZIP URL RECIBIDA: '$zipUrl'");
        await _orderService.openUrl(zipUrl, forceDownload: true);
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

  void showOrderForm({OrderModel? order}) {
    _showOrderForm(order: order);
  }

  void showOrderDetail(OrderModel order, {UserModel? viewingUser}) {
    _showOrderDetail(order, viewingUser: viewingUser);
  }

  void _showOrderDetail(OrderModel order, {UserModel? viewingUser}) {
    bool isProcessing = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1B1B21), // Fondo más sólido y elegante
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Detalle del Pedido #${order.id}', 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildDetailRow("CLIENTE", order.clientName),
                   const SizedBox(height: 12),
                   if (order.product != null && order.product!.isNotEmpty) ...[
                     _buildDetailRow("PRODUCTO", order.product!),
                     const SizedBox(height: 12),
                   ],
                   if ((order.country != null && order.country!.isNotEmpty) || (order.price != null)) ...[
                     Row(
                       children: [
                          if (order.country != null && order.country!.isNotEmpty)
                            Expanded(child: _buildDetailRow("PAÍS", order.country!)),
                          if (order.country != null && order.country!.isNotEmpty && order.price != null)
                            const SizedBox(width: 16),
                          if (order.price != null && viewingUser?.role != UserRole.control_calidad)
                            Expanded(child: _buildDetailRow("PRECIO", "\$${order.price!.toStringAsFixed(2)}")),
                       ],
                     ),
                     const SizedBox(height: 12),
                   ],
                   if ((order.phone != null && order.phone!.isNotEmpty) || (order.paymentMethod != null && order.paymentMethod!.isNotEmpty)) ...[
                     Row(
                       children: [
                          if (order.phone != null && order.phone!.isNotEmpty)
                            Expanded(child: _buildDetailRow("CELULAR", order.phone!)),
                          if (order.phone != null && order.phone!.isNotEmpty && order.paymentMethod != null && order.paymentMethod!.isNotEmpty)
                            const SizedBox(width: 16),
                          if (order.paymentMethod != null && order.paymentMethod!.isNotEmpty)
                            Expanded(child: _buildDetailRow("MEDIO DE PAGO", order.paymentMethod!)),
                       ],
                     ),
                     const SizedBox(height: 12),
                   ],
                   Row(
                     children: [
                        Expanded(child: _buildDetailRow("INGRESO", DateFormat('dd/MM - HH:mm').format(order.createdAt))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildDetailRow("ENTREGA", DateFormat('dd/MM - HH:mm').format(order.deliveryDueAt))),
                     ],
                   ),
                   const SizedBox(height: 20),
                  
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
                    ),
                  ),
                  
                  const SizedBox(height: 16),
  
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
                      ),
                    )
                  else
                    const Text("No hay archivo adjunto", style: TextStyle(color: Colors.white24, fontSize: 13, fontStyle: FontStyle.italic)),
  
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 24),
  
                  // SECCIÓN DE AUDIOS Y PROYECTO (SIEMPRE VISIBLE)
                  if (true) ...[
                    const Text("AUDIOS Y PROYECTO", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
                              onPressed: () => _orderService.openUrl(order.baseAudioUrl, forceDownload: true),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text("Descargar"),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.amber, side: BorderSide(color: Colors.amber.withOpacity(0.5))),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
  
                    if (order.audioMuestraUrl != null) ...[
                      const Text("AUDIO DE MUESTRA", style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _orderService.openUrl(order.audioMuestraUrl),
                              icon: const Icon(Icons.play_circle_fill),
                              label: const Text("Escuchar"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent.withOpacity(0.1), foregroundColor: Colors.tealAccent),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _orderService.openUrl(order.audioMuestraUrl, forceDownload: true),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text("Descargar"),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.tealAccent, side: BorderSide(color: Colors.tealAccent.withOpacity(0.5))),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _orderService.shareOrderAudio(order, isFinal: false),
                            icon: const Icon(Icons.share_outlined, color: Colors.tealAccent),
                            tooltip: "Compartir Muestra",
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
  
                    if (order.finalAudioUrl != null) ...[
                      const Text("PRODUCTO FINAL (EDITADO)", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _orderService.openUrl(order.finalAudioUrl),
                              icon: const Icon(Icons.play_circle_fill),
                              label: const Text("Escuchar"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.1), foregroundColor: Colors.redAccent),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: (order.status == OrderStatus.AUDIO_LISTO || order.status == OrderStatus.ENTREGADO) 
                                ? () => _orderService.openUrl(order.finalAudioUrl, forceDownload: true)
                                : null,
                              icon: const Icon(Icons.download_rounded),
                              label: const Text("Descargar"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent, 
                                side: BorderSide(color: Colors.redAccent.withOpacity(0.5))
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: (order.status == OrderStatus.AUDIO_LISTO || order.status == OrderStatus.ENTREGADO)
                              ? () => _orderService.shareOrderAudio(order, isFinal: true)
                              : null,
                            icon: Icon(Icons.share_rounded, 
                              color: (order.status == OrderStatus.AUDIO_LISTO || order.status == OrderStatus.ENTREGADO) 
                                ? Colors.redAccent 
                                : Colors.white10
                            ),
                            tooltip: "Compartir Producto Final",
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // PROYECTO
                    const Text("PROYECTO EDITABLE (.AUP3 / ZIP)", style: TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (order.projectFileUrl != null)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _orderService.openUrl(order.projectFileUrl),
                              icon: const Icon(Icons.folder_zip, color: Colors.purpleAccent),
                              label: const Text("Ver Proyecto"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.withOpacity(0.1), foregroundColor: Colors.purpleAccent),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _orderService.openUrl(order.projectFileUrl, forceDownload: true),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text("Descargar"),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.purpleAccent, side: BorderSide(color: Colors.purpleAccent.withOpacity(0.5))),
                            ),
                          ),
                        ],
                      )
                    else 
                      const Text("No hay proyecto cargado", style: TextStyle(color: Colors.white10, fontSize: 12)),
                  ] else
                     const Center(child: Text("Aún no hay audios procesados", style: TextStyle(color: Colors.white10, fontSize: 12))),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CERRAR', style: TextStyle(color: Colors.white38)),
            ),
            if (order.status == OrderStatus.EN_REVISION && (_currentUser?.role == UserRole.admin || _currentUser?.role == UserRole.control_calidad))
              ElevatedButton(
                onPressed: isProcessing ? null : () async {
                  setDialogState(() => isProcessing = true);
                  try {
                    await _orderService.approveQualityControl(order.id!);
                    if (mounted) {
                      Navigator.pop(context);
                      refreshData();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedido aprobado con éxito"), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    setDialogState(() => isProcessing = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                child: isProcessing 
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                  : const Text("LISTO (APROBAR)"),
              ),
            if (order.status == OrderStatus.AUDIO_LISTO && (_currentUser?.role == UserRole.admin || _currentUser?.role == UserRole.recepcion))
              ElevatedButton(
                onPressed: isProcessing ? null : () async {
                  setDialogState(() => isProcessing = true);
                  try {
                    await _orderService.markAsDelivered(order.id!);
                    if (mounted) {
                      Navigator.pop(context);
                      refreshData();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text("✅ Pedido entregado al cliente"), 
                        backgroundColor: const Color(0xFFFFEB3B).withOpacity(0.9),
                        duration: const Duration(seconds: 3),
                      ));
                    }
                  } catch (e) {
                    if (mounted) {
                      setDialogState(() => isProcessing = false);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("❌ No se pudo marcar como entregado"), 
                        backgroundColor: Colors.redAccent
                      ));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFEB3B), foregroundColor: Colors.black),
                child: isProcessing 
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) 
                  : const Text("ENTREGAR PEDIDO"),
              ),
          ],
        ),
      ),
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

  void _showOrderForm({OrderModel? order}) {
    final clientController = TextEditingController(text: order?.clientName);
    final scriptController = TextEditingController(text: order?.scriptText);
    final obsController = TextEditingController(text: order?.observations);
    final countryController = TextEditingController(text: order?.country);
    final priceController = TextEditingController(text: order?.price?.toString());
    final phoneController = TextEditingController(text: order?.phone);
    final paymentController = TextEditingController(text: order?.paymentMethod);
    final productController = TextEditingController(text: order?.product);
    DateTime selectedDate = order?.deliveryDueAt ?? DateTime.now().add(const Duration(hours: 4));
    
    PlatformFile? selectedFile;
    bool hasExistingFile = order?.scriptFileUrl != null && order!.scriptFileUrl!.isNotEmpty;
    bool isUploading = false;
    bool isDragging = false; // Estado para arrastre

    showDialog(
      context: context,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF7C3AED),
            onPrimary: Colors.white,
            surface: Color(0xFF16161A),
            onSurface: Colors.white,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF7C3AED)),
          ),
        ),
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF16161A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Nueva Orden de Trabajo', 
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            content: Stack(
              children: [
                // DropTarget invisible que cubre todo el modal
                Positioned.fill(
                  child: DropTarget(
                    onDragDone: (details) async {
                      print("DEBUG: Drop detectado (Unificado)");
                      if (details.files.isNotEmpty) {
                        try {
                          final file = details.files.first;
                          
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Leyendo archivo..."), duration: Duration(milliseconds: 500))
                            );
                          }

                          final bytes = await file.readAsBytes();
                          
                          setDialogState(() {
                            selectedFile = PlatformFile(
                              name: file.name,
                              size: bytes.length,
                              bytes: bytes,
                              path: kIsWeb ? null : file.path, // En Web el path es null
                            );
                            isDragging = false;
                          });

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("✅ Archivo listo: ${file.name}"),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          print("DEBUG: Error en Drop: $e");
                          setDialogState(() => isDragging = false);
                        }
                      }
                    },
                    onDragEntered: (details) => setDialogState(() => isDragging = true),
                    onDragExited: (details) => setDialogState(() => isDragging = false),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                
                // Formulario (Ignora gestos durante el arrastre para no tapar el DropTarget)
                IgnorePointer(
                  ignoring: isDragging,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _buildFormContent(
                          setDialogState, 
                          clientController, 
                          scriptController, 
                          productController, 
                          phoneController, 
                          countryController, 
                          priceController, 
                          paymentController, 
                          isDragging, 
                          selectedFile, 
                          hasExistingFile, 
                          isUploading, 
                          selectedDate, 
                          (newDate) => setDialogState(() => selectedDate = newDate), // Callback para actualización real
                          obsController, 
                          (newFile) => setDialogState(() => selectedFile = newFile), // Callback para archivo
                          order, 
                          context
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCELAR', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: isUploading ? null : () async {
                  if (clientController.text.isEmpty) return;
                  
                  try {
                    setDialogState(() => isUploading = true);

                    // 1. Guardar Metadata en Supabase (Sin archivo aún)
                    final orderData = OrderModel(
                      id: order?.id,
                      clientName: clientController.text.trim(),
                      scriptText: scriptController.text.trim(),
                      observations: obsController.text.trim(),
                      country: countryController.text.trim(),
                      price: double.tryParse(priceController.text.trim()),
                       phone: phoneController.text.trim(),
                       paymentMethod: paymentController.text.trim(),
                       product: productController.text.trim(),
                       deliveryDueAt: selectedDate,
                      status: order?.status ?? OrderStatus.PENDIENTE,
                      scriptFileUrl: order?.scriptFileUrl, // Mantener anterior si existe
                    );
                    
                    OrderModel savedOrder;
                    if (order?.id == null) {
                      savedOrder = await _orderService.createOrder(orderData);
                    } else {
                      await _orderService.updateOrder(orderData);
                      savedOrder = orderData; // Para edición, usamos el modelo actual con ID
                    }

                    // 2. Enviar a n8n si hay archivo nuevo
                    if (selectedFile != null) {
                      String ref = 'script_file_url';
                      final extension = selectedFile!.extension?.toLowerCase() ?? 
                                     selectedFile!.name.split('.').last.toLowerCase();
                      
                      if (extension == 'mp3' || extension == 'wav' || extension == 'zip') {
                        ref = 'base_audio_url';
                      }

                      UploadService().startUpload(
                        clientName: savedOrder.clientName,
                        orderId: savedOrder.id.toString(),
                        file: selectedFile!,
                        structuralReference: ref,
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("🚀 Subida de archivo iniciada"), backgroundColor: Color(0xFF7C3AED))
                        );
                      }
                    }
                    
                    if (!mounted) return;
                    Navigator.pop(context);
                    refreshData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Orden guardada correctamente'), backgroundColor: Colors.green)
                    );
                  } catch (e) {
                    print("Error: $e");
                    if (mounted) {
                      setDialogState(() => isUploading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isUploading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
            actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, {int maxLines = 1, IconData? icon, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF7C3AED), size: 20) : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildQuickSelect({
    required StateSetter setDialogState,
    required TextEditingController controller,
    required List<String> options,
  }) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: options.map((option) {
            final isSelected = controller.text == option;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                onTap: () {
                  setDialogState(() {
                    controller.text = option;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF7C3AED).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    option,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF7C3AED) : Colors.white60,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTimeQuickSelect({
    required StateSetter setDialogState,
    required DateTime selectedDate,
    required Function(DateTime) onTimeSelected,
  }) {
    final times = [
      {'label': 'DURANTE EL DÍA', 'hour': 23, 'minute': 59},
      {'label': '10:00 AM', 'hour': 10, 'minute': 0},
      {'label': '11:00 AM', 'hour': 11, 'minute': 0},
      {'label': '12:00 PM', 'hour': 12, 'minute': 0},
      {'label': '02:00 PM', 'hour': 14, 'minute': 0},
      {'label': '03:00 PM', 'hour': 15, 'minute': 0},
      {'label': '04:00 PM', 'hour': 16, 'minute': 0},
      {'label': '05:00 PM', 'hour': 17, 'minute': 0},
    ];

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: times.map((time) {
            final hour = time['hour'] as int;
            final minute = time['minute'] as int;
            final isSelected = selectedDate.hour == hour && selectedDate.minute == minute;
            
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                onTap: () {
                  setDialogState(() {
                    onTimeSelected(DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      hour,
                      minute,
                    ));
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF7C3AED).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    time['label'] as String,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF7C3AED) : Colors.white60,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildValueBox({required String label, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, color: const Color(0xFF7C3AED), size: 16),
              const SizedBox(width: 8),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
    
    // Lógica de filtrado unificada para UI y Selección
    final filteredOrders = _orders.where((order) {
      if (_showMaintenanceOnly) {
        final alertThreshold = DateTime.now().subtract(Duration(days: (_maintenanceDays / 2).floor()));
        return order.createdAt.isBefore(alertThreshold) && 
               (order.scriptFileUrl != null || order.finalAudioUrl != null) &&
               order.status != OrderStatus.ANULADO;
      }
      // Filtro de anulados
      if (_statusFilter == null && order.status == OrderStatus.ANULADO) return false;
      // Filtro de estado
      if (_statusFilter != null && order.status != _statusFilter) return false;
      // Filtro de búsqueda
      if (_searchQuery.isNotEmpty) {
        return order.clientName.toLowerCase().contains(_searchQuery) ||
               (order.id?.toString().contains(_searchQuery) ?? false);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('CENTRAL DE PEDIDOS', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    // Botón Seleccionar Todo
                    if (filteredOrders.isNotEmpty)
                      IconButton(
                        tooltip: _selectedOrderIds.length == filteredOrders.length ? "Desmarcar todos" : "Seleccionar todos",
                        icon: Icon(
                          _selectedOrderIds.length == filteredOrders.length ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: _selectedOrderIds.isNotEmpty ? const Color(0xFF7C3AED) : Colors.white24,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            if (_selectedOrderIds.length == filteredOrders.length) {
                              _selectedOrderIds.clear();
                            } else {
                              for (var o in filteredOrders) {
                                if (o.id != null) _selectedOrderIds.add(o.id!);
                              }
                            }
                          });
                        },
                      ),
                    if (_selectedOrderIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: ElevatedButton.icon(
                          onPressed: _isBulkLoading ? null : _handleBulkDownload,
                          icon: _isBulkLoading 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.archive_outlined, size: 18),
                          label: Text("ZIP (${_selectedOrderIds.length})"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.tealAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 10)),
                      ),
                    IconButton(
                      onPressed: refreshData,
                      icon: const Icon(Icons.refresh, color: Colors.white24, size: 18),
                      tooltip: 'Refrescar datos',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Buscador y Filtros
            _buildFilterBar(),
            
            // Contenido principal del Dashboard
            const SizedBox(height: 10),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<List<OrderModel>>(
                stream: _orderService.ordersStream,
                builder: (context, snapshot) {
                  // Usamos la misma lógica de filtrado que en build para consistencia
                  List<OrderModel> sourceList = snapshot.hasData ? snapshot.data! : _orders;
                   
                  // 1. Filtrado de Base (No anulados a menos que se pida)
                  if (_showMaintenanceOnly) {
                    final alertThreshold = DateTime.now().subtract(Duration(days: (_maintenanceDays / 2).floor()));
                    sourceList = sourceList.where((o) => 
                      o.createdAt.isBefore(alertThreshold) && 
                      (o.scriptFileUrl != null || o.finalAudioUrl != null) &&
                      o.status != OrderStatus.ANULADO
                    ).toList();
                  } else {
                    if (_statusFilter != null) {
                      sourceList = sourceList.where((o) => o.status == _statusFilter).toList();
                    } else {
                      sourceList = sourceList.where((o) => o.status != OrderStatus.ANULADO).toList();
                    }
                  }

                  // 2. Filtrado por Búsqueda
                  if (_searchQuery.isNotEmpty) {
                    sourceList = sourceList.where((o) => 
                      o.clientName.toLowerCase().contains(_searchQuery) || (o.id?.toString().contains(_searchQuery) ?? false)
                    ).toList();
                  }

                  // 3. Ordenamiento
                  if (_sortByDelivery) {
                    sourceList.sort((a, b) => a.deliveryDueAt.compareTo(b.deliveryDueAt));
                  } else {
                    sourceList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  }

                  if (sourceList.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty ? 'Sin pedidos activos.' : 'No se encontraron resultados.', 
                        style: const TextStyle(color: Colors.white24)
                      )
                    );
                  }

                  // Lógica de Agrupación (Steve Jobs Vision: Orden y Prioridad)
                  final groups = _groupOrders(sourceList);
                  
                  // Definimos el Orden Exacto pedido por el usuario
                  // 1. Esta Semana (Siempre visible)
                  // 2. Más Adelante
                  // 3. Atrasados
                  // 4. Entregados
                  final groupKeys = groups.keys.where((k) {
                    if (groups[k]!.isNotEmpty) return true;
                    if (k.contains('SEMANA')) return true; // Mantener Esta Semana visible aunque esté vacía
                    return false;
                  }).toList();
                  
                  return ListView.builder(
                    itemCount: groupKeys.length,
                    itemBuilder: (context, groupIndex) {
                      final category = groupKeys[groupIndex];
                      final categoryOrders = groups[category]!;
                      final color = _getGroupColor(category);
                      final isCollapsed = _collapsedGroups.contains(category);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGroupHeader(category, categoryOrders.length, color, isCollapsed),
                          if (!isCollapsed)
                            categoryOrders.isEmpty 
                              ? Padding(
                                  padding: const EdgeInsets.only(left: 40.0, bottom: 24.0),
                                  child: Text(
                                    "No hay pedidos pendientes.", 
                                    style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 13, fontStyle: FontStyle.italic)
                                  ),
                                )
                              : Column(
                                  children: categoryOrders.map((order) => Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0),
                                    child: OrderCardPremium(
                                      order: order, 
                                      onEdit: () => _showOrderForm(order: order),
                                      onTap: () => showOrderDetail(order, viewingUser: _currentUser),
                                      isSelected: _selectedOrderIds.contains(order.id),
                                      onSelect: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedOrderIds.add(order.id!);
                                          } else {
                                            _selectedOrderIds.remove(order.id);
                                          }
                                        });
                                      },
                                      onDelete: (order) async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            backgroundColor: const Color(0xFF16161A),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            title: const Text('¿Mover a papelera?', style: TextStyle(color: Colors.white)),
                                            content: const Text('El pedido dejará de ser visible en las secciones activas.', style: TextStyle(color: Colors.white70)),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, true), 
                                                child: const Text('MOVER', style: TextStyle(color: Colors.redAccent))
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                           try {
                                             await _orderService.updateOrderStatus(order.id!, OrderStatus.ANULADO);
                                             refreshData();
                                           } catch (e) {
                                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                                           }
                                        }
                                      },
                                      showEditButton: _currentUser?.role == UserRole.admin || _currentUser?.role == UserRole.control_calidad,
                                    ),
                                  )).toList(),
                                ),
                        ],
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
        _filterChip("PENDIENTE", OrderStatus.PENDIENTE),
        _filterChip("GENERACIÓN", OrderStatus.EN_GENERACION),
        _filterChip("EDICIÓN", OrderStatus.EDICION),
        _filterChip("LISTO", OrderStatus.AUDIO_LISTO),

        const VerticalDivider(color: Colors.white10, width: 10),

        // Botones de Ordenamiento
        IconButton(
          tooltip: "Más recientes",
          icon: Icon(Icons.history, color: !_sortByDelivery ? const Color(0xFF7C3AED) : Colors.white24),
          onPressed: () => setState(() => _sortByDelivery = false),
        ),
        IconButton(
          tooltip: "Fecha entrega",
          icon: Icon(Icons.timer, color: _sortByDelivery ? Colors.orangeAccent : Colors.white24),
          onPressed: () => setState(() => _sortByDelivery = true),
        ),

        if (_showMaintenanceOnly)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: InkWell(
              onTap: () => toggleMaintenanceFilter(false),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orangeAccent, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 16),
                    const SizedBox(width: 8),
                    const Text("Modo Mantenimiento", style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => toggleMaintenanceFilter(false),
                      child: const Icon(Icons.close, color: Colors.orangeAccent, size: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildFormContent(
    StateSetter setDialogState,
    TextEditingController clientController,
    TextEditingController scriptController,
    TextEditingController productController,
    TextEditingController phoneController,
    TextEditingController countryController,
    TextEditingController priceController,
    TextEditingController paymentController,
    bool isDragging,
    PlatformFile? selectedFile,
    bool hasExistingFile,
    bool isUploading,
    DateTime selectedDate,
    Function(DateTime) onDateChanged,
    TextEditingController obsController,
    Function(PlatformFile?) onFileChanged,
    OrderModel? order,
    BuildContext context,
  ) {
    return [
      _buildField(clientController, 'Cliente', icon: Icons.person_outline),
      const SizedBox(height: 12),
      _buildField(scriptController, 'Texto / Guion', maxLines: 3, icon: Icons.description_outlined),
      const SizedBox(height: 12),
      _buildField(productController, 'Producto', icon: Icons.inventory_2_outlined),
      const SizedBox(height: 8),
      _buildQuickSelect(
        setDialogState: setDialogState,
        controller: productController,
        options: ['Audiobebe', 'audiobebe+video', 'invitaciones', 'invitaciones+video', 'Cancion', 'cancion+video', 'Animacion'],
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IntelligentPhoneField(
                  initialValue: phoneController.text,
                  onChanged: (fullNumber, countryName, isoCode) {
                    phoneController.text = fullNumber;
                    countryController.text = countryName;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildField(priceController, 'Precio', icon: Icons.attach_money, keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                _buildQuickSelect(
                  setDialogState: setDialogState,
                  controller: priceController,
                  options: ['55', '65', '25', '45', '35', '16.4'],
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                _buildField(paymentController, 'Medio de Pago', icon: Icons.payment),
                const SizedBox(height: 8),
                _buildQuickSelect(
                  setDialogState: setDialogState,
                  controller: paymentController,
                  options: ['paypal', 'hotmar', 'ria', 'remitli', 'globas66', 'yape'],
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      
      // Botón de selección de archivo mejorado
      InkWell(
        onTap: isUploading ? null : () async {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'mp3'],
            withData: true, // Asegurar que tengamos los bytes en Web
          );
          if (result != null) {
            onFileChanged(result.files.first);
          }
        },
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(
            color: isDragging 
                ? const Color(0xFF7C3AED).withOpacity(0.15) 
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDragging 
                  ? const Color(0xFF7C3AED) 
                  : (selectedFile != null || hasExistingFile) 
                      ? Colors.green.withOpacity(0.6) 
                      : Colors.white.withOpacity(0.1),
              width: isDragging ? 2.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isUploading)
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)))
              else
                Icon(
                  (selectedFile != null || hasExistingFile) ? Icons.check_circle_rounded : Icons.cloud_upload_rounded,
                  color: (selectedFile != null || hasExistingFile) ? Colors.green : const Color(0xFF7C3AED),
                  size: 32
                ),
              const SizedBox(height: 12),
              Text(
                selectedFile != null 
                  ? "Seleccionado: ${selectedFile!.name}" 
                  : (hasExistingFile ? "Archivo adjunto previamente" : "Haz clic o arrastra un archivo"),
                style: TextStyle(
                  color: (selectedFile != null || hasExistingFile) ? Colors.green : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              if (selectedFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: TextButton.icon(
                    onPressed: () => onFileChanged(null),
                    icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                    label: const Text("QUITAR", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                isDragging ? "¡Suelto para adjuntar!" : "Soporta PDF, Word, MP3",
                style: TextStyle(
                  color: isDragging ? const Color(0xFF7C3AED) : Colors.white24, 
                  fontSize: 11,
                  fontWeight: isDragging ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  onDateChanged(DateTime(
                    date.year, date.month, date.day,
                    selectedDate.hour, selectedDate.minute,
                  ));
                }
              },
              child: _buildValueBox(
                label: 'Fecha',
                value: DateFormat('dd/MM/yyyy', 'es').format(selectedDate),
                icon: Icons.calendar_today_rounded,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                InkWell(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(selectedDate),
                      cancelText: 'CANCELAR',
                      confirmText: 'ACEPTAR',
                      helpText: 'SELECCIONAR HORA',
                      builder: (context, child) {
                        return Localizations.override(
                          context: context,
                          locale: const Locale('en', 'US'),
                          child: MediaQuery(
                            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                materialTapTargetSize: MaterialTapTargetSize.padded,
                                timePickerTheme: TimePickerThemeData(
                                  backgroundColor: const Color(0xFF1E1E24),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  dialBackgroundColor: const Color(0xFF2A2A35),
                                  dialHandColor: const Color(0xFF7C3AED),
                                  dialTextColor: Colors.white,
                                  hourMinuteShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                  hourMinuteColor: MaterialStateColor.resolveWith((states) => 
                                      states.contains(MaterialState.selected) ? const Color(0xFF7C3AED).withOpacity(0.2) : const Color(0xFF2A2A35)),
                                  hourMinuteTextColor: MaterialStateColor.resolveWith((states) => 
                                      states.contains(MaterialState.selected) ? const Color(0xFF7C3AED) : Colors.white),
                                  dayPeriodShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                  dayPeriodColor: MaterialStateColor.resolveWith((states) => 
                                      states.contains(MaterialState.selected) ? const Color(0xFF7C3AED) : Colors.transparent),
                                  dayPeriodTextColor: MaterialStateColor.resolveWith((states) => 
                                      states.contains(MaterialState.selected) ? Colors.white : Colors.white70),
                                  dayPeriodBorderSide: const BorderSide(color: Color(0xFF7C3AED)),
                                ),
                              ),
                              child: child!,
                            ),
                          ),
                        );
                      },
                    );
                    if (time != null) {
                      onDateChanged(DateTime(
                        selectedDate.year, selectedDate.month, selectedDate.day,
                        time.hour, time.minute,
                      ));
                    }
                  },
                  child: _buildValueBox(
                    label: 'Hora',
                    value: (selectedDate.hour == 23 && selectedDate.minute == 59)
                      ? "DURANTE EL DÍA"
                      : DateFormat('hh:mm a', 'es').format(selectedDate).toUpperCase(),
                    icon: Icons.access_time_rounded,
                  ),
                ),
                const SizedBox(height: 8),
                _buildTimeQuickSelect(
                  setDialogState: setDialogState,
                  selectedDate: selectedDate,
                  onTimeSelected: (newDate) => onDateChanged(newDate),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _buildField(obsController, 'Observaciones', icon: Icons.comment_outlined),
    ];
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

  // MÉTODOS DE AGRUPACIÓN (Steve Jobs Vision)

  Map<String, List<OrderModel>> _groupOrders(List<OrderModel> orders) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Calcular inicio y fin de la semana actual (Lunes a Domingo)
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final weekLabel = "ESTA SEMANA (${DateFormat('dd/MM', 'es').format(monday)} - ${DateFormat('dd/MM', 'es').format(sunday)})";

    // El orden de las llaves define el orden de aparición en el Map si se itera sobre keys
    final Map<String, List<OrderModel>> groups = {
      weekLabel: [],
      '🔴 CON HORA DE ENTREGA': [],
      '🚀 MÁS ADELANTE': [],
      '⚠️ ATRASADOS': [],
      '✅ ENTREGADOS': [],
    };

    for (var order in orders) {
      if (order.status == OrderStatus.ENTREGADO) {
        groups['✅ ENTREGADOS']!.add(order);
        continue;
      }

      final dueDate = DateTime(order.deliveryDueAt.year, order.deliveryDueAt.month, order.deliveryDueAt.day);
      
      // 1. Clasificación por Prioridad (Si tiene hora específica)
      if (order.deliveryDueAt.hour != 23 || order.deliveryDueAt.minute != 59) {
        groups['🔴 CON HORA DE ENTREGA']!.add(order);
      } 

      // 2. Clasificación Temporal
      if (dueDate.isBefore(monday)) {
        // Pedidos de semanas/meses anteriores
        groups['⚠️ ATRASADOS']!.add(order);
      } else if (dueDate.isBefore(sunday) || dueDate.isAtSameMomentAs(sunday)) {
        // Dentro de la semana actual (Lunes a Domingo)
        groups[weekLabel]!.add(order);
      } else {
        // Futuro
        groups['🚀 MÁS ADELANTE']!.add(order);
      }
    }

    return groups;
  }

  Widget _buildGroupHeader(String title, int count, Color color, bool isCollapsed) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 16.0, left: 4.0),
      child: InkWell(
        onTap: () {
          setState(() {
            if (_collapsedGroups.contains(title)) {
              _collapsedGroups.remove(title);
            } else {
              _collapsedGroups.add(title);
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: isCollapsed ? -0.25 : 0, // -90 grados si está colapsado
              child: Icon(Icons.keyboard_arrow_down_rounded, color: color, size: 24),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 1),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Expanded(child: Divider(indent: 20, color: Colors.white10, thickness: 0.5)),
          ],
        ),
      ),
    );
  }

  Color _getGroupColor(String category) {
    if (category.contains('HORA DE') || category.contains('ATRASADOS')) return Colors.redAccent;
    if (category.contains('HOY')) return const Color(0xFF7C3AED);
    if (category.contains('MAÑANA')) return Colors.orangeAccent;
    if (category.contains('SEMANA')) return Colors.tealAccent;
    if (category.contains('ADELANTE')) return Colors.blueAccent;
    if (category.contains('ENTREGADOS')) return Colors.white30;
    return Colors.blueAccent;
  }
}
