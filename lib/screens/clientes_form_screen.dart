import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../services/cliente_service.dart';
import '../services/auth_service.dart';
import 'package:excel/excel.dart' hide Border;
import '../utils/downloader.dart';

class ClientesFormScreen extends StatefulWidget {
  const ClientesFormScreen({super.key});

  @override
  State<ClientesFormScreen> createState() => _ClientesFormScreenState();
}

class _ClientesFormScreenState extends State<ClientesFormScreen> {
  final ClienteService _clienteService = ClienteService();
  List<ClienteModel> _clientes = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _unificarClientes = false;

  @override
  void initState() {
    super.initState();
    // Ya no cargamos clientes automáticamente
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

  Future<void> _loadClientes() async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });
    try {
      var data = await _clienteService.fetchClientesForm(startDate: _startDate, endDate: _endDate);
      
      if (_unificarClientes && data.isNotEmpty) {
        final grouped = <String, ClienteModel>{};
        for (var c in data) {
          final paramNombre = c.nombres.trim().toLowerCase();
          final paramApellido = c.apellidos.trim().toLowerCase();
          final contactKey = '$paramNombre-$paramApellido';
          
          final key = '${contactKey}_${c.tipoMoneda}';
          
          if (grouped.containsKey(key)) {
            final existing = grouped[key]!;
            final currentPrice = existing.precio ?? 0;
            final extraPrice = c.precio ?? 0;
            
            final json = existing.toJson();
            json['precio'] = currentPrice + extraPrice;
            json['producto'] = 'Varios depósitos';
            
            grouped[key] = ClienteModel.fromJson(json);
          } else {
             grouped[key] = ClienteModel.fromJson(c.toJson());
          }
        }
        data = grouped.values.toList();
      }

      if (mounted) {
        setState(() {
          _clientes = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando clientes: $e'), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  void _exportarExcel() {
    if (_clientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay clientes para exportar', style: TextStyle(color: Colors.white)))
      );
      return;
    }

    final excel = Excel.createExcel();
    final sheet = excel['Clientes Form'];
    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    sheet.appendRow([
      TextCellValue('BOLETA'),
      TextCellValue('CLIENTE'),
      TextCellValue('PAÍS'),
      TextCellValue('CONTACTO'),
      TextCellValue('PRODUCTO'),
      TextCellValue('MONTO'),
      TextCellValue('MONEDA'),
      TextCellValue('MEDIO PAGO'),
      TextCellValue('FECHA'),
    ]);

    for (var c in _clientes) {
      sheet.appendRow([
        TextCellValue('B001-${c.numBoleta.toString().padLeft(6, '0')}'),
        TextCellValue(c.nombreCompleto),
        TextCellValue(c.pais ?? ''),
        TextCellValue(c.celular ?? ''),
        TextCellValue(c.producto ?? ''),
        DoubleCellValue(c.precio ?? 0.0),
        TextCellValue(c.tipoMoneda ?? ''),
        TextCellValue(c.medioPago ?? ''),
        TextCellValue(c.fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(c.fecha!) : ''),
      ]);
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      downloadWeb(fileBytes, "formulario_erp_magic.xlsx");
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
                  'Formulario Público',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _exportarExcel,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Excel', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981).withOpacity(0.2), 
                        foregroundColor: const Color(0xFF10B981),
                        elevation: 0,
                        side: const BorderSide(color: Color(0xFF10B981)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Obtiene la base de la URL actual completa (incluyendo subcarpetas como /login/)
                        final baseUrl = '${Uri.base.origin}${Uri.base.path}';
                        final url = '$baseUrl#/formulario-cliente';
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Enlace copiado al portapapeles'), backgroundColor: Colors.green)
                        );
                      },
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Compartir Formulario'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED).withOpacity(0.2), 
                        foregroundColor: const Color(0xFF7C3AED),
                        elevation: 0,
                        side: const BorderSide(color: Color(0xFF7C3AED)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF7C3AED)),
                      tooltip: "Restablecer filtros",
                      onPressed: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                          _unificarClientes = false;
                          _hasSearched = false;
                          _clientes = [];
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Consulta todos los ingresos guardados de la nueva plataforma.',
              style: TextStyle(fontSize: 14, color: Colors.white38),
            ),
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
                   Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Checkbox(
                         value: _unificarClientes,
                         onChanged: (v) => setState(() => _unificarClientes = v ?? false),
                         activeColor: const Color(0xFF7C3AED),
                       ),
                       const Text('Unificar por cliente (sumar montos)', style: TextStyle(color: Colors.white70)),
                     ],
                   ),
                   ElevatedButton.icon(
                     onPressed: _loadClientes,
                     icon: const Icon(Icons.search),
                     label: const Text('Buscar', style: TextStyle(fontWeight: FontWeight.bold)),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: const Color(0xFF7C3AED),
                       foregroundColor: Colors.white,
                     ),
                   ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: !_hasSearched && !_isLoading 
                ? const Center(child: Text('Usa los filtros y presiona Buscar para cargar los datos.', style: TextStyle(color: Colors.white54, fontSize: 16)))
                : _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
                  : _clientes.isEmpty 
                    ? const Center(child: Text("No hay clientes registrados que coincidan con los filtros.", style: TextStyle(color: Colors.white54)))
                    : Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF16161A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.all(Colors.black12),
                              dataRowMaxHeight: 65,
                              dataRowMinHeight: 60,
                              dividerThickness: 0.5,
                              columns: const [
                                DataColumn(label: Text('BOLETA', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('CLIENTE', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('CONTACTO', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('PRODUCTO', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('MONTO', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('FECHA', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
                              ],
                              rows: _clientes.map((cliente) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                        child: Text(
                                          "B001-${cliente.numBoleta.toString().padLeft(6, '0')}",
                                          style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(cliente.nombreCompleto, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                          if (cliente.pais != null && cliente.pais!.isNotEmpty)
                                            Text(cliente.pais!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text(cliente.celular ?? '-', style: const TextStyle(color: Colors.white70))),
                                    DataCell(Text(cliente.producto ?? '-', style: const TextStyle(color: Colors.white70))),
                                    DataCell(
                                      Text(
                                        cliente.precio != null 
                                          ? '${cliente.tipoMoneda == "PEN" ? "S/." : "\$"} ${cliente.precio!.toStringAsFixed(2)}' 
                                          : '-', 
                                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)
                                      )
                                    ),
                                    DataCell(
                                      Text(
                                        cliente.fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(cliente.fecha!) : '-',
                                        style: const TextStyle(color: Colors.white38, fontSize: 12)
                                      )
                                    ),
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
