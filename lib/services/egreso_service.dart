import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/egreso_model.dart';
import '../supabase_config.dart';

class EgresoService {
  final _supabase = Supabase.instance.client;
  final String _schema = SupabaseConfig.schema;

  Future<List<EgresoModel>> fetchEgresos({DateTime? startDate, DateTime? endDate}) async {
    try {
      var query = _supabase
          .schema(_schema)
          .from('egresos')
          .select()
          .order('fecha', ascending: false);

      if (startDate != null) {
        query = query.gte('fecha', startDate.toIso8601String());
      }
      if (endDate != null) {
        // Para incluir todo el día final, sumamos 23h 59m 59s
        final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        query = query.lte('fecha', endOfDay.toIso8601String());
      }

      final response = await query;
      return (response as List).map((json) => EgresoModel.fromJson(json)).toList();
    } catch (e) {
      print('Error fetchEgresos: $e');
      rethrow;
    }
  }

  Future<EgresoModel> insertEgreso(EgresoModel egreso) async {
    try {
      final response = await _supabase
          .schema(_schema)
          .from('egresos')
          .insert(egreso.toJson())
          .select()
          .single();
      
      return EgresoModel.fromJson(response);
    } catch (e) {
      print('Error insertEgreso: $e');
      rethrow;
    }
  }

  Future<void> deleteEgreso(int id) async {
    try {
      await _supabase
          .schema(_schema)
          .from('egresos')
          .delete()
          .eq('id', id);
    } catch (e) {
      print('Error deleteEgreso: $e');
      rethrow;
    }
  }
}
