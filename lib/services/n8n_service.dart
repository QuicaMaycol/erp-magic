import 'dart:convert';
import 'package:http/http.dart' as http;
import '../supabase_config.dart';

class N8nService {
  static const String _baseUrl = SupabaseConfig.n8nBaseUrl;
  
  final String _webhookUrl = '$_baseUrl/webhook/subir-archivo-erp';
  final String _bulkZipWebhookUrl = '$_baseUrl/webhook/d175c2d6-ad82-4cd6-bff3-06e19b4add25';
  final String _cleanupWebhookUrl = '$_baseUrl/webhook/3ae47e48-2af5-4eba-a72b-a16a1f707d34';

  /// Envía una notificación a n8n con la URL del archivo ya subido a Supabase
  Future<String?> notifyN8n({
    required String clientName,
    required String orderId,
    required String fileUrl,
    required String fileName,
    required String storagePath,
    required String structuralReference,
  }) async {
    final payload = {
      'order_id': orderId,
      'client_name': clientName,
      'file_url': fileUrl,
      'file_name': fileName,
      'storage_path': storagePath,
      'column': structuralReference,
    };

    final uri = Uri.parse(_webhookUrl).replace(queryParameters: payload);
    print('🔔 Notificando a n8n: $fileUrl');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(minutes: 30));

      print('📡 Respuesta n8n: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['message'] == 'Workflow was started') {
          return "PENDING_IN_N8N";
        }
        return _extractUrlFromResponse(jsonResponse, structuralReference);
      }
      return null;
    } catch (e) {
      print("❌ Error notificando a n8n: $e");
      return null;
    }
  }

  String? _extractUrlFromResponse(dynamic jsonResponse, String targetRef) {
    String? findUrl(dynamic obj, String target) {
      if (obj is Map) {
        final possibleKeys = ['file_url', 'url', 'link', 'webViewLink', target];
        for (final key in possibleKeys) {
          if (obj[key] != null) return obj[key].toString();
        }
        for (final value in obj.values) {
          final found = findUrl(value, target);
          if (found != null) return found;
        }
      } else if (obj is List) {
        for (final item in obj) {
          final found = findUrl(item, target);
          if (found != null) return found;
        }
      }
      return null;
    }
    return findUrl(jsonResponse, targetRef);
  }

  /// Solicita a n8n la generación de un archivo ZIP con varios audios
  Future<String?> generateBulkZip(List<Map<String, String>> filesData) async {
    try {
      print("Solicitando generación de ZIP masivo para ${filesData.length} archivos...");
      
      final response = await http.post(
        Uri.parse(_bulkZipWebhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'bulk_zip',
          'files': filesData,
        }),
      );

      print("Status Code ZIP: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.trim().isEmpty) return null;

        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse is Map) {
          return jsonResponse['zip_url'] ?? 
                 jsonResponse['url'] ?? 
                 jsonResponse['file_url'] ?? 
                 jsonResponse['link'] ?? 
                 jsonResponse['webViewLink'] ?? 
                 jsonResponse['id'];
        } else if (jsonResponse is List && jsonResponse.isNotEmpty) {
          final first = jsonResponse.first;
          if (first is Map) {
            return first['zip_url'] ?? first['url'] ?? first['file_url'] ?? first['link'] ?? first['id'];
          }
        }
      }
    } catch (e) {
      print("Error solicitando ZIP masivo: $e");
    }
    return null;
  }

  /// Solicita a n8n la eliminación física de archivos y actualización de DB
  Future<bool> triggerStorageCleanup({required int orderId, required List<String> filePaths}) async {
    try {
      print("🗑️ Solicitando Limpieza Sincronizada a n8n para Pedido #$orderId...");
      
      final response = await http.post(
        Uri.parse(_cleanupWebhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
            'order_id': orderId,
            'files': filePaths.map((p) => {'path': p}).toList(),
            'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      print("📡 Respuesta Limpieza n8n: ${response.statusCode}");
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("❌ Error en triggerStorageCleanup: $e");
      return false;
    }
  }

  /// Solicita a n8n el rescate masivo de proyectos del día 27 hacia Google Drive
  Future<String?> triggerMaintenanceRescue() async {
    try {
      print("🚀 Solicitando Rescate Masivo (Día 27)...");
      
      final response = await http.post(
        Uri.parse(_cleanupWebhookUrl), // Usa el mismo Webhook o uno específico si se configuró distinto
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'bulk_rescue_day_27',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      print("📡 Respuesta Rescate: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['drive_folder_url'] ?? jsonResponse['url'] ?? jsonResponse['link'];
      }
    } catch (e) {
      print("❌ Error en Rescate Masivo: $e");
    }
    return null;
  }
}
