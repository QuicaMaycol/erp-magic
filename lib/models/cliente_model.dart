import 'package:flutter/material.dart';

class ClienteModel {
  final int? id;
  final int? orderId;
  final int? numBoleta;
  final String nombres;
  final String apellidos;
  final String? pais;
  final String? celular;
  final String? producto;
  final String? tipoMoneda;
  final double? precio;
  final String? medioPago;
  final DateTime? fecha;
  final DateTime? createdAt;

  ClienteModel({
    this.id,
    this.orderId,
    this.numBoleta,
    required this.nombres,
    required this.apellidos,
    this.pais,
    this.celular,
    this.producto,
    this.tipoMoneda = 'USD',
    this.precio,
    this.medioPago,
    this.fecha,
    this.createdAt,
  });

  factory ClienteModel.fromJson(Map<String, dynamic> json) {
    return ClienteModel(
      id: json['id'],
      orderId: json['orders_id'], // Manejo seguro si falla el nombre de columna en SB
      numBoleta: json['num_boleta'],
      nombres: json['nombres'] ?? '',
      apellidos: json['apellidos'] ?? '',
      pais: json['pais'],
      celular: json['celular'],
      producto: json['producto'],
      tipoMoneda: json['tipo_moneda'] ?? 'USD',
      precio: json['precio'] != null ? double.tryParse(json['precio'].toString()) : null,
      medioPago: json['medio_pago'],
      fecha: json['fecha'] != null ? DateTime.parse(json['fecha']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (orderId != null) 'orders_id': orderId,
    if (numBoleta != null) 'num_boleta': numBoleta,
    'nombres': nombres,
    'apellidos': apellidos,
    'pais': pais,
    'celular': celular,
    'producto': producto,
    'tipo_moneda': tipoMoneda,
    'precio': precio,
    'medio_pago': medioPago,
    'fecha': fecha?.toIso8601String() ?? DateTime.now().toIso8601String(),
    if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
  };

  // Nombres completos auxiliar
  String get nombreCompleto => '$nombres $apellidos'.trim();
}
