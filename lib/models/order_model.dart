import 'package:flutter/material.dart';

enum OrderStatus {
  PENDIENTE,
  EN_GENERACION,
  EDICION,
  EN_REVISION,
  AUDIO_LISTO,
  ANULADO,
}

class OrderModel {
  final int? id;
  final String clientName;
  final String? scriptText;
  final String? observations;
  final DateTime deliveryDueAt;
  final OrderStatus status;
  final String? generatorId;
  final String? editorId;
  final String? scriptFileUrl;
  final String? baseAudioUrl;
  final String? finalAudioUrl;
  final String? projectFileUrl;
  final DateTime? generationStartedAt;
  final DateTime? generationEndedAt;
  final DateTime? editionStartedAt;
  final DateTime? editionEndedAt;
  final DateTime createdAt;

  OrderModel({
    this.id,
    required this.clientName,
    this.scriptText,
    this.observations,
    required this.deliveryDueAt,
    this.status = OrderStatus.PENDIENTE,
    this.generatorId,
    this.editorId,
    this.scriptFileUrl,
    this.baseAudioUrl,
    this.finalAudioUrl,
    this.projectFileUrl,
    this.generationStartedAt,
    this.generationEndedAt,
    this.editionStartedAt,
    this.editionEndedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Lógica de Urgencia (Puntos de color)
  Map<String, dynamic> get urgencyStyle {
    final diff = deliveryDueAt.difference(DateTime.now()).inHours;
    if (diff < 0) return {'color': Colors.redAccent, 'label': 'RETRASADO'};
    if (diff < 4) return {'color': Colors.orangeAccent, 'label': 'URGENTE'};
    if (diff < 12) return {'color': Colors.yellowAccent, 'label': 'PRIORIDAD'};
    return {'color': Colors.greenAccent, 'label': 'A TIEMPO'};
  }

  // Alias para compatibilidad con código antiguo
  Map<String, dynamic> get urgencyColor => {'text': urgencyStyle['color']};

  // Lógica de Estilos Premium Actualizada (Verde -> Amarillo)
  Map<String, dynamic> get statusStyle {
    switch (status) {
      case OrderStatus.PENDIENTE:
        return {
          'color': const Color(0xFF10B981), // Verde Esmeralda
          'label': 'PENDIENTE',
        };
      case OrderStatus.EN_GENERACION:
        return {
          'color': const Color(0xFFFFC107), // Amarillo / Ámbar
          'label': 'EN GENERACION',
        };
      case OrderStatus.AUDIO_LISTO:
        return {
          'color': const Color(0xFFEF4444), // Rojo (Red Accent / Tailwind Red 500)
          'label': 'LISTO',
        };
      default:
        return {
          'color': Colors.grey,
          'label': status.name,
        };
    }
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    try {
      // Lógica robusta para parsear el estado (Maneja Strings, Objetos FK, y variaciones de texto)
      String statusRaw = 'PENDIENTE';
      
      if (json['status'] != null) {
        if (json['status'] is Map) {
          // Si viene como objeto relación (ej: {name: "EN_GENERACION"})
          statusRaw = json['status']['name'] ?? json['status']['descripcion'] ?? 'PENDIENTE';
        } else {
          statusRaw = json['status'].toString();
        }
      }

      final normalized = statusRaw.toUpperCase().trim();

      final parsedStatus = OrderStatus.values.firstWhere(
        (e) => e.name == normalized,
        orElse: () {
          // Fallback inteligente por si los nombres en BD difieren ligeramente
          if (normalized.contains('GENER')) return OrderStatus.EN_GENERACION;
          if (normalized.contains('EDIC') || normalized.contains('EDIT')) return OrderStatus.EDICION;
          if (normalized.contains('LISTO') || normalized.contains('TERMINAD')) return OrderStatus.AUDIO_LISTO;
          if (normalized.contains('REVIS')) return OrderStatus.EN_REVISION;
          if (normalized.contains('ANULA')) return OrderStatus.ANULADO;
          return OrderStatus.PENDIENTE;
        },
      );

      return OrderModel(
        id: json['id'],
        clientName: json['client_name'] ?? 'Sin Nombre',
        scriptText: json['script_text'],
        observations: json['observations'],
        deliveryDueAt: json['delivery_due_at'] != null 
            ? DateTime.parse(json['delivery_due_at']) 
            : DateTime.now(),
        status: parsedStatus,
        generatorId: json['generator_id'],
        editorId: json['editor_id'],
        // Fallback inteligente para nombres de columnas heredados o variantes
        scriptFileUrl: json['script_file_url'] ?? json['document_url'] ?? json['file_url'],
        baseAudioUrl: json['base_audio_url'] ?? json['generated_audio_url'],
        finalAudioUrl: json['final_audio_url'],
        projectFileUrl: json['project_file_url'],
        generationStartedAt: json['generation_started_at'] != null ? DateTime.parse(json['generation_started_at']) : null,
        generationEndedAt: json['generation_ended_at'] != null ? DateTime.parse(json['generation_ended_at']) : null,
        editionStartedAt: json['edition_started_at'] != null ? DateTime.parse(json['edition_started_at']) : null,
        editionEndedAt: json['edition_ended_at'] != null ? DateTime.parse(json['edition_ended_at']) : null,
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      );
    } catch (e) {
      // Fallback en caso de error crítico de parseo
      print('Error parsing OrderModel: $e'); // Debug log
      return OrderModel(
        id: json['id'],
        clientName: 'Error de carga',
        deliveryDueAt: DateTime.now(),
        observations: e.toString(),
      );
    }
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'client_name': clientName,
    'script_text': scriptText,
    'observations': observations,
    'delivery_due_at': deliveryDueAt.toIso8601String(),
    'status': status.name,
    'generator_id': generatorId,
    'editor_id': editorId,
    'script_file_url': scriptFileUrl,
    'base_audio_url': baseAudioUrl,
    'final_audio_url': finalAudioUrl,
    'project_file_url': projectFileUrl,
    'generation_started_at': generationStartedAt?.toIso8601String(),
    'generation_ended_at': generationEndedAt?.toIso8601String(),
    'edition_started_at': editionStartedAt?.toIso8601String(),
    'edition_ended_at': editionEndedAt?.toIso8601String(),
  };
}
