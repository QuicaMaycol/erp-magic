import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/egreso_model.dart';
import '../services/egreso_service.dart';
import 'package:excel/excel.dart' hide Border;
import '../utils/downloader.dart';

class EgresosScreen extends StatefulWidget {
  const EgresosScreen({super.key});

  @override
  State<EgresosScreen> createState() => _EgresosScreenState();
}

class _EgresosScreenState extends State<EgresosScreen> {
  final EgresoService _egresoService = EgresoService();
  List<EgresoModel> _egresos = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  DateTime? _startDate;
  DateTime? _endDate;

  // Controladores para el diálogo de nuevo egreso
  final _descripcionController = TextEditingController();
  final _montoController = TextEditingController();
  final _medioPagoController = TextEditingController();
  final _categoriaController = TextEditingController();
  String _selectedMoneda = 'USD';

  @override
  void initState() {
    super.initState();
    // No cargamos automáticamente
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _loadEgresos() async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });
    try {
      final data = await _egresoService.fetchEgresos(startDate: _startDate, endDate: _endDate);
      if (mounted) {
        setState(() {
          _egresos = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando egresos: $e'), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  Future<void> _showAddEgresoDialog() async {
    _descripcionController.clear();
    _montoController.clear();
    _medioPagoController.clear();
    _categoriaController.clear();
    _selectedMoneda = 'USD';

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1B1B21),
          title: const Text('Registrar Nuevo Egreso', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _descripcionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Descripción'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _montoController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Monto'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedMoneda,
                            dropdownColor: const Color(0xFF1B1B21),
                            style: const TextStyle(color: Colors.white),
                            items: ['USD', 'PEN'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                            onChanged: (v) => setDialogState(() => _selectedMoneda = v!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _medioPagoController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Medio de Pago'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _categoriaController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Categoría'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_descripcionController.text.isEmpty || _montoController.text.isEmpty) return;
                
                final nuevo = EgresoModel(
                  descripcion: _descripcionController.text.trim(),
                  monto: double.tryParse(_montoController.text.trim()) ?? 0.0,
                  tipoMoneda: _selectedMoneda,
                  medioPago: _medioPagoController.text.trim(),
                  categoria: _categoriaController.text.trim(),
                  fecha: DateTime.now(),
                );

                try {
                  await _egresoService.insertEgreso(nuevo);
                  if (mounted) {
                    Navigator.pop(context);
                    _loadEgresos();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Egreso registrado'), backgroundColor: Colors.green)
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent)
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
              child: const Text('GUARDAR EGRESO'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF7C3AED))),
    );
  }

  void _exportarExcel() {
    if (_egresos.isEmpty) return;

    final excel = Excel.createExcel();
    final sheet = excel['Egresos'];
    if (excel.tables.containsKey('Sheet1')) excel.delete('Sheet1');

    sheet.appendRow([
      TextCellValue('FECHA'),
      TextCellValue('DESCRIPCIÓN'),
      TextCellValue('MONTO'),
      TextCellValue('MONEDA'),
      TextCellValue('CATEGORÍA'),
      TextCellValue('MEDIO PAGO'),
    ]);

    for (var e in _egresos) {
      sheet.appendRow([
        TextCellValue(e.fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(e.fecha!) : ''),
        TextCellValue(e.descripcion),
        DoubleCellValue(e.monto),
        TextCellValue(e.tipoMoneda),
        TextCellValue(e.categoria ?? ''),
        TextCellValue(e.medioPago ?? ''),
      ]);
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      downloadWeb(fileBytes, "egresos_erp_magic.xlsx");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gestión de Egresos',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showAddEgresoDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Nuevo Egreso'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _exportarExcel,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Excel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981).withOpacity(0.2), 
                        foregroundColor: const Color(0xFF10B981),
                        side: const BorderSide(color: Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16161A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                   InkWell(
                     onTap: () => _selectStartDate(context),
                     child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                       decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                       child: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           const Icon(Icons.date_range, color: Colors.white54, size: 20),
                           const SizedBox(width: 8),
                           Text(_startDate == null ? 'Fecha Inicio' : DateFormat('dd/MM/yyyy').format(_startDate!), style: const TextStyle(color: Colors.white)),
                         ],
                       ),
                     )
                   ),
                   const Text('-', style: TextStyle(color: Colors.white54)),
                   InkWell(
                     onTap: () => _selectEndDate(context),
                     child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                       decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                       child: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           const Icon(Icons.date_range, color: Colors.white54, size: 20),
                           const SizedBox(width: 8),
                           Text(_endDate == null ? 'Fecha Fin' : DateFormat('dd/MM/yyyy').format(_endDate!), style: const TextStyle(color: Colors.white)),
                         ],
                       ),
                     )
                   ),
                   ElevatedButton.icon(
                     onPressed: _loadEgresos,
                     icon: const Icon(Icons.search),
                     label: const Text('Buscar'),
                     style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white),
                   ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: !_hasSearched && !_isLoading 
                ? const Center(child: Text('Usa los filtros o realiza una búsqueda para ver los egresos.', style: TextStyle(color: Colors.white54)))
                : _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
                  : _egresos.isEmpty 
                    ? const Center(child: Text("No se encontraron egresos.", style: TextStyle(color: Colors.white54)))
                    : Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF16161A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Scrollbar(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('FECHA', style: TextStyle(color: Colors.white54))),
                                    DataColumn(label: Text('DESCRIPCIÓN', style: TextStyle(color: Colors.white54))),
                                    DataColumn(label: Text('MONTO', style: TextStyle(color: Colors.white54))),
                                    DataColumn(label: Text('CATEGORÍA', style: TextStyle(color: Colors.white54))),
                                    DataColumn(label: Text('MEDIO PAGO', style: TextStyle(color: Colors.white54))),
                                    DataColumn(label: Text('ACCIONES', style: TextStyle(color: Colors.white54))),
                                  ],
                                  rows: _egresos.map((egreso) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(egreso.fecha != null ? DateFormat('dd/MM HH:mm').format(egreso.fecha!) : '-', style: const TextStyle(color: Colors.white38, fontSize: 12))),
                                        DataCell(Text(egreso.descripcion, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                        DataCell(Text('${egreso.tipoMoneda == "PEN" ? "S/." : "\$"} ${egreso.monto.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold))),
                                        DataCell(Text(egreso.categoria ?? '-', style: const TextStyle(color: Colors.white70))),
                                        DataCell(Text(egreso.medioPago ?? '-', style: const TextStyle(color: Colors.white70))),
                                        DataCell(IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 20),
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                backgroundColor: const Color(0xFF1B1B21),
                                                title: const Text('¿Eliminar egreso?', style: TextStyle(color: Colors.white)),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
                                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ELIMINAR', style: TextStyle(color: Colors.redAccent))),
                                                ],
                                              )
                                            );
                                            if (confirm == true) {
                                              await _egresoService.deleteEgreso(egreso.id!);
                                              _loadEgresos();
                                            }
                                          },
                                        )),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
