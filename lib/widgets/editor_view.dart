import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/order_service.dart';
import '../services/n8n_service.dart'; // Importamos N8nService
import 'qc_order_card.dart';

class EditorView extends StatefulWidget {
  final UserModel currentUser;
  const EditorView({super.key, required this.currentUser});

  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> {
  final OrderService _orderService = OrderService();
  final N8nService _n8nService = N8nService();
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

  void _showEditionDialog(OrderModel order) {
    String? tempFinalAudioUrl = order.finalAudioUrl;
    String? tempProjectUrl = order.projectFileUrl; 
    bool isUploadingProject = false; // Estado independiente para Proyecto
    bool isUploadingFinal = false;   // Estado independiente para Audio Final
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF16161A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Editar Pedido #${order.id}', 
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

                  const SizedBox(height: 20),

                  // Escuchar Audio Base (del Generador)
                  const Text("AUDIO BASE (LOCUCIÓN)", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  if (order.baseAudioUrl != null)
                    Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _orderService.openUrl(order.baseAudioUrl),
                          icon: const Icon(Icons.play_circle_fill, color: Colors.amber),
                          label: const Text("Escuchar Locución Original"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.withOpacity(0.1),
                            foregroundColor: Colors.amber,
                            minimumSize: const Size(double.infinity, 45),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _orderService.openUrl(order.baseAudioUrl),
                          icon: const Icon(Icons.download_rounded, color: Colors.blueAccent),
                          label: const Text("Descargar Locución"),
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
                    const Text("No hay audio base cargado", style: TextStyle(color: Colors.white24, fontSize: 13, fontStyle: FontStyle.italic)),

                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 20),

                  // Proyecto Editable
                  const Text("ARCHIVO DE PROYECTO (.AUP3 / ZIP)", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  if (tempProjectUrl != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_zip, color: Colors.purple, size: 20),
                          const SizedBox(width: 12),
                          const Expanded(child: Text("Proyecto cargado", style: TextStyle(color: Colors.purple, fontSize: 13))),
                          IconButton(
                            icon: const Icon(Icons.download, color: Colors.white),
                            onPressed: () => _orderService.openUrl(tempProjectUrl),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => setDialogState(() => tempProjectUrl = null),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: OutlinedButton.icon(
                      onPressed: (isUploadingProject || isUploadingFinal) ? null : () async {
                        setDialogState(() => isUploadingProject = true);
                        FilePickerResult? result = await FilePicker.platform.pickFiles(
                          type: FileType.any, 
                        );

                        if (result != null) {
                           try {
                             final n8nUrl = await _n8nService.uploadFile(
                               clientName: order.clientName,
                               orderId: order.id.toString(),
                               file: result.files.first,
                               structuralReference: 'project_file_url', 
                             );

                             if (n8nUrl != null) {
                               setDialogState(() {
                                 tempProjectUrl = n8nUrl;
                                 isUploadingProject = false;
                               });
                               // Guardar URL del proyecto inmediatamente
                               await _orderService.updateOrder(order.copyWith(projectFileUrl: n8nUrl));
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Proyecto subido correctamente"), backgroundColor: Colors.green));
                             } else {
                               setDialogState(() => isUploadingProject = false);
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Proyecto enviado a n8n (sin enlace de retorno)"), backgroundColor: Colors.orange));
                             }
                           } catch (e) {
                             setDialogState(() => isUploadingProject = false);
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                           }
                        } else {
                          setDialogState(() => isUploadingProject = false);
                        }
                      },
                      icon: isUploadingProject 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload_file),
                      label: Text(tempProjectUrl == null ? "SUBIR PROYECTO EDITABLE" : "REEMPLAZAR PROYECTO"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.purpleAccent,
                        side: BorderSide(color: Colors.purpleAccent.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 20),

                  // Subida de Audio Final
                  const Text("AUDIO FINAL EDITADO", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  
                  if (tempFinalAudioUrl != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.music_video_rounded, color: Colors.blue, size: 20),
                          const SizedBox(width: 12),
                          const Expanded(child: Text("Edición cargada", style: TextStyle(color: Colors.blue, fontSize: 13))),
                          IconButton(
                            icon: const Icon(Icons.play_arrow, color: Colors.white),
                            onPressed: () => _orderService.openUrl(tempFinalAudioUrl),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => setDialogState(() => tempFinalAudioUrl = null),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: OutlinedButton.icon(
                      onPressed: (isUploadingFinal || isUploadingProject) ? null : () async {
                        setDialogState(() => isUploadingFinal = true);
                        
                        // Selección local del archivo
                        FilePickerResult? result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['mp3', 'wav', 'm4a'],
                        );

                        if (result != null) {
                           try {
                             final n8nUrl = await _n8nService.uploadFile(
                               clientName: order.clientName,
                               orderId: order.id.toString(),
                               file: result.files.first,
                               structuralReference: 'final_audio_url', 
                             );

                             if (n8nUrl != null) {
                               setDialogState(() {
                                 tempFinalAudioUrl = n8nUrl;
                                 isUploadingFinal = false;
                               });
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Audio final subido a n8n correctamente"), backgroundColor: Colors.green));
                             } else {
                               setDialogState(() => isUploadingFinal = false);
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Audio enviado, pero n8n no devolvió el enlace."), backgroundColor: Colors.orange));
                             }
                           } catch (e) {
                             setDialogState(() => isUploadingFinal = false);
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al subir: $e"), backgroundColor: Colors.red));
                           }
                        } else {
                          setDialogState(() => isUploadingFinal = false);
                        }
                      },
                      icon: isUploadingFinal 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.cloud_upload_outlined),
                      label: Text(tempFinalAudioUrl == null ? "SUBIR PRODUCTO FINAL" : "REEMPLAZAR ARCHIVO"),
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
                      onPressed: (tempFinalAudioUrl != null && !isProcessing) 
                          ? () async {
                              setDialogState(() => isProcessing = true);
                              try {
                                await _orderService.completeEdition(order.id!, tempFinalAudioUrl!);
                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedido finalizado con éxito"), backgroundColor: Colors.green));
                                }
                              } catch (e) {
                                setDialogState(() => isProcessing = false);
                              }
                            } 
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        disabledBackgroundColor: Colors.white10,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isProcessing 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text("LISTO (ENTREGAR AUDIO)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
            const Text('Panel de Edición', 
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
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
                  }
                  
                  var orders = snapshot.data ?? [];

                  // 1. Filtrado de Base (Solo lo que pertenece al editor o admin)
                  orders = orders.where((o) => 
                    (widget.currentUser.role == UserRole.admin || o.editorId == widget.currentUser.id)
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
                    // Por defecto: Edición y Audio Listo
                    orders = orders.where((o) => 
                      o.status == OrderStatus.EDICION || o.status == OrderStatus.AUDIO_LISTO
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
                          Icon(Icons.music_note_outlined, size: 80, color: Colors.white10),
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
                        onTap: () => _showEditionDialog(orders[index]),
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
              hintText: 'Buscar trabajos...',
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
        _filterChip("EDICIÓN", OrderStatus.EDICION),
        _filterChip("LISTO", OrderStatus.AUDIO_LISTO),
        
        const VerticalDivider(color: Colors.white10, width: 10),

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
