import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart'; // Importante para tipos de archivo
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/order_service.dart';
import '../services/n8n_service.dart'; // Servicio N8n
import 'qc_order_card.dart';

class GeneratorView extends StatefulWidget {
// ... resto de imports igual
  final UserModel currentUser;
  const GeneratorView({super.key, required this.currentUser});

  @override
  State<GeneratorView> createState() => _GeneratorViewState();
}

class _GeneratorViewState extends State<GeneratorView> {
  final OrderService _orderService = OrderService();
  final N8nService _n8nService = N8nService(); // Instancia del servicio
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  OrderStatus? _statusFilter;
  bool _sortByDelivery = false; // false = createdAt DESC, true = deliveryDueAt ASC

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  void _showGenerationDialog(OrderModel order) {
    String? tempAudioUrl = order.baseAudioUrl;
    bool isUploading = false;
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF16161A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Procesar Pedido #${order.id}', 
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
                      maxLines: 8, 
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  const Text("ARCHIVO ADJUNTO", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  if (order.scriptFileUrl != null && order.scriptFileUrl!.isNotEmpty)
                    Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _orderService.openUrl(order.scriptFileUrl),
                          icon: const Icon(Icons.file_present_rounded),
                          label: const Text("Ver Documento (PDF/Word)"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2A2A35), 
                            foregroundColor: Colors.blueAccent,
                            minimumSize: const Size(double.infinity, 45),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                    )
                  else
                    const Text("No hay archivo adjunto", style: TextStyle(color: Colors.white24, fontSize: 13, fontStyle: FontStyle.italic)),

                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 20),

                  // Subida de Audio
                  const Text("AUDIO GENERADO", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  
                  if (tempAudioUrl != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text("Audio cargado: ${tempAudioUrl!.split('/').last}", style: const TextStyle(color: Colors.green, fontSize: 13), overflow: TextOverflow.ellipsis)),
                          IconButton(
                            icon: const Icon(Icons.play_arrow, color: Colors.white),
                            onPressed: () => _orderService.openUrl(tempAudioUrl),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => setDialogState(() => tempAudioUrl = null),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: OutlinedButton.icon(
                      onPressed: isUploading ? null : () async {
                        setDialogState(() => isUploading = true);
                        
                        // 1. Selección local del archivo
                        FilePickerResult? result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['mp3', 'wav', 'm4a'],
                        );

                        if (result != null) {
                           final file = result.files.first;
                           print("Seleccionado audio: ${file.name} (${file.size} bytes)"); // LOG EXTRA
                           try {
                             // 2. Subida a n8n
                             print("Invocando N8nService para subir audio..."); // LOG EXTRA
                             final n8nUrl = await _n8nService.uploadFile(
                               clientName: order.clientName,
                               orderId: order.id.toString(),
                               file: file,
                               structuralReference: 'base_audio_url', 
                             );
                             print("Respuesta N8n recibida: $n8nUrl"); // LOG EXTRA

                             if (n8nUrl != null) {
                               setDialogState(() {
                                 tempAudioUrl = n8nUrl;
                                 isUploading = false;
                               });
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Audio subido a n8n correctamente"), backgroundColor: Colors.green));
                             } else {
                               // Si n8n no devuelve URL (fallo en flujo de retorno), no podemos mostrarlo.
                               setDialogState(() => isUploading = false);
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Audio enviado, pero n8n no devolvió el enlace."), backgroundColor: Colors.orange));
                             }
                           } catch (e) {
                             setDialogState(() => isUploading = false);
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al subir: $e"), backgroundColor: Colors.red));
                           }
                        } else {
                          setDialogState(() => isUploading = false);
                        }
                      },
                      icon: isUploading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload_file),
                      label: Text(tempAudioUrl == null ? "SUBIR AUDIO (MP3/WAV)" : "REEMPLAZAR AUDIO"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // Botón Listo
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (tempAudioUrl != null && !isProcessing) 
                          ? () async {
                              setDialogState(() => isProcessing = true);
                              try {
                                await _orderService.sendToEdition(order.id!, tempAudioUrl!);
                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enviado a edición"), backgroundColor: Colors.blue));
                                }
                              } catch (e) {
                                setDialogState(() => isProcessing = false);
                              }
                            } 
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        disabledBackgroundColor: Colors.white10,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isProcessing 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text("LISTO (ENVIAR A EDITOR)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
            const Text('Panel de Generación', 
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // Buscador y Filtros
            _buildFilterBar(),
            
            const SizedBox(height: 16),
            
            Expanded(
              child: StreamBuilder<List<OrderModel>>(
                stream: _orderService.ordersStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
                  }
                  
                  var orders = snapshot.data ?? [];

                  // 1. Filtrado de Base (Solo lo que pertenece al generador o admin)
                  orders = orders.where((o) => 
                    (widget.currentUser.role == UserRole.admin || o.generatorId == widget.currentUser.id)
                  ).toList();

                  // 2. Filtrado por Búsqueda
                  if (_searchQuery.isNotEmpty) {
                    orders = orders.where((o) => 
                      o.clientName.toLowerCase().contains(_searchQuery) || (o.id?.toString().contains(_searchQuery) ?? false)
                    ).toList();
                  }

                  // 3. Filtrado por Estado
                  if (_statusFilter != null) {
                    orders = orders.where((o) => o.status == _statusFilter).toList();
                  } else {
                    // Por defecto: Generación, Edición y Audio Listo
                    orders = orders.where((o) => 
                      o.status == OrderStatus.EN_GENERACION || o.status == OrderStatus.EDICION || o.status == OrderStatus.AUDIO_LISTO
                    ).toList();
                  }

                  // 4. Ordenamiento
                  if (_sortByDelivery) {
                    orders.sort((a, b) => a.deliveryDueAt.compareTo(b.deliveryDueAt));
                  } else {
                    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  }

                  if (orders.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt_outlined, size: 80, color: Colors.white10),
                          SizedBox(height: 16),
                          Text('No hay trabajos que coincidan', style: TextStyle(color: Colors.white38)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      return QCOrderCard(
                        order: orders[index],
                        showAssigners: false,
                        onTap: () => _showGenerationDialog(orders[index]),
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
        _filterChip("TODO", null),
        _filterChip("GENERACIÓN", OrderStatus.EN_GENERACION),
        _filterChip("EDICIÓN", OrderStatus.EDICION),
        _filterChip("LISTO", OrderStatus.AUDIO_LISTO),
        
        const VerticalDivider(color: Colors.white10, width: 10),

        IconButton(
          tooltip: "Más recientes",
          icon: Icon(Icons.history, color: !_sortByDelivery ? Colors.amberAccent : Colors.white24),
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
      selectedColor: Colors.amber.withOpacity(0.4),
      backgroundColor: Colors.white.withOpacity(0.05),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    );
  }
}
