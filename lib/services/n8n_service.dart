import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

class N8nService {
  final String _webhookUrl = 'https://mqwebhook.dashbportal.com/webhook/subir-archivo-erp';

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
    } else if (structuralReference == 'base_audio_url' || structuralReference == 'final_audio_url') {
      fileType = 'mp3';
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
          if (jsonResponse is Map) {
            // Buscamos varias posibles claves para ser más flexibles
            final url = jsonResponse['file_url'] ?? 
                        jsonResponse['url'] ?? 
                        jsonResponse['link'] ?? 
                        jsonResponse['webViewLink'] ??
                        jsonResponse['webContentLink'] ??
                        // Si n8n devuelve el objeto de la fila de Supabase actualizado, buscamos ahí
                        jsonResponse['base_audio_url'] ??
                        jsonResponse['script_file_url'] ??
                        jsonResponse['project_file_url'] ??
                        jsonResponse['final_audio_url'];
                        
            if (url != null && url.toString().isNotEmpty) {
              print("🔗 URL detectada en respuesta n8n: $url");
              return url.toString();
            }
          }
        } catch (e) {
          print("⚠️ No se pudo parsear JSON de respuesta n8n: $e");
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
}
