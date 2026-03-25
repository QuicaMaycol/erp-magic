import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../services/cliente_service.dart';

class PublicClientFormScreen extends StatefulWidget {
  const PublicClientFormScreen({super.key});

  @override
  State<PublicClientFormScreen> createState() => _PublicClientFormScreenState();
}

class _PublicClientFormScreenState extends State<PublicClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ClienteService _clienteService = ClienteService();

  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _paisController = TextEditingController();
  final _celularController = TextEditingController();
  final _productoController = TextEditingController();
  final _precioController = TextEditingController();
  final _otroMedioPagoController = TextEditingController();
  
  String _selectedMoneda = 'USD';
  String _selectedMedioPago = 'PayPal';
  bool _isLoading = false;
  bool _isCelularEnabled = false;
  ClienteModel? _clienteGuardado;

  final List<Map<String, String>> _countries = [
    {'name': 'Perú', 'code': '+51'},
    {'name': 'México', 'code': '+52'},
    {'name': 'Colombia', 'code': '+57'},
    {'name': 'Ecuador', 'code': '+593'},
    {'name': 'Chile', 'code': '+56'},
    {'name': 'Argentina', 'code': '+54'},
    {'name': 'Bolivia', 'code': '+591'},
    {'name': 'Venezuela', 'code': '+58'},
    {'name': 'España', 'code': '+34'},
    {'name': 'Estados Unidos', 'code': '+1'},
    {'name': 'República Dominicana', 'code': '+1'},
    {'name': 'Costa Rica', 'code': '+506'},
    {'name': 'Panamá', 'code': '+507'},
    {'name': 'Uruguay', 'code': '+598'},
    {'name': 'Paraguay', 'code': '+595'},
    {'name': 'Honduras', 'code': '+504'},
    {'name': 'El Salvador', 'code': '+503'},
    {'name': 'Nicaragua', 'code': '+505'},
    {'name': 'Guatemala', 'code': '+502'},
    {'name': 'Puerto Rico', 'code': '+1'},
  ];

  final List<String> _mediosPago = ['PayPal', 'Hotmart', 'Ria', 'Remitly', 'Yape', 'Plin', 'Global66', 'Otro'];

  @override
  Widget build(BuildContext context) {
    if (_clienteGuardado != null) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF16161A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.1), blurRadius: 40, spreadRadius: 10),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'img/logo.png',
                        height: 80,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Registro de Compra',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Por favor, completa tus datos para generar tu comprobante y vincular tu pedido.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.white54),
                    ),
                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(child: _buildTextField('Nombres', _nombresController, icon: Icons.person_outline, isRequired: true)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField('Apellidos', _apellidosController, isRequired: true)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCountryAutocomplete(),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Celular / WhatsApp', 
                      _celularController, 
                      icon: Icons.phone_android, 
                      keyboardType: TextInputType.phone, 
                      isRequired: true, 
                      enabled: _isCelularEnabled
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('Producto/Servicio', _productoController, icon: Icons.shopping_bag_outlined, isRequired: true),
                    const SizedBox(height: 8),
                    _buildProductChips(),
                    const SizedBox(height: 6),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline, size: 14, color: Colors.white38),
                        SizedBox(width: 6),
                        Expanded(child: Text('Si no encuentras en las alternativas lo que buscas, solo describe con dos palabras el servicio que necesitas (ej: "audio cumpleaños").', style: TextStyle(fontSize: 12, color: Colors.white38, fontStyle: FontStyle.italic))),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                         Expanded(
                           flex: 1,
                           child: _buildDropdown(
                             value: _selectedMoneda,
                             items: ['USD', 'S/.'],
                             onChanged: (val) => setState(() => _selectedMoneda = val!),
                           )
                         ),
                         const SizedBox(width: 16),
                         Expanded(
                           flex: 2,
                           child: _buildTextField('Precio (Monto Total)', _precioController, keyboardType: TextInputType.number, isRequired: true)
                         ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPriceChips(),
                    const SizedBox(height: 16),
                    _buildPaymentChips(),
                    const SizedBox(height: 40),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('GENERAR RECIBO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    final cliente = _clienteGuardado!;
    final fechaFormateada = DateFormat('dd/MM/yyyy HH:mm', 'es').format(DateTime.now());
    final nroBoleta = 'B001-${cliente.numBoleta.toString().padLeft(6, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              decoration: BoxDecoration(
                color: const Color(0xFF16161A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF10B981).withOpacity(0.1), blurRadius: 40, spreadRadius: 10),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Encabezado del recibo
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1B1B21),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        Image.asset('img/logo.png', height: 60, fit: BoxFit.contain),
                        const SizedBox(height: 16),
                        const Text('COMPROBANTE DE PAGO', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        Text(nroBoleta, style: const TextStyle(color: Color(0xFF10B981), fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
                      ],
                    ),
                  ),
                  
                  // Cuerpo del recibo
                  Padding(
                     padding: const EdgeInsets.all(32),
                     child: Column(
                       children: [
                         _buildReceiptRow('Fecha:', fechaFormateada),
                         const Divider(color: Colors.white10, height: 24),
                         _buildReceiptRow('Cliente:', '${cliente.nombres} ${cliente.apellidos}'),
                         const SizedBox(height: 12),
                         _buildReceiptRow('Teléfono:', cliente.celular ?? ''),
                         const Divider(color: Colors.white10, height: 24),
                         _buildReceiptRow('Servicio:', cliente.producto ?? ''),
                         const SizedBox(height: 12),
                         _buildReceiptRow('Medio de Pago:', cliente.medioPago ?? ''),
                         const Divider(color: Colors.white10, height: 32),
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             const Text('TOTAL PAGADO', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                             Text(
                               '${cliente.tipoMoneda == 'USD' ? '\$' : 'S/.'} ${cliente.precio?.toStringAsFixed(2) ?? '0.00'}', 
                               style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 24, fontWeight: FontWeight.w900)
                             ),
                           ],
                         ),
                       ]
                     )
                  ),

                  // Botones de acción
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final phone = '+51939218802';
                              final message = "¡Hola! Adjunto mi comprobante de pago generado.\n\n"
                                "*Recibo:* $nroBoleta\n"
                                "*Cliente:* ${cliente.nombres} ${cliente.apellidos}\n"
                                "*Servicio:* ${cliente.producto}\n"
                                "*Total:* ${cliente.tipoMoneda == 'USD' ? '\$' : 'S/.'} ${cliente.precio?.toStringAsFixed(2) ?? '0.00'}\n"
                                "*Medio de Pago:* ${cliente.medioPago}\n\nPor favor confirmar recepción. Gracias.";
                                
                              final url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              }
                            },
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('ENVIAR COMPROBANTE', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              _clienteGuardado = null;
                              _formKey.currentState?.reset();
                              _nombresController.clear();
                              _apellidosController.clear();
                              _paisController.clear();
                              _celularController.clear();
                              _isCelularEnabled = false;
                              _productoController.clear();
                              _precioController.clear();
                              _otroMedioPagoController.clear();
                            }),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white10),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('CREAR NUEVO RECIBO'),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value, 
            textAlign: TextAlign.right, 
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {IconData? icon, bool isRequired = false, TextInputType? keyboardType, bool enabled = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      style: TextStyle(color: enabled ? Colors.white : Colors.white24),
      validator: isRequired ? (value) {
        if (value == null || value.trim().isEmpty) return 'Requerido';
        return null;
      } : null,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        labelStyle: const TextStyle(color: Colors.white38),
        prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF7C3AED), size: 20) : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildDropdown({String? label, required String value, required List<String> items, required void Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF16161A),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF7C3AED)),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          onChanged: onChanged,
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        ),
      ),
    );
  }

  Widget _buildCountryAutocomplete() {
    return Autocomplete<Map<String, String>>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<Map<String, String>>.empty();
        }
        return _countries.where((country) =>
            country['name']!.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      displayStringForOption: (option) => option['name']!,
      onSelected: (option) {
        setState(() {
          _paisController.text = option['name']!;
          _celularController.text = '${option['code']} ';
          _isCelularEnabled = true;
          if (option['name']?.toLowerCase() == 'perú' || option['name']?.toLowerCase() == 'peru') {
            _selectedMoneda = 'S/.';
          } else {
            _selectedMoneda = 'USD';
          }
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // Para asegurar validación lo clonamos manual en el controlador real
        // pero la interacción la maneja el Autocomplete
        controller.addListener(() {
          _paisController.text = controller.text;
          if (controller.text.isEmpty) {
            setState(() => _isCelularEnabled = false);
          }
          if (controller.text.toLowerCase() == 'perú' || controller.text.toLowerCase() == 'peru') {
            if (_selectedMoneda != 'S/.') {
              setState(() => _selectedMoneda = 'S/.');
            }
          } else if (controller.text.isNotEmpty) {
            if (_selectedMoneda != 'USD') {
              setState(() => _selectedMoneda = 'USD');
            }
          }
        });
        
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(color: Colors.white),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Requerido';
            return null;
          },
          decoration: InputDecoration(
            labelText: 'País (Escribe para buscar) *',
            labelStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.public, color: Color(0xFF7C3AED), size: 20),
            filled: true,
            fillColor: Colors.white.withOpacity(0.03),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 320,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF16161A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10),
                ],
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    title: Text(option['name']!, style: const TextStyle(color: Colors.white)),
                    trailing: Text(option['code']!, style: const TextStyle(color: Colors.white38)),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductChips() {
    final opciones = [
      'Audio para revelación de género',
      'Audio para babyshower',
      'Audio de Fallecidos',
      'Invitación digital',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: opciones.map((opt) {
        return ActionChip(
          label: Text(opt, style: const TextStyle(fontSize: 12, color: Colors.white)),
          backgroundColor: Colors.white.withOpacity(0.05),
          side: const BorderSide(color: Color(0xFF7C3AED), width: 0.8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          onPressed: () {
            setState(() {
              _productoController.text = opt;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildPriceChips() {
    final precios = ['23', '25', '30', '35', '55', '65'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: precios.map((precio) {
        return ActionChip(
          label: Text(precio, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white.withOpacity(0.05),
          side: const BorderSide(color: Color(0xFF10B981), width: 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          onPressed: () {
            setState(() {
              _precioController.text = precio;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildPaymentChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('  Medio de Pago', style: TextStyle(color: Colors.white38, fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _mediosPago.map((pago) {
            final isSelected = _selectedMedioPago == pago;
            return ChoiceChip(
              label: Text(pago, style: TextStyle(
                fontSize: 13, 
                color: isSelected ? Colors.white : Colors.white70, 
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
              )),
              selected: isSelected,
              selectedColor: const Color(0xFF7C3AED),
              backgroundColor: Colors.white.withOpacity(0.05),
              side: BorderSide(
                color: isSelected ? const Color(0xFF7C3AED) : Colors.white10,
                width: 1.0,
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              onSelected: (bool selected) {
                if (selected) {
                  setState(() {
                    _selectedMedioPago = pago;
                  });
                }
              },
            );
          }).toList(),
        ),
        if (_selectedMedioPago == 'Otro') ...[
          const SizedBox(height: 16),
          _buildTextField('Especificar Medio de Pago', _otroMedioPagoController, isRequired: true, icon: Icons.payment)
        ],
      ],
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final medioFinal = _selectedMedioPago == 'Otro' 
          ? _otroMedioPagoController.text.trim() 
          : _selectedMedioPago;

      final nuevoCliente = ClienteModel(
        nombres: _nombresController.text.trim(),
        apellidos: _apellidosController.text.trim(),
        celular: _celularController.text.trim(),
        pais: _paisController.text.trim(),
        producto: _productoController.text.trim(),
        precio: double.tryParse(_precioController.text.trim()),
        tipoMoneda: _selectedMoneda,
        medioPago: medioFinal,
      );

      final guardado = await _clienteService.insertCliente(nuevoCliente);

      if (mounted) {
        setState(() {
          _clienteGuardado = guardado;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }
}
