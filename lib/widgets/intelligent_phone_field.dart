import 'package:flutter/material.dart';
import 'package:intl_phone_field/countries.dart';

class IntelligentPhoneField extends StatefulWidget {
  final String initialValue;
  final Function(String fullNumber, String countryName, String isoCode) onChanged;

  const IntelligentPhoneField({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<IntelligentPhoneField> createState() => _IntelligentPhoneFieldState();
}

class _IntelligentPhoneFieldState extends State<IntelligentPhoneField> {
  final TextEditingController _controller = TextEditingController();
  String? _detectedCountryName;
  String? _detectedIsoCode;
  String? _detectedFlag;
  
  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialValue;
  }

  void _analyzeInput(String value) {
    if (value.startsWith('+')) {
      // Intentar detectar país por el prefijo
      bool found = false;
      // Ordenamos por longitud de dialCode descendente para evitar falsos positivos (ej +1 vs +124)
      final sortedCountries = List<Country>.from(countries)
        ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));

      for (var country in sortedCountries) {
        if (value.startsWith('+${country.dialCode}')) {
          setState(() {
            _detectedCountryName = country.name;
            _detectedIsoCode = country.code;
            _detectedFlag = country.flag;
          });
          found = true;
          break;
        }
      }
      if (!found) {
        setState(() {
          _detectedCountryName = null;
          _detectedIsoCode = null;
        });
      }
    } else {
      setState(() {
        _detectedCountryName = null;
        _detectedIsoCode = null;
      });
    }
    
    // Notificamos cambios básicos
    widget.onChanged(
      _controller.text,
      _detectedCountryName ?? "Desconocido",
      _detectedIsoCode ?? "??",
    );
  }

  void _confirmCountry() {
    if (_detectedIsoCode != null) {
      final text = _controller.text;
      // Si el número ya tiene el ISO entre paréntesis, no lo agregamos de nuevo
      if (!text.contains('($_detectedIsoCode)')) {
        setState(() {
          _controller.text = "$text ($_detectedIsoCode)";
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
      }
      _analyzeInput(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: _controller,
            onChanged: _analyzeInput,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'WhatsApp / Celular',
              labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: const Icon(Icons.phone_android, color: Color(0xFF7C3AED), size: 18),
            ),
          ),
        ),
        if (_detectedCountryName != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: InkWell(
              onTap: _confirmCountry,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_detectedFlag ?? "📍", style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Text(
                      "¿Confirmar ${_detectedCountryName}? (+${_detectedIsoCode})",
                      style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF7C3AED), size: 14),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
