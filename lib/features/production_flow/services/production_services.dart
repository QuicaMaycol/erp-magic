import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/production_order_model.dart';

class ProductionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- STORAGE ---

  /// Sube un archivo usando el explorador nativo
  /// [bucket]: 'documents' o 'audios'
  Future<String?> pickAndUploadFile(String bucket) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: bucket == 'documents' 
            ? ['pdf', 'doc', 'docx', 'txt'] 
            : ['mp3', 'wav', 'm4a'],
      );

      if (result != null) {
        final platformFile = result.files.first;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${platformFile.name.replaceAll(RegExp(r'\s+'), '_')}';
        
        // Subida compatible Web/Desktop/Mobile
        if (platformFile.bytes != null) {
          // Web o Desktop con bytes en memoria
          await _supabase.storage.from(bucket).uploadBinary(fileName, platformFile.bytes!);
        } else if (platformFile.path != null) {
          // Mobile / Desktop IO
          await _supabase.storage.from(bucket).upload(fileName, File(platformFile.path!));
        } else {
          throw Exception("No se pudo leer el archivo");
        }

        return _supabase.storage.from(bucket).getPublicUrl(fileName);
      }
    } catch (e) {
      print("Error subiendo archivo: $e");
    }
    return null;
  }

  /// Abre una URL en el navegador/visor del sistema
  Future<void> openUrl(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // --- DATABASE ---

  // Stream para Calidad, Generación, Editor (usando Polling para seguridad como en v1)
  Stream<List<ProductionOrderModel>> getOrdersStream() {
    return Stream.periodic(const Duration(seconds: 5))
        .asyncMap((_) => fetchOrders())
        .asBroadcastStream();
  }

  Future<List<ProductionOrderModel>> fetchOrders() async {
    try {
      final response = await _supabase
          .from('production_orders') // Tabla V2
          .select()
          .order('created_at', ascending: false);
      
      final list = response as List;
      print('DEBUG: V2 Connection OK. Recibidas ${list.length} órdenes.');
      
      return list
          .map((json) => ProductionOrderModel.fromJson(json))
          .toList();
    } catch (e) {
      print('DEBUG: V2 Connection FAILED: $e');
      return [];
    }
  }

  // Recepción: Crear Orden
  Future<void> createOrder(ProductionOrderModel order) async {
    await _supabase.from('production_orders').insert(order.toJson());
  }

  // Calidad: Actualizar Estado y Observaciones
  Future<void> updateQualityStatus(int id, ProductionStatus status, {String? observations}) async {
    final updates = {
      'status': status.name,
      if (observations != null) 'observations': observations,
    };
    await _supabase.from('production_orders').update(updates).eq('id', id);
  }

  // Generación: Subir Audio Preliminar
  Future<void> uploadGeneratedAudio(int id, String url) async {
    await _supabase.from('production_orders').update({
      'generated_audio_url': url,
    }).eq('id', id);
  }

  // Editor: Subir Audio Final
  Future<void> uploadFinalAudio(int id, String url) async {
    await _supabase.from('production_orders').update({
      'final_audio_url': url,
    }).eq('id', id);
  }

  // Cambio de Estado Genérico
  Future<void> updateStatus(int id, ProductionStatus status) async {
    await _supabase.from('production_orders').update({
      'status': status.name,
    }).eq('id', id);
  }
}
