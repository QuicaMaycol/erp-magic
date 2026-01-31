import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

class N8nService {
  final String _webhookUrl = 'https://mqwebhook.dashbportal.com/webhook/subir-archivo-erp';
  final String _bulkZipWebhookUrl = 'https://mqwebhook.dashbportal.com/webhook/d175c2d6-ad82-4cd6-bff3-06e19b4add25';

  /// Retorna la URL del archivo si n8n la devuelve en el campo 'file_url', o null si no.
  Future<String?> uploadFile({
    required String clientName,
    required String orderId,
    required PlatformFile file,
    required String structuralReference, 
  }) async {
    
    // ... (Lógica de determinación de tipo y nombre igual que antes) ...
    // 1. Determinar file_type (Mantenemos lógica dinámica para soportar audio si es necesario)
    String fileType;
    if (structuralReference == 'script_file_url') {
      fileType = 'word';
    } else if (structuralReference == 'base_audio_url') {
      fileType = 'mp3';
    } else if (structuralReference == 'final_audio_url') {
      fileType = 'final'; 
    } else if (structuralReference == 'audio_muestra_url') {
      fileType = 'muestra';
    } else if (structuralReference == 'project_file_url') {
      fileType = 'aup3';
    } else {
      fileType = 'word'; // Fallback por defecto
    }

    // 2. Preparar el nombre de archivo limpio
    final safeClientName = clientName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final ext = file.extension?.toLowerCase() ?? 'dat';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newFileName = '${safeClientName}_${fileType}_$timestamp.$ext';

    // 3. Determinar MediaType
    MediaType? mediaType;
    if (ext == 'pdf') mediaType = MediaType('application', 'pdf');
    else if (ext == 'doc') mediaType = MediaType('application', 'msword');
    else if (ext == 'docx') mediaType = MediaType('application', 'vnd.openxmlformats-officedocument.wordprocessingml.document');
    else if (ext == 'mp3') mediaType = MediaType('audio', 'mpeg');
    else if (ext == 'wav') mediaType = MediaType('audio', 'wav');
    else if (ext == 'txt') mediaType = MediaType('text', 'plain');
    else mediaType = MediaType('application', 'octet-stream');

    print('Iniciando subida HTTP POST a: $_webhookUrl');
    print('Datos: Client=$clientName, Order=$orderId, FileType=$fileType, FileName=$newFileName');

    try {
      // 4. Crear la petición Multipart
      var request = http.MultipartRequest('POST', Uri.parse(_webhookUrl));
      
      // Campos de texto obligatorios
      request.fields['order_id'] = orderId;
      request.fields['client_name'] = clientName;
      request.fields['file_type'] = fileType;
      request.fields['desired_filename'] = newFileName; 

      // 5. Adjuntar archivo
      http.MultipartFile multipartFile;
      
      if (file.bytes != null) {
        multipartFile = http.MultipartFile.fromBytes(
          'data', 
          file.bytes!,
          filename: newFileName,
          contentType: mediaType,
        );
      } else if (file.path != null) {
        multipartFile = await http.MultipartFile.fromPath(
          'data', 
          file.path!,
          filename: newFileName,
          contentType: mediaType,
        );
      } else {
        throw Exception("El archivo no tiene ruta ni bytes.");
      }

      request.files.add(multipartFile);

      // 6. Enviar
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      // 7. Validar respuesta
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ Subida exitosa.");
        
        // Intentar parsear la URL de respuesta
        try {
          final jsonResponse = jsonDecode(response.body);
          print("🔍 Depuración N8N - Cuerpo: ${response.body}");

          // Función local para buscar URL en cualquier objeto (Mapa o Lista)
          String? findUrl(dynamic obj, String targetRef) {
            if (obj is Map) {
              final keys = obj.keys.map((k) => k.toString().toLowerCase()).toList();
              final targetLower = targetRef.toLowerCase();

              // 1. Prioridad: claves directas de URL (Exactas o Genéricas)
              final possibleKeys = ['file_url', 'url', 'link', 'webViewLink', 'webContentLink', targetRef];
              for (final key in possibleKeys) {
                final normalizedKey = key.toLowerCase();
                
                // Búsqueda manual para evitar TypeError en Web
                dynamic actualKey;
                for (final k in obj.keys) {
                  if (k.toString().toLowerCase() == normalizedKey) {
                    actualKey = k;
                    break;
                  }
                }
                
                if (actualKey != null && obj[actualKey] != null) {
                  final val = obj[actualKey].toString().trim();
                  if (val.startsWith('http') || (val.length > 20 && !val.contains(' '))) {
                    print("✅ Coincidencia encontrada en clave: $actualKey");
                    return val;
                  }
                }
              }

              // 2. Fallback: buscar cualquier clave que CONTENGA el targetRef
              for (final key in obj.keys) {
                if (key.toString().toLowerCase().contains(targetLower)) {
                  final val = obj[key].toString().trim();
                  if (val.startsWith('http') || (val.length > 20 && !val.contains(' '))) {
                    return val;
                  }
                }
              }

              // 3. Búsqueda recursiva en sub-objetos
              for (final value in obj.values) {
                if (value is Map || value is List) {
                  final found = findUrl(value, targetRef);
                  if (found != null) return found;
                }
              }
            } else if (obj is List) {
              for (final item in obj) {
                final found = findUrl(item, targetRef);
                if (found != null) return found;
              }
            }
            return null;
          }

          final extractedUrl = findUrl(jsonResponse, structuralReference);
          
          if (extractedUrl != null && extractedUrl.isNotEmpty) {
            String finalUrl = extractedUrl;
            if (!finalUrl.startsWith('http')) {
              // Cambiado a /view para permitir previsualización nativa
              finalUrl = 'https://drive.google.com/file/d/$finalUrl/view';
            }
            return finalUrl;
          }
          
          print("⚠️ No se encontró la clave '$structuralReference' ni ninguna URL válida en el JSON.");
        } catch (e) {
          print("⚠️ Error procesando JSON de n8n: $e");
        }
        
        return null; // Éxito pero sin URL
      } else {
        // Manejo especial error n8n sin respuesta
        if (response.statusCode == 500 && response.body.contains("No item to return was found")) {
           print("⚠️ N8N Warning: 'No item to return'. No hay URL disponible.");
           return null;
        }
        
        throw Exception('Error del servidor (${response.statusCode}): ${response.body}');
      }

    } catch (e) {
      print("❌ Excepción de conexión: $e");
      throw Exception('Error de conexión: $e');
    }
  }

  /// Solicita a n8n la generación de un archivo ZIP con varios audios
  Future<String?> generateBulkZip(List<Map<String, String>> filesData) async {
    try {
      print("Solicitando generación de ZIP masivo para ${filesData.length} archivos...");
      print("POST a: $_bulkZipWebhookUrl");

      final response = await http.post(
        Uri.parse(_bulkZipWebhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'bulk_zip',
          'files': filesData,
        }),
      );

      print("Status Code ZIP: ${response.statusCode}");
      print("Response Body ZIP: '${response.body}'");

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.trim().isEmpty) {
          print("⚠️ Alerta: El servidor respondió con éxito pero el cuerpo está vacío. Verifique el nodo 'Respond to Webhook' en n8n.");
          return null;
        }

        final jsonResponse = jsonDecode(response.body);
        
        // Intentar encontrar la URL de diversas formas igual que en uploadFile
        if (jsonResponse is Map) {
          return jsonResponse['zip_url'] ?? jsonResponse['url'] ?? jsonResponse['file_url'] ?? jsonResponse['link'] ?? jsonResponse['id'];
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
}
