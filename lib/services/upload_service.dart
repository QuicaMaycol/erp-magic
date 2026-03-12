import 'dart:async';
import 'package:flutter/foundation.dart';
import 'n8n_service.dart';
import 'order_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import '../supabase_config.dart';

enum UploadStatus { uploading, success, error }

class UploadTask {
  final String id;
  final String clientName;
  final String orderId;
  final String fileName;
  final String structuralReference;
  double progress;
  UploadStatus status;
  String? error;
  int retryCount;

  UploadTask({
    required this.id,
    required this.clientName,
    required this.orderId,
    required this.fileName,
    required this.structuralReference,
    this.progress = 0.0,
    this.status = UploadStatus.uploading,
    this.error,
    this.retryCount = 0,
  });
}

class UploadService extends ChangeNotifier {
  static final UploadService _instance = UploadService._internal();
  factory UploadService() => _instance;
  UploadService._internal();

  final N8nService _n8nService = N8nService();
  final OrderService _orderService = OrderService();
  
  final List<UploadTask> _tasks = [];
  List<UploadTask> get tasks => List.unmodifiable(_tasks);

  void startUpload({
    required String clientName,
    required String orderId,
    required PlatformFile file,
    required String structuralReference,
  }) async {
    final taskId = '${orderId}_${DateTime.now().millisecondsSinceEpoch}';
    final task = UploadTask(
      id: taskId,
      clientName: clientName,
      orderId: orderId,
      fileName: file.name,
      structuralReference: structuralReference,
    );

    _tasks.add(task);
    notifyListeners();

    try {
      // 1. Preparar metadatos
      final ext = file.extension?.toLowerCase() ?? (file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'dat');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '_');
      // Usar una ruta más limpia para el bucket
      final supabasePath = 'pedidos/${orderId}_${timestamp}_$safeName';
      
      print('📤 Iniciando subida a Supabase Storage: $supabasePath');

      // 2. Subida a Supabase usando el SDK nativo con REINTENTOS
      final Uint8List? bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception("No se pudieron leer los bytes del archivo. En Web es necesario habilitar 'withData: true'.");
      }
      
      task.progress = 0.05;
      notifyListeners();

      const int maxRetries = 3;
      bool uploadSuccess = false;
      
      for (int i = 0; i <= maxRetries; i++) {
        try {
          if (i > 0) {
            task.retryCount = i;
            task.error = "Reintentando... ($i/$maxRetries)";
            notifyListeners();
            print('🔄 Reintentando subida (${i}/${maxRetries})...');
            // Espera exponencial corta: 1s, 2s, 4s...
            await Future.delayed(Duration(seconds: i * 2));
          }

          await Supabase.instance.client.storage.from('uploads').uploadBinary(
            supabasePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _getMediaType(ext).toString(),
              upsert: true,
            ),
          ).timeout(const Duration(minutes: 5));
          
          uploadSuccess = true;
          break; // Éxito, salimos del loop
        } catch (e) {
          print('⚠️ Intento $i fallido: $e');
          if (i == maxRetries) rethrow; // Si es el último intento, lanzamos el error
          
          // Si es un error de CORS o red en Web, suele venir como ClientException
          if (e.toString().contains('Failed to fetch') || e.toString().contains('ClientException')) {
            print('🌐 Error de red/CORS detectado. Reintentando...');
            continue;
          }
          
          if (e is StorageException && (e.statusCode == '413' || e.message.contains('exceeded the maximum allowed size'))) {
            throw Exception('Archivo muy grande (Máx 500MB en Supabase).');
          }         
          // Si es otro tipo de error de Storage, podemos intentar una vez más
          if (e is StorageException) {
            continue;
          }
        }
      }

      if (!uploadSuccess) throw Exception("No se pudo completar la subida después de varios intentos.");

      task.progress = 0.9;
      notifyListeners();

      print('✅ Archivo en Supabase. Actualizando Base de Datos...');

      // 3. Obtener URL pública y Actualizar Base de Datos directamente
      final publicUrl = Supabase.instance.client.storage.from('uploads').getPublicUrl(supabasePath);
      
      try {
        final idInt = int.tryParse(orderId);
        if (idInt != null) {
          // Actualización DIRECTA Y FINAL en la tabla 'orders'
          await _orderService.updateOrderField(idInt, structuralReference, publicUrl);
          print('🗄️ Base de datos actualizada con ÉXITO con URL de Supabase: $publicUrl');
        }
      } catch (e) {
        print('⚠️ Error crítico actualizando DB: $e');
        throw Exception("Error al guardar link en base de datos: $e");
      }

      task.status = UploadStatus.success;
      task.progress = 1.0;
    } catch (e) {
      print('❌ Error en proceso de subida: $e');
      task.status = UploadStatus.error;
      task.error = e.toString();
    } finally {
      notifyListeners();
      Future.delayed(const Duration(seconds: 10), () {
        if (task.status == UploadStatus.success) {
          removeTask(task.id);
        }
      });
    }
  }

  bool isUploading(String orderId, String reference) {
    return _tasks.any((t) => t.orderId == orderId && t.structuralReference == reference && t.status == UploadStatus.uploading);
  }

  MediaType _getMediaType(String ext) {
    switch (ext) {
      case 'pdf': return MediaType('application', 'pdf');
      case 'doc': return MediaType('application', 'msword');
      case 'docx': return MediaType('application', 'vnd.openxmlformats-officedocument.wordprocessingml.document');
      case 'mp3': return MediaType('audio', 'mpeg');
      case 'wav': return MediaType('audio', 'wav');
      case 'zip': return MediaType('application', 'zip');
      case 'rar': return MediaType('application', 'x-rar-compressed');
      default: return MediaType('application', 'octet-stream');
    }
  }

  void removeTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.status == UploadStatus.success || t.status == UploadStatus.error);
    notifyListeners();
  }
}
