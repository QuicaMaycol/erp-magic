import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cliente_model.dart';
import 'dart:async';

class ClienteService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obtiene clientes de la base de datos de erp_magicvoice, opcionalmente filtrando por fechas
  Future<List<ClienteModel>> fetchClientes({DateTime? startDate, DateTime? endDate}) async {
    try {
      var query = _supabase
          .schema('erp_magicvoice')
          .from('clientes')
          .select();
          
      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        // Asegurar que cubra todo el día moviendo la fecha final al último segundo del día
        final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        query = query.lte('created_at', endOfDay.toIso8601String());
      }
      
      final response = await query.order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => ClienteModel.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error fetching clientes: $e');
      rethrow;
    }
  }

  /// Obtiene los registros de clientes desde la tabla clientes_form
  Future<List<ClienteModel>> fetchClientesForm({DateTime? startDate, DateTime? endDate}) async {
    try {
      var query = _supabase
          .schema('erp_magicvoice')
          .from('clientes_form')
          .select();
          
      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        query = query.lte('created_at', endOfDay.toIso8601String());
      }
      
      final response = await query.order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => ClienteModel.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error fetching clientes_form: $e');
      rethrow;
    }
  }

  /// Registra un nuevo cliente y retorna el modelo creado (con id y num_boleta)
  Future<ClienteModel> insertCliente(ClienteModel cliente) async {
    try {
      final response = await _supabase
          .schema('erp_magicvoice')
          .from('clientes_form')
          .insert(cliente.toJson())
          .select()
          .single();

      return ClienteModel.fromJson(response);
    } catch (e) {
      print('❌ Error insertando cliente: $e');
      rethrow;
    }
  }

  /// Actualiza información de un cliente existente
  Future<void> updateCliente(ClienteModel cliente) async {
    if (cliente.id == null) return;
    try {
      await _supabase
          .schema('erp_magicvoice')
          .from('clientes')
          .update(cliente.toJson())
          .eq('id', cliente.id!);
    } catch (e) {
      print('❌ Error actualizando cliente: $e');
      rethrow;
    }
  }

  /// Elimina un cliente por su ID
  Future<void> deleteCliente(int id) async {
    try {
      await _supabase
          .schema('erp_magicvoice')
          .from('clientes')
          .delete()
          .eq('id', id);
    } catch (e) {
      print('❌ Error eliminando cliente: $e');
      rethrow;
    }
  }
}
