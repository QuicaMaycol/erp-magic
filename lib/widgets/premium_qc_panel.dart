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
import '../services/upload_service.dart';
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
  List<UserModel> _allStaff = [];
  UserModel? _currentUser;
  String _searchQuery = '';
  OrderStatus? _statusFilter;
  
  bool _sortByDelivery = false; // false = createdAt DESC, true = deliveryDueAt ASC
  final Set<String> _collapsedGroups = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      if (mounted) {
        setState(() => _searchQuery = _searchController.text.toLowerCase());
      }
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
        _allStaff = [...gens, ...eds];
        _allStaff.sort((a, b) => a.name.compareTo(b.name));
        _currentUser = user;
      });
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
                _orderService.openUrl(url, forceDownload: true);
              },
            ),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.add_to_drive, color: Colors.greenAccent),
              title: const Text('Google Drive', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Subir a mi unidad de Drive', style: TextStyle(color: Colors.white38, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _orderService.openUrl(url, forceDownload: true); 
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

  void _showAssignmentDialog(OrderModel order) {
    UserModel? selectedGen = _allStaff.firstWhere((u) => u.id == order.generatorId, orElse: () => _allStaff.isNotEmpty ? _allStaff.first : UserModel(id: '', name: '', email: '', role: UserRole.generador, active: true));
    UserModel? selectedEd = _allStaff.firstWhere((u) => u.id == order.editorId, orElse: () => _allStaff.isNotEmpty ? _allStaff.first : UserModel(id: '', name: '', email: '', role: UserRole.editor, active: true));

    
    String? tempGenId = order.generatorId;
    String? tempEdId = order.editorId;
    String? tempFinalAudioUrl = order.finalAudioUrl;
    String? tempAudioMuestraUrl = order.audioMuestraUrl;
    String? tempProjectUrl = order.projectFileUrl;
    final TextEditingController observationController = TextEditingController();
    bool isProcessing = false; 
    bool isUploadingFinal = false;
    bool isUploadingMuestra = false;
    bool isUploadingProject = false;
    bool isDraggingFinal = false;
    bool isDraggingMuestra = false;
    bool isDraggingProject = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B1B21),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Gestionar Pedido #${order.id}', 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: ListenableBuilder(
                listenable: UploadService(),
                builder: (context, _) {
                  return SizedBox(
                    width: 500,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  // Info del Cliente y Pedido
                  _buildDetailRow("CLIENTE", order.clientName),
                  const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildDetailRow("INGRESO", DateFormat('dd/MM - HH:mm').format(order.createdAt))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildDetailRow(
                          "ENTREGA", 
                          _formatDateWithDay(order.deliveryDueAt),
                          valueColor: Colors.orangeAccent
                        )),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Texto / Guion
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
                        overflow: TextOverflow.ellipsis
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                  const SizedBox(height: 16),

                  // Archivo Adjunto
                  const Text("ARCHIVO ADJUNTO", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  if (order.scriptFileUrl != null && order.scriptFileUrl!.isNotEmpty)
                    Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _orderService.openUrl(order.scriptFileUrl),
                          icon: const Icon(Icons.file_present_rounded),
                          label: const Text("Ver Documento Adjunto (PDF/Word)"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2A2A35), 
                            foregroundColor: Colors.blueAccent,
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 45),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.blueAccent.withOpacity(0.3))),
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

                  // SECCIÓN DE AUDIOS Y ARCHIVOS (SIEMPRE VISIBLE)
                  if (true) ...[
                    const Text("AUDIOS Y PROYECTO", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    
                    // 1. Locución Base
                    if (order.baseAudioUrl != null) ...[
                      const Text("LOCUCIÓN BASE (VOZ)", style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
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
                              onPressed: () => _showDownloadOptions(order.baseAudioUrl, "Locución Base"),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text("Descargar"),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.amber, side: BorderSide(color: Colors.amber.withOpacity(0.5))),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 2. Producto Final (EDITADO)
                    const Text("PRODUCTO FINAL (EDITADO)", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (tempFinalAudioUrl != null)
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _orderService.openUrl(tempFinalAudioUrl),
                                  icon: const Icon(Icons.play_circle_fill),
                                  label: const Text("Escuchar"),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent.withOpacity(0.1), foregroundColor: Colors.blueAccent),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showDownloadOptions(tempFinalAudioUrl, "Producto Final"),
                                  icon: const Icon(Icons.download_rounded),
                                  label: const Text("Descargar"),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.blueAccent, side: BorderSide(color: Colors.blueAccent.withOpacity(0.5))),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_currentUser?.role == UserRole.admin || _currentUser?.role == UserRole.recepcion || _currentUser?.role == UserRole.control_calidad)
                                IconButton(
                                  onPressed: () async {
                                    final confirmed = await _showConfirmDelete(context, "audio final");
                                    if (confirmed == true) {
                                      setDialogState(() => tempFinalAudioUrl = null);
                                      try {
                                        await _orderService.updateAudioFinal(order.id!, null);
                                      } catch (e) {
                                        print("Error eliminando audio final: $e");
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  tooltip: "Eliminar Audio Final",
                                ),
                            ],
                          ),
                           const SizedBox(height: 8),
                          // Botón para REEMPLAZAR (Siempre visible si hay uno cargado)
                          if (_currentUser?.role == UserRole.admin || _currentUser?.role == UserRole.recepcion || _currentUser?.role == UserRole.control_calidad)
                            SizedBox(
                              width: double.infinity,
                              child: DropTarget(
                                onDragDone: (details) async {
                                  final isQueued = UploadService().isUploading(order.id.toString(), 'final_audio_url');
                                  if (details.files.isNotEmpty && !isUploadingFinal && !isQueued) {
                                    final file = details.files.first;
                                    setDialogState(() {
                                      isDraggingFinal = false;
                                      isUploadingFinal = true;
                                    });
                                    try {
                                      final bytes = await file.readAsBytes();
                                      final platformFile = PlatformFile(name: file.name, size: bytes.length, bytes: bytes);
                                      
                                      UploadService().startUpload(
                                        clientName: order.clientName,
                                        orderId: order.id.toString(),
                                        file: platformFile,
                                        structuralReference: 'final_audio_url', 
                                      );

                                      if (context.mounted) {
                                        Navigator.pop(context); // Cerrar modal inmediatamente
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("🚀 Subida de audio final iniciada en segundo plano. Se te avisará al terminar."), 
                                            backgroundColor: Color(0xFF7C3AED),
                                            duration: Duration(seconds: 4),
                                          )
                                        );
                                      }
                                    } catch (e) {
                                      print("Error drop final replacement: $e");
                                    } finally {
                                      setDialogState(() => isUploadingFinal = false);
                                    }
                                  }
                                },
                                onDragEntered: (details) => setDialogState(() => isDraggingFinal = true),
                                onDragExited: (details) => setDialogState(() => isDraggingFinal = false),
                                child: OutlinedButton.icon(
                                  onPressed: (isUploadingFinal || UploadService().isUploading(order.id.toString(), 'final_audio_url')) ? null : () async {
                                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: ['mp3', 'wav', 'm4a', 'zip'],
                                      withData: true, // Requerido para Web
                                    );

                                    if (result != null) {
                                      setDialogState(() => isUploadingFinal = true);
                                      final file = result.files.first;
                                      UploadService().startUpload(
                                        clientName: order.clientName,
                                        orderId: order.id.toString(),
                                        file: file,
                                        structuralReference: 'final_audio_url', 
                                      );

                                      if (context.mounted) {
                                        Navigator.pop(context); // Cerrar modal inmediatamente
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("🚀 Subida de audio final iniciada en segundo plano. Se te avisará al terminar."), 
                                            backgroundColor: Color(0xFF7C3AED),
                                            duration: Duration(seconds: 4),
                                          )
                                        );
                                      }
                                      setDialogState(() => isUploadingFinal = false);
                                    }
                                  },
                                  icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                                  label: Text(
                                    isDraggingFinal ? "¡SUELTA AQUÍ!" : ((isUploadingFinal || UploadService().isUploading(order.id.toString(), 'final_audio_url')) ? "Subiendo..." : "SUBIR AUDIO FINAL"), 
                                    style: const TextStyle(fontSize: 12)
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: isDraggingFinal ? Colors.blueAccent.withOpacity(0.1) : Colors.transparent,
                                    foregroundColor: Colors.blueAccent,
                                    side: BorderSide(color: isDraggingFinal ? Colors.blueAccent : Colors.blueAccent.withOpacity(0.3)),
                                    minimumSize: const Size(double.infinity, 40),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    else if (_currentUser?.role == UserRole.admin || _currentUser?.role == UserRole.recepcion || _currentUser?.role == UserRole.control_calidad)
                      SizedBox(
                        width: double.infinity,
                        child: DropTarget(
                          onDragDone: (details) async {
                            final isQueued = UploadService().isUploading(order.id.toString(), 'final_audio_url');
                            if (details.files.isNotEmpty && !isUploadingFinal && !isQueued) {
                              final file = details.files.first;
                              setDialogState(() {
                                isDraggingFinal = false;
                                isUploadingFinal = true;
                              });
                              try {
                                final bytes = await file.readAsBytes();
                                final platformFile = PlatformFile(name: file.name, size: bytes.length, bytes: bytes);
                                
                                UploadService().startUpload(
                                  clientName: order.clientName,
                                  orderId: order.id.toString(),
                                  file: platformFile,
                                  structuralReference: 'final_audio_url', 
                                );

                                if (context.mounted) {
                                  Navigator.pop(context); // Cerrar modal inmediatamente
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("🚀 Subida de audio final iniciada en segundo plano. Se te avisará al terminar."), 
                                      backgroundColor: Color(0xFF7C3AED),
                                      duration: Duration(seconds: 4),
                                    )
                                  );
                                }
                              } catch (e) {
                                print("Error drop final upload: $e");
                              } finally {
                                setDialogState(() => isUploadingFinal = false);
                              }
                            }
                          },
                          onDragEntered: (details) => setDialogState(() => isDraggingFinal = true),
                          onDragExited: (details) => setDialogState(() => isDraggingFinal = false),
                          child: OutlinedButton.icon(
                            onPressed: (isUploadingFinal || UploadService().isUploading(order.id.toString(), 'final_audio_url')) ? null : () async {
                              FilePickerResult? result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['mp3', 'wav', 'm4a', 'zip'],
                                withData: true, // Requerido para Web
                              );

                              if (result != null) {
                                setDialogState(() => isUploadingFinal = true);
                                final file = result.files.first;
                                UploadService().startUpload(
                                  clientName: order.clientName,
                                  orderId: order.id.toString(),
                                  file: file,
                                  structuralReference: 'final_audio_url', 
                                );

                                if (context.mounted) {
                                  Navigator.pop(context); // Cerrar modal inmediatamente
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("🚀 Subida de audio final iniciada en segundo plano. Se te avisará al terminar."), 
                                      backgroundColor: Color(0xFF7C3AED),
                                      duration: Duration(seconds: 4),
                                    )
                                  );
                                }
                                setDialogState(() => isUploadingFinal = false);
                              }
                            },
                            icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                            label: Text(
                              isDraggingFinal ? "¡SUELTA AQUÍ!" : ((isUploadingFinal || UploadService().isUploading(order.id.toString(), 'final_audio_url')) ? "Subiendo..." : "SUBIR AUDIO FINAL"), 
                              style: const TextStyle(fontSize: 12)
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: isDraggingFinal ? Colors.blueAccent.withOpacity(0.1) : Colors.transparent,
                              foregroundColor: Colors.blueAccent,
                              side: BorderSide(color: isDraggingFinal ? Colors.blueAccent : Colors.blueAccent.withOpacity(0.3)),
                              minimumSize: const Size(double.infinity, 40),
                            ),
                          ),
                        ),
                      ),

                        const SizedBox(height: 16),

                        // 3. Audio de Muestra (NUEVO)
                        const Text("AUDIO DE MUESTRA (PARA CLIENTE)", style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (tempAudioMuestraUrl != null)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _orderService.openUrl(tempAudioMuestraUrl),
                                  icon: const Icon(Icons.play_circle_fill),
                                  label: const Text("Escuchar"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal.withOpacity(0.1), 
                                    foregroundColor: Colors.tealAccent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showDownloadOptions(tempAudioMuestraUrl, "Audio de Muestra"),
                                  icon: const Icon(Icons.download_rounded),
                                  label: const Text("Descargar"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.tealAccent, 
                                    side: BorderSide(color: Colors.tealAccent.withOpacity(0.5)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_currentUser?.role == UserRole.admin || _currentUser?.role == UserRole.recepcion || _currentUser?.role == UserRole.control_calidad)
                                IconButton(
                                  onPressed: () async {
                                    final confirmed = await _showConfirmDelete(context, "audio de muestra");
                                    if (confirmed == true) {
                                      setDialogState(() => tempAudioMuestraUrl = null);
                                      try {
                                        await _orderService.updateAudioMuestra(order.id!, null);
                                      } catch (e) {
                                        print("Error eliminando muestra: $e");
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                  tooltip: "Eliminar Muestra",
                                ),
                            ],
                          )
                        else if (_currentUser?.role == UserRole.admin || _currentUser?.role == UserRole.recepcion || _currentUser?.role == UserRole.control_calidad)
                          Column(
                            children: [
                              DropTarget(
                                onDragDone: (details) async {
                                  final isQueued = UploadService().isUploading(order.id.toString(), 'audio_muestra_url');
                                  if (details.files.isNotEmpty && !isUploadingMuestra && !isQueued) {
                                    final file = details.files.first;
                                    setDialogState(() {
                                      isDraggingMuestra = false;
                                      isUploadingMuestra = true;
                                    });
                                    try {
                                      final bytes = await file.readAsBytes();
                                      final platformFile = PlatformFile(name: file.name, size: bytes.length, bytes: bytes);

                                    UploadService().startUpload(
                                      clientName: order.clientName,
                                      orderId: order.id.toString(),
                                      file: platformFile,
                                      structuralReference: 'audio_muestra_url', 
                                    );

                                    if (context.mounted) {
                                      Navigator.pop(context); // Cerrar modal inmediatamente
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("🚀 Subida de muestra iniciada en segundo plano. Se te avisará al terminar."), 
                                          backgroundColor: Color(0xFF10B981),
                                          duration: Duration(seconds: 4),
                                        )
                                      );
                                    }
                                    } catch (e) {
                                      print("Error drop muestra: $e");
                                    } finally {
                                      setDialogState(() => isUploadingMuestra = false);
                                    }
                                  }
                                },
                                onDragEntered: (details) => setDialogState(() => isDraggingMuestra = true),
                                onDragExited: (details) => setDialogState(() => isDraggingMuestra = false),
                                child: OutlinedButton.icon(
                                  onPressed: (isUploadingMuestra || UploadService().isUploading(order.id.toString(), 'audio_muestra_url')) ? null : () async {
                                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: ['mp3', 'wav', 'm4a', 'zip'],
                                      withData: true, // Requerido para Web
                                    );

                                    if (result != null) {
                                      setDialogState(() => isUploadingMuestra = true);
                                      final file = result.files.first;
                                      UploadService().startUpload(
                                        clientName: order.clientName,
                                        orderId: order.id.toString(),
                                        file: file,
                                        structuralReference: 'audio_muestra_url', 
                                      );

                                      if (context.mounted) {
                                        Navigator.pop(context); // Cerrar modal inmediatamente
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("🚀 Subida de muestra iniciada en segundo plano. Se te avisará al terminar."), 
                                            backgroundColor: Color(0xFF10B981),
                                            duration: Duration(seconds: 4),
                                          )
                                        );
                                      }
                                      setDialogState(() => isUploadingMuestra = false);
                                    }
                                  },
                                  icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                                  label: Text(
                                    isDraggingMuestra ? "¡SUELTA AQUÍ!" : ((isUploadingMuestra || UploadService().isUploading(order.id.toString(), 'audio_muestra_url')) ? "Subiendo..." : "SUBIR AUDIO DE MUESTRA"), 
                                    style: const TextStyle(fontSize: 12)
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: isDraggingMuestra ? Colors.tealAccent.withOpacity(0.1) : Colors.transparent,
                                    foregroundColor: Colors.tealAccent,
                                    side: BorderSide(color: isDraggingMuestra ? Colors.tealAccent : Colors.tealAccent.withOpacity(0.3)),
                                    minimumSize: const Size(double.infinity, 40),
                                  ),
                                ),
                              ),
                              if (isDraggingMuestra || isDraggingFinal)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    "Detectado archivo para ${isDraggingMuestra ? 'MUESTRA' : 'AUDIO FINAL'}", 
                                    style: TextStyle(color: isDraggingMuestra ? Colors.tealAccent : Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)
                                  ),
                                ),
                            ],
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(8)),
                            child: const Text("Aún no se ha cargado el audio de muestra", style: TextStyle(color: Colors.white24, fontSize: 11, fontStyle: FontStyle.italic)),
                          ),
                        
                        const SizedBox(height: 16),

                        // 4. Proyecto Editable
                        const Text("PROYECTO EDITABLE (.AUP3 / ZIP)", style: TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (tempProjectUrl != null) ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _orderService.openUrl(tempProjectUrl),
                                  icon: const Icon(Icons.folder_zip, color: Colors.purpleAccent),
                                  label: const Text("Ver Proyecto"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple.withOpacity(0.1), 
                                    foregroundColor: Colors.purpleAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showDownloadOptions(tempProjectUrl, "Archivo de Proyecto"),
                                  icon: const Icon(Icons.download_rounded),
                                  label: const Text("Descargar"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.purpleAccent, 
                                    side: BorderSide(color: Colors.purpleAccent.withOpacity(0.5)),
                                  ),
                                ),
                              ),
                              if (_currentUser?.role == UserRole.admin || 
                                  _currentUser?.role == UserRole.recepcion || 
                                  _currentUser?.role == UserRole.control_calidad)
                                IconButton(
                                  onPressed: () async {
                                    final confirmed = await _showConfirmDelete(context, "proyecto editable");
                                    if (confirmed == true) {
                                      setDialogState(() => tempProjectUrl = null);
                                      try {
                                        await _orderService.updateOrder(order.copyWith(clearProjectFile: true));
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Proyecto eliminado"), backgroundColor: Colors.redAccent));
                                      } catch (e) {
                                        print("Error eliminando proyecto: $e");
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                  tooltip: "Eliminar Proyecto",
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Botón para REEMPLAZAR
                          if (_currentUser?.role == UserRole.admin || _currentUser?.role == UserRole.recepcion || _currentUser?.role == UserRole.control_calidad)
                            SizedBox(
                              width: double.infinity,
                              child: DropTarget(
                                onDragDone: (details) async {
                                  final isQueued = UploadService().isUploading(order.id.toString(), 'project_file_url');
                                  if (details.files.isNotEmpty && !isUploadingProject && !isQueued) {
                                    final file = details.files.first;
                                    setDialogState(() {
                                      isDraggingProject = false;
                                      isUploadingProject = true;
                                    });
                                    try {
                                      final bytes = await file.readAsBytes();
                                      UploadService().startUpload(
                                        clientName: order.clientName,
                                        orderId: order.id.toString(),
                                        file: PlatformFile(name: file.name, size: bytes.length, bytes: bytes),
                                        structuralReference: 'project_file_url', 
                                      );

                                      if (context.mounted) {
                                        Navigator.pop(context); 
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("🚀 Reemplazo de proyecto iniciado"), backgroundColor: Colors.purpleAccent)
                                        );
                                      }
                                    } catch (e) {
                                      print("Error al leer archivo: $e");
                                    } finally {
                                      setDialogState(() => isUploadingProject = false);
                                    }
                                  }
                                },
                                onDragEntered: (details) => setDialogState(() => isDraggingProject = true),
                                onDragExited: (details) => setDialogState(() => isDraggingProject = false),
                                child: OutlinedButton.icon(
                                  onPressed: (isUploadingProject || UploadService().isUploading(order.id.toString(), 'project_file_url')) ? null : () async {
                                    final result = await FilePicker.platform.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: ['aup3', 'zip', 'rar'],
                                      withData: true, // Requerido para Web
                                    );
                                    if (result != null) {
                                      setDialogState(() => isUploadingProject = true);
                                      UploadService().startUpload(
                                        clientName: order.clientName,
                                        orderId: order.id.toString(),
                                        file: result.files.first,
                                        structuralReference: 'project_file_url',
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("🚀 Reemplazo de proyecto iniciado"), backgroundColor: Colors.purpleAccent)
                                        );
                                      }
                                      setDialogState(() => isUploadingProject = false);
                                    }
                                  },
                                  icon: const Icon(Icons.sync_rounded, size: 16),
                                  label: Text(isDraggingProject ? "SOLTAR PARA REEMPLAZAR" : ((isUploadingProject || UploadService().isUploading(order.id.toString(), 'project_file_url')) ? "Subiendo..." : "REEMPLAZAR PROYECTO")),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.purpleAccent,
                                    side: BorderSide(color: isDraggingProject ? Colors.purpleAccent : Colors.purpleAccent.withOpacity(0.3)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ),
                        ] else if (_currentUser?.role == UserRole.admin || _currentUser?.role == UserRole.recepcion || _currentUser?.role == UserRole.control_calidad) ...[
                          // Si NO hay proyecto, permitir subirlo
                          Column(
                            children: [
                              DropTarget(
                                onDragDone: (details) async {
                                  final isQueued = UploadService().isUploading(order.id.toString(), 'project_file_url');
                                  if (details.files.isNotEmpty && !isUploadingProject && !isQueued) {
                                    final file = details.files.first;
                                    setDialogState(() {
                                      isDraggingProject = false;
                                      isUploadingProject = true;
                                    });
                                    try {
                                      final bytes = await file.readAsBytes();
                                      UploadService().startUpload(
                                        clientName: order.clientName,
                                        orderId: order.id.toString(),
                                        file: PlatformFile(name: file.name, size: bytes.length, bytes: bytes),
                                        structuralReference: 'project_file_url', 
                                      );

                                      if (context.mounted) {
                                        Navigator.pop(context); 
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("🚀 Subida de Proyecto iniciada en segundo plano. Se te avisará al terminar."), 
                                            backgroundColor: Color(0xFF7C3AED),
                                            duration: Duration(seconds: 4),
                                          )
                                        );
                                      }
                                    } catch (e) {
                                      print("Error drop project: $e");
                                    } finally {
                                      setDialogState(() => isUploadingProject = false);
                                    }
                                  }
                                },
                                onDragEntered: (details) => setDialogState(() => isDraggingProject = true),
                                onDragExited: (details) => setDialogState(() => isDraggingProject = false),
                                child: OutlinedButton.icon(
                                  onPressed: (isUploadingProject || UploadService().isUploading(order.id.toString(), 'project_file_url')) ? null : () async {
                                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: ['zip', 'aup3', 'rar'],
                                      withData: true,
                                    );

                                    if (result != null) {
                                      setDialogState(() => isUploadingProject = true);
                                      try {
                                        UploadService().startUpload(
                                          clientName: order.clientName,
                                          orderId: order.id.toString(),
                                          file: result.files.first,
                                          structuralReference: 'project_file_url', 
                                        );

                                        if (context.mounted) {
                                          Navigator.pop(context); 
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text("🚀 Subida de Proyecto iniciada en segundo plano. Se te avisará al terminar."), 
                                              backgroundColor: Color(0xFF7C3AED),
                                              duration: Duration(seconds: 4),
                                            )
                                          );
                                        }
                                      } catch (e) {
                                        print("Error pick project: $e");
                                      } finally {
                                        setDialogState(() => isUploadingProject = false);
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.cloud_upload_outlined, color: Colors.purpleAccent),
                                  label: Text(
                                    isDraggingProject ? "¡SUELTA EL PROYECTO AQUÍ!" : ((isUploadingProject || UploadService().isUploading(order.id.toString(), 'project_file_url')) ? "Subiendo..." : "SUBIR PROYECTO (.AUP3 / ZIP)"), 
                                    style: const TextStyle(color: Colors.purpleAccent)
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: isDraggingProject ? Colors.white : Colors.purpleAccent, width: isDraggingProject ? 2 : 1),
                                    backgroundColor: isDraggingProject ? Colors.purpleAccent.withOpacity(0.1) : Colors.transparent,
                                    minimumSize: const Size(double.infinity, 45),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(8)),
                            child: const Text("Sin proyecto editable", style: TextStyle(color: Colors.white24, fontSize: 11, fontStyle: FontStyle.italic)),
                          ),

                        const SizedBox(height: 16),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 16),
                      ],

                      // Asignación
                      const Text("ASIGNACIÓN DE PERSONAL", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 12),
                      
                      // Dropdown Generador (Lista Unificada)
                      _buildDropdown("Generador", _allStaff, tempGenId, (val) => setDialogState(() => tempGenId = val), 
                        enabled: (order.status == OrderStatus.PENDIENTE || order.status == OrderStatus.EN_GENERACION)),
                      const SizedBox(height: 12),
                      // Dropdown Editor (Lista Unificada)
                      _buildDropdown("Editor", _allStaff, tempEdId, (val) => setDialogState(() => tempEdId = val),
                        enabled: (order.status == OrderStatus.PENDIENTE || order.status == OrderStatus.EN_GENERACION)),

                      const SizedBox(height: 20),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 16),

                      // Sección de Observaciones de Calidad
                      const Text("NUEVA OBSERVACIÓN (CALIDAD)", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: observationController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: "Escribe un comentario si es necesario...",
                          hintStyle: const TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),

                      const SizedBox(height: 20),

                      
                       SizedBox(
                        width: double.infinity,
                        child: (order.status == OrderStatus.EN_REVISION) 
                          ? ElevatedButton(
                              onPressed: isProcessing ? null : () async {
                                  setDialogState(() => isProcessing = true);
                                  try {
                                    await _orderService.approveQualityControl(order.id!);
                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedido aprobado por Calidad"), backgroundColor: Colors.green));
                                    }
                                  } catch (e) {
                                    setDialogState(() => isProcessing = false);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al aprobar: $e"), backgroundColor: Colors.red));
                                  }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981), // Verde
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: isProcessing 
                                  ? const CircularProgressIndicator(color: Colors.white) 
                                  : const Text("LISTO (APROBAR CALIDAD)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            )
                          : Column(
                              children: [
                                if (order.status == OrderStatus.AUDIO_LISTO && (_currentUser?.role == UserRole.admin || _currentUser?.role == UserRole.recepcion))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: ElevatedButton(
                                      onPressed: isProcessing ? null : () async {
                                        setDialogState(() => isProcessing = true);
                                        try {
                                          await _orderService.markAsDelivered(order.id!);
                                          if (mounted) {
                                            Navigator.pop(context);
                                            _loadData();
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                              content: const Text("✅ Pedido entregado al cliente"), 
                                              backgroundColor: const Color(0xFFFFEB3B).withOpacity(0.9),
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
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFFEB3B), 
                                        foregroundColor: Colors.black,
                                        minimumSize: const Size(double.infinity, 45),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: isProcessing 
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) 
                                        : const Text("ENTREGAR PEDIDO", style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ElevatedButton(
                                  onPressed: (tempGenId != null && tempEdId != null && !isProcessing && (order.status == OrderStatus.PENDIENTE || order.status == OrderStatus.EN_GENERACION)) 
                                      ? () async {
                                          setDialogState(() => isProcessing = true);
                                          try {
                                            String finalObservations = order.observations ?? '';
                                            if (observationController.text.isNotEmpty) {
                                              final timestamp = DateFormat('dd/MM HH:mm').format(DateTime.now());
                                              final separator = finalObservations.isEmpty ? "" : "\n";
                                              finalObservations += "$separator- [CALIDAD $timestamp]: ${observationController.text.trim()}";
                                            }

                                            await _orderService.assignStaff(
                                              order.id!, 
                                              tempGenId!, 
                                              tempEdId!,
                                              newObservations: observationController.text.isNotEmpty ? finalObservations : null,
                                            );
                                            
                                            if (mounted) {
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedido actualizado correctamente"), backgroundColor: Colors.green));
                                            }
                                          } catch (e) {
                                            setDialogState(() => isProcessing = false);
                                          }
                                        } 
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7C3AED),
                                    disabledBackgroundColor: Colors.white.withOpacity(0.05),
                                    minimumSize: const Size(double.infinity, 45),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: isProcessing 
                                      ? const CircularProgressIndicator(color: Colors.white) 
                                      : Text(
                                          (order.status == OrderStatus.AUDIO_LISTO || order.status == OrderStatus.EDICION || order.status == OrderStatus.ENTREGADO) 
                                            ? "ORDEN PROCESADA" 
                                            : "GENERAR ORDEN", 
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold, 
                                            color: (order.status == OrderStatus.AUDIO_LISTO || order.status == OrderStatus.EDICION || order.status == OrderStatus.ENTREGADO) ? Colors.white24 : Colors.white
                                          )
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDropdown(String label, List<UserModel> users, String? selectedId, Function(String?) onChanged, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: enabled ? Colors.white.withOpacity(0.05) : Colors.black12,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: enabled ? Colors.white10 : Colors.white.withOpacity(0.02)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: users.any((u) => u.id == selectedId) ? selectedId : null,
              isExpanded: true,
              dropdownColor: const Color(0xFF222222),
              hint: Text("Seleccionar $label", style: const TextStyle(color: Colors.white24)),
              items: users.map((u) {
                final isGen = u.role == UserRole.generador;
                final roleColor = isGen ? const Color(0xFF7C3AED) : const Color(0xFF3B82F6);
                
                return DropdownMenuItem(
                  value: u.id,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: roleColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        u.name, 
                        style: TextStyle(
                          color: enabled ? Colors.white : Colors.white38,
                          fontSize: 13,
                        )
                      ),
                      const Spacer(),
                      Text(
                        isGen ? "GEN" : "EDI",
                        style: TextStyle(
                          color: roleColor.withOpacity(0.5),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Future<bool?> _showConfirmDelete(BuildContext context, String type) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B21),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("¿Eliminar $type?", style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Text("Se eliminará el $type de forma permanente de la base de datos.", style: const TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCELAR")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("ELIMINAR", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  String _formatDateWithDay(DateTime date) {
    // Array de días en español
    final days = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"];
    String dayName = days[date.weekday % 7];
    
    // Formato: "Lunes 03/02 - 10:00"
    return "$dayName ${DateFormat('dd/MM - HH:mm').format(date)}";
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
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: color.withOpacity(0.9),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            if (isCollapsed)
              Icon(Icons.unfold_more_rounded, color: color.withOpacity(0.3), size: 18),
          ],
        ),
      ),
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
            Row(
              children: [
                const Text('Panel de Calidad', 
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const Spacer(),
                IconButton(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh, color: Colors.white24),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Buscador y Filtros
            _buildFilterBar(),
            
            const SizedBox(height: 16),

            
            Expanded(
              child: StreamBuilder<List<OrderModel>>(
                stream: _orderService.ordersStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
                  }
                  
                  var orders = snapshot.data ?? [];

                  // 1. Filtrado por Búsqueda
                  if (_searchQuery.isNotEmpty) {
                    orders = orders.where((o) => 
                      o.clientName.toLowerCase().contains(_searchQuery) || (o.id?.toString().contains(_searchQuery) ?? false)
                    ).toList();
                  }

                  // 2. Filtrado por Estado
                  if (_statusFilter != null) {
                    orders = orders.where((o) => o.status == _statusFilter).toList();
                  } else {
                    // Por defecto quitamos los anulados si no hay filtro activo
                    orders = orders.where((o) => o.status != OrderStatus.ANULADO).toList();
                  }

                  // 3. Ordenamiento
                  if (_sortByDelivery) {
                    orders.sort((a, b) => a.deliveryDueAt.compareTo(b.deliveryDueAt));
                  } else {
                    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  }

                  if (orders.isEmpty) {
                    return const Center(child: Text('No hay pedidos activos.', style: TextStyle(color: Colors.white38)));
                  }

                  final groupedOrders = _groupOrders(orders);
                  final List<Widget> listItems = [];

                  groupedOrders.forEach((groupTitle, groupOrdersList) {
                    if (groupOrdersList.isEmpty) return;

                    final isCollapsed = _collapsedGroups.contains(groupTitle);
                    Color groupColor = Colors.deepPurpleAccent;
                    
                    if (groupTitle.contains("⚠️")) groupColor = Colors.orangeAccent;
                    if (groupTitle.contains("🔴")) groupColor = Colors.redAccent;
                    if (groupTitle.contains("✅")) groupColor = Colors.greenAccent;
                    if (groupTitle.contains("🚀")) groupColor = Colors.blueAccent;

                    listItems.add(_buildGroupHeader(groupTitle, groupOrdersList.length, groupColor, isCollapsed));

                    if (!isCollapsed) {
                      for (var order in groupOrdersList) {
                        final gen = _allStaff.firstWhere((u) => u.id == order.generatorId, orElse: () => UserModel(id: '', name: 'Pendiente', email: '', role: UserRole.generador, active: true));
                        final edi = _allStaff.firstWhere((u) => u.id == order.editorId, orElse: () => UserModel(id: '', name: 'Pendiente', email: '', role: UserRole.editor, active: true));
                        
                        listItems.add(
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: QCOrderCard(
                              order: order,
                              generator: gen,
                              editor: edi,
                              isSelected: false,
                              onSelect: null,
                              onTap: () => _showAssignmentDialog(order),
                            ),
                          ),
                        );
                      }
                    }
                  });

                  return ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: listItems,
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
        _filterChip("REVISIÓN", OrderStatus.EN_REVISION),
        _filterChip("LISTO", OrderStatus.AUDIO_LISTO),

        const VerticalDivider(color: Colors.white10, width: 10),

        // Botones de Ordenamiento
        IconButton(
          tooltip: "Más recientes",
          icon: Icon(Icons.history, color: !_sortByDelivery ? Colors.deepPurpleAccent : Colors.white24),
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
