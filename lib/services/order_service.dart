import 'dart:io';
import 'dart:typed_data'; // Necesario para Uint8List
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // Para abrir URLs
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../supabase_config.dart';

class OrderService {
  static final OrderService _instance = OrderService._internal();
  factory OrderService() => _instance;
  OrderService._internal();

  final _supabase = Supabase.instance.client;

  // Stream con Polling automático restaurado
  Stream<List<OrderModel>> get ordersStream {
    return Stream.periodic(const Duration(seconds: 5))
        .asyncMap((_) async => await fetchOrders())
        .asBroadcastStream();
  }

  // Consulta estándar (Mucho más fiable para carga inicial)
  Future<List<OrderModel>> fetchOrders() async {
    try {
      // Usamos la configuración por defecto definida en la inicialización
      final response = await _supabase
          .from('orders')
          .select();
          // Eliminamos el .order por ahora para diagnosticar si es el culpable del "Failed to fetch"
          // .order('delivery_due_at', ascending: true);

      final List data = response as List;
      // Ordenamos localmente para mayor seguridad
      final orders = data.map((json) => OrderModel.fromJson(json)).toList();
      orders.sort((a, b) => a.deliveryDueAt.compareTo(b.deliveryDueAt));
      return orders;
    } catch (e) {
      // Evitamos inundar la consola si hay un error persistente de red
      debugPrint('Supabase: No se pudieron obtener órdenes V1. Verifique conexión.');
      return [];
    }
  }

  // Mantener compatibilidad con código existente
  Future<List<OrderModel>> getOrders(UserModel user) => fetchOrders();

  Future<OrderModel> createOrder(OrderModel order) async {
    final response = await _supabase
        .from('orders')
        .insert(order.toJson())
        .select()
        .single();
    
    return OrderModel.fromJson(response);
  }

  Future<void> updateOrder(OrderModel order) async {
    if (order.id == null) return;
    
    await _supabase
        .from('orders')
        .update(order.toJson())
        .eq('id', order.id!);
  }


  // Asignar personal a una orden
  Future<void> assignStaff(int orderId, String generatorId, String editorId) async {
    final data = await _supabase
        .from('orders')
        .update({
      'generator_id': generatorId,
      'editor_id': editorId,
      'status': 'EN_GENERACION',
      'generation_started_at': DateTime.now().toIso8601String(),
    })
    .eq('id', orderId)
    .select();

    if ((data as List).isEmpty) {
      throw Exception("No se pudo actualizar la orden #$orderId");
    }
  }

  Future<void> assignGenerator(int orderId, String userId) async {
    await _supabase.from('orders').update({
      'generator_id': userId,
      'status': 'EN_GENERACION',
      'generation_started_at': DateTime.now().toIso8601String(),
    }).eq('id', orderId);
  }

  Future<void> assignEditor(int orderId, String userId) async {
    await _supabase.from('orders').update({
      'editor_id': userId,
    }).eq('id', orderId);
  }

  // Actualizar estado a EDICION con la URL del audio base generado
  Future<void> sendToEdition(int orderId, String audioUrl) async {
    final data = await _supabase
        .from('orders')
        .update({
      'status': 'EDICION',
      'base_audio_url': audioUrl, // Se guarda en base_audio_url (Generador)
      'generation_ended_at': DateTime.now().toIso8601String(),
      'edition_started_at': DateTime.now().toIso8601String(),
    })
    .eq('id', orderId)
    .select();

    if ((data as List).isEmpty) {
      throw Exception("No se pudo enviar a edición el pedido #$orderId");
    }
  }

  // Actualizar estado a EN_REVISION con el audio final editado (Cerrar edición)
  Future<void> completeEdition(int orderId, String audioUrl) async {
    final data = await _supabase
        .from('orders')
        .update({
      'status': 'EN_REVISION', // Cambiado de AUDIO_LISTO a EN_REVISION
      'final_audio_url': audioUrl, 
      'edition_ended_at': DateTime.now().toIso8601String(),
    })
    .eq('id', orderId)
    .select();

    if ((data as List).isEmpty) {
      throw Exception("No se pudo completar la edición del pedido #$orderId");
    }
  }

  // Aprobar Control de Calidad y pasar a AUDIO_LISTO
  Future<void> approveQualityControl(int orderId) async {
    final data = await _supabase
        .from('orders')
        .update({
      'status': 'AUDIO_LISTO',
    })
    .eq('id', orderId)
    .select();

    if ((data as List).isEmpty) {
      throw Exception("No se pudo aprobar el control de calidad del pedido #$orderId");
    }
  }

  // Marcar como ENTREGADO
  Future<void> markAsDelivered(int orderId) async {
    final data = await _supabase
        .from('orders')
        .update({
      'status': 'ENTREGADO',
    })
    .eq('id', orderId)
    .select();

    if ((data as List).isEmpty) {
      throw Exception("No se pudo marcar como entregado el pedido #$orderId");
    }
  }

  // Actualizar el estado de una orden (útil para anulación/papelera)
  Future<void> updateOrderStatus(int orderId, OrderStatus status) async {
    await _supabase
        .from('orders')
        .update({'status': status.name})
        .eq('id', orderId);
  }

  // Eliminar físicamente una orden de la base de datos
  Future<void> deleteOrderPermanently(int orderId) async {
    await _supabase
        .from('orders')
        .delete()
        .eq('id', orderId);
  }


  // Método para subir archivos compatible con Web, Móvil y Escritorio
  Future<String?> pickAndUploadFile(String bucket) async {
    try {
      // Nota: No usamos withData: true por defecto para evitar problemas de memoria en Desktop
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        // En Web, los bytes vienen automáticamente. En Desktop/Mobile, usamos path a menos que se fuerce.
        allowedExtensions: bucket == 'documents' 
            ? ['pdf', 'doc', 'docx', 'txt'] 
            : ['mp3', 'wav', 'm4a'],
      );

      if (result != null) {
        final platformFile = result.files.first;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${platformFile.name.replaceAll(RegExp(r'\s+'), '_')}';
        
        // Estrategia híbrida robusta
        Uint8List? fileBytes = platformFile.bytes;

        // Si no hay bytes (Desktop/Mobile) y no es Web, leemos el archivo manualmente
        if (fileBytes == null && !kIsWeb && platformFile.path != null) {
          try {
            fileBytes = await File(platformFile.path!).readAsBytes();
          } catch (e) {
            print("Error leyendo archivo local: $e");
          }
        }

        if (fileBytes != null) {
          final String contentType = bucket == 'documents' ? 'application/pdf' : 'audio/mpeg';
          print("Intentando subir a bucket: $bucket ...");
          try {
            await _supabase.storage.from(bucket).uploadBinary(
              fileName, 
              fileBytes,
              fileOptions: FileOptions(contentType: contentType, upsert: true),
            );
            final String publicUrl = _supabase.storage.from(bucket).getPublicUrl(fileName);
            print("SUBIDA EXITOSA. URL OBTENIDA: $publicUrl");
            return publicUrl;
          } catch (storageError) {
            print("ERROR CRÍTICO EN STORAGE: $storageError");
            try {
              final buckets = await _supabase.storage.listBuckets();
              print("BUCKETS QUE EXISTEN EN TU PROYECTO: ${buckets.map((b) => b.name).toList()}");
            } catch (e) {
              print("No se pudo ni siquiera listar los buckets: $e");
            }
            rethrow;
          }
        } else {
          throw Exception("No se pudieron obtener los datos del archivo (Bytes null y path inaccesible)");
        }
      }
    } catch (e) {
      print("Error subiendo archivo: $e");
    }
    return null;
  }

  /// Abre una URL en el navegador/visor del sistema
  Future<void> openUrl(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    try {
      String processedUrl = url.trim();

      // CORRECCIÓN: Si el "link" no parece un link (no tiene http), asumimos que es un ID de Google Drive
      if (!processedUrl.startsWith('http')) {
        print("Detectado posible ID de Drive: $processedUrl. Construyendo URL completa...");
        processedUrl = 'https://drive.google.com/file/d/$processedUrl/view';
      }

      final String lowerUrl = processedUrl.toLowerCase();
      Uri uri = Uri.parse(processedUrl);
      
      // Si es un documento directo (Word, PDF) y no es ya un link de visualización de Drive/Docs,
      // intentamos usar el visor de Google Docs para asegurar que se abra en el navegador móvil/web sin descargar.
      // (Omitimos esto si ya es un link de drive.google.com para no romper la vista nativa de Drive)
      if (!lowerUrl.contains('drive.google.com') && 
          (lowerUrl.contains('.doc') || lowerUrl.contains('.pdf') || lowerUrl.contains('.docx') || lowerUrl.contains('.txt'))) {
        uri = Uri.parse('https://docs.google.com/viewer?url=${Uri.encodeComponent(processedUrl)}');
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: intentar lanzar sin validación estricta (a veces necesario para esquemas raros)
        try {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        } catch (e) {
          print("No se pudo abrir la URL: $processedUrl");
        }
      }
    } catch (e) {
      print("Error al abrir URL: $e");
    }
  }
}
