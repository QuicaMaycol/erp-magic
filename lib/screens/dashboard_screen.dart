import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/order_service.dart';
import '../services/auth_service.dart';
import '../services/n8n_service.dart';
import '../widgets/order_card_premium.dart';

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

  void showOrderForm({OrderModel? order}) {
    _showOrderForm(order: order);
  }

  void _showOrderDetail(OrderModel order) {
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
                          if (order.price != null)
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
                              onPressed: () => _orderService.openUrl(order.baseAudioUrl),
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
                              onPressed: () => _orderService.openUrl(order.finalAudioUrl),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text("Descargar"),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: BorderSide(color: Colors.redAccent.withOpacity(0.5))),
                            ),
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
                              onPressed: () => _orderService.openUrl(order.projectFileUrl),
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
            if (order.status == OrderStatus.EN_REVISION && (_currentUser?.role == UserRole.admin || _currentUser?.role == UserRole.qc))
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
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildField(clientController, 'Cliente', icon: Icons.person_outline),
                    const SizedBox(height: 12),
                    _buildField(scriptController, 'Texto / Guion', maxLines: 3, icon: Icons.description_outlined),
                    const SizedBox(height: 12),
                    _buildField(productController, 'Producto', icon: Icons.inventory_2_outlined),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(child: _buildField(countryController, 'País', icon: Icons.public)),
                        const SizedBox(width: 12),
                         Expanded(child: _buildField(priceController, 'Precio', icon: Icons.attach_money, keyboardType: TextInputType.number)),
                       ],
                     ),
                     const SizedBox(height: 12),
                     Row(
                       children: [
                         Expanded(child: _buildField(phoneController, 'WhatsApp/Celular', icon: Icons.phone_android, keyboardType: TextInputType.phone)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField(paymentController, 'Medio de Pago', icon: Icons.payment)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Botón de selección de archivo (n8n integration)
                    InkWell(
                      onTap: isUploading ? null : () async {
                        FilePickerResult? result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'mp3'],
                        );
                        if (result != null) {
                          setDialogState(() {
                            selectedFile = result.files.first;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (selectedFile != null || hasExistingFile) ? Colors.green.withOpacity(0.5) : Colors.transparent
                          ),
                        ),
                        child: Row(
                          children: [
                            if (isUploading)
                               const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)))
                            else
                              Icon(
                                (selectedFile != null || hasExistingFile) ? Icons.check_circle : Icons.attach_file,
                                color: (selectedFile != null || hasExistingFile) ? Colors.green : const Color(0xFF7C3AED),
                                size: 20
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                selectedFile != null 
                                  ? "Seleccionado: ${selectedFile!.name}" 
                                  : (hasExistingFile ? "Archivo adjunto previamente" : "Adjuntar Archivo"),
                                style: TextStyle(
                                  color: (selectedFile != null || hasExistingFile) ? Colors.green : Colors.white70,
                                  fontSize: 14
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (selectedFile != null && !isUploading)
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                                onPressed: () => setDialogState(() => selectedFile = null),
                              )
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    Row(
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
                                setDialogState(() => selectedDate = DateTime(
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
                          child: InkWell(
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
                                setDialogState(() => selectedDate = DateTime(
                                  selectedDate.year, selectedDate.month, selectedDate.day,
                                  time.hour, time.minute,
                                ));
                              }
                            },
                            child: _buildValueBox(
                              label: 'Hora',
                              value: DateFormat('hh:mm a', 'es').format(selectedDate).toUpperCase(),
                              icon: Icons.access_time_rounded,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildField(obsController, 'Observaciones', icon: Icons.comment_outlined),
                  ],
                ),
              ),
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
                      // Regla simple: si es mp3 -> base_audio, si no -> script_file
                      String ref = 'script_file_url';
                      if (selectedFile!.extension == 'mp3' || selectedFile!.extension == 'wav') {
                        ref = 'base_audio_url';
                      }

                      try {
                        final n8nUrl = await _n8nService.uploadFile(
                          clientName: savedOrder.clientName,
                          orderId: savedOrder.id.toString(),
                          file: selectedFile!,
                          structuralReference: ref,
                        );

                        if (n8nUrl != null) {
                          // Si n8n devolvió URL, actualizamos Supabase
                          print("Actualizando orden con URL de n8n: $n8nUrl");
                          OrderModel updatedOrder;
                          if (ref == 'script_file_url') {
                             updatedOrder = savedOrder.copyWith(scriptFileUrl: n8nUrl);
                          } else {
                             updatedOrder = savedOrder.copyWith(baseAudioUrl: n8nUrl);
                          }
                          await _orderService.updateOrder(updatedOrder);
                        } else {
                           print("n8n no devolvió URL, el archivo se envió pero no se enlazó.");
                        }

                      } catch (n8nError) {
                        print("Advertencia n8n: $n8nError");
                        // No lanzamos error para permitir que el flujo de guardado continúe
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Orden guardada, pero hubo un problema enviando el archivo a n8n.'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 5),
                            )
                          );
                        }
                        // Regresamos aquí para cerrar el diálogo
                        if (!mounted) return;
                        Navigator.pop(context);
                        refreshData();
                        return;
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
    
    // Filtramos las órdenes según el buscador
    final filteredOrders = _orders.where((order) {
      if (_searchQuery.isEmpty) return true;
      return order.clientName.toLowerCase().contains(_searchQuery) ||
             (order.id?.toString().contains(_searchQuery) ?? false);
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
            
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<List<OrderModel>>(
                stream: _orderService.ordersStream,
                builder: (context, snapshot) {
                  var sourceList = snapshot.hasData ? snapshot.data! : _orders;
                   
                  // 1. Filtrado por Búsqueda
                  if (_searchQuery.isNotEmpty) {
                    sourceList = sourceList.where((o) => 
                      o.clientName.toLowerCase().contains(_searchQuery) || (o.id?.toString().contains(_searchQuery) ?? false)
                    ).toList();
                  }

                  // 2. Filtrado por Estado
                  if (_statusFilter != null) {
                    sourceList = sourceList.where((o) => o.status == _statusFilter).toList();
                  } else {
                    sourceList = sourceList.where((o) => o.status != OrderStatus.ANULADO).toList();
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
                  
                  // Siempre mostramos ListView, independientemente del tamaño de pantalla
                  return ListView.builder(
                    itemCount: sourceList.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16.0), // Espaciado entre items
                      child: OrderCardPremium(
                        order: sourceList[index], 
                        onEdit: () => _showOrderForm(order: sourceList[index]),
                        onTap: () => _showOrderDetail(sourceList[index]),
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
                        showEditButton: _currentUser?.role == UserRole.admin || _currentUser?.role == UserRole.qc,
                      ),
                    ),
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
