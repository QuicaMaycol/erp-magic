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

  Future<void> createOrder(OrderModel order) async {
    await _supabase
        .from('orders')
        .insert(order.toJson());
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

  // Actualizar estado a AUDIO_LISTO con el audio final editado
  Future<void> completeEdition(int orderId, String audioUrl) async {
    final data = await _supabase
        .from('orders')
        .update({
      'status': 'AUDIO_LISTO',
      'final_audio_url': audioUrl, // Se guarda en final_audio_url (Editor)
      'edition_ended_at': DateTime.now().toIso8601String(),
    })
    .eq('id', orderId)
    .select();

    if ((data as List).isEmpty) {
      throw Exception("No se pudo completar la edición del pedido #$orderId");
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
    if (url == null) return;
    try {
      final String lowerUrl = url.toLowerCase();
      Uri uri = Uri.parse(url);
      
      // Si es un documento (Word, PDF, etc), usamos el visor de Google Docs para previsualizarlo
      if (lowerUrl.contains('.doc') || lowerUrl.contains('.pdf') || lowerUrl.contains('.docx') || lowerUrl.contains('.txt')) {
        uri = Uri.parse('https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}');
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print("No se pudo abrir la URL: $url");
      }
    } catch (e) {
      print("Error al abrir URL: $e");
    }
  }
}
