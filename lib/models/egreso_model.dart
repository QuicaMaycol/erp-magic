import 'package:flutter/material.dart';

class EgresoModel {
  final int? id;
  final String descripcion;
  final double monto;
  final String tipoMoneda;
  final String? medioPago;
  final String? categoria;
  final DateTime? fecha;
  final DateTime? createdAt;

  EgresoModel({
    this.id,
    required this.descripcion,
    required this.monto,
    this.tipoMoneda = 'USD',
    this.medioPago,
    this.categoria,
    this.fecha,
    this.createdAt,
  });

  factory EgresoModel.fromJson(Map<String, dynamic> json) {
    return EgresoModel(
      id: json['id'],
      descripcion: json['descripcion'] ?? '',
      monto: json['monto'] != null ? double.tryParse(json['monto'].toString()) ?? 0.0 : 0.0,
      tipoMoneda: json['tipo_moneda'] ?? 'USD',
      medioPago: json['medio_pago'],
      categoria: json['categoria'],
      fecha: json['fecha'] != null ? DateTime.parse(json['fecha']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'descripcion': descripcion,
    'monto': monto,
    'tipo_moneda': tipoMoneda,
    if (medioPago != null) 'medio_pago': medioPago,
    if (categoria != null) 'categoria': categoria,
    'fecha': fecha?.toIso8601String() ?? DateTime.now().toIso8601String(),
    if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
  };
}
