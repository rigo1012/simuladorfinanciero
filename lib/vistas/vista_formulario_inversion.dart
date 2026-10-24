import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controladores/proveedor_simulador.dart';
import 'seccion_activos.dart';

class VistaFormularioInversion extends StatefulWidget {
  const VistaFormularioInversion({super.key});

  @override
  State<VistaFormularioInversion> createState() => _VistaFormularioInversionState();
}

class _VistaFormularioInversionState extends State<VistaFormularioInversion> {
  final _llaveFormulario = GlobalKey<FormState>();
  final TextEditingController _tasaCtrl = TextEditingController();
  final TextEditingController _aniosCtrl = TextEditingController();
  final FocusNode _nodoTasa = FocusNode();
  final FocusNode _nodoAnios = FocusNode();

  void _enviarFormulario(ProveedorSimulador proveedor) {
    if (proveedor.estaCargando) return;

    // Validar que haya activos
    if (proveedor.inversionRequerida.activos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe agregar al menos un activo en la sección "Activos"'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // El validador bloquea la ejecución si algún campo falla
    if (!_llaveFormulario.currentState!.validate()) return;

    final tasa = double.parse(_tasaCtrl.text);
    final anios = int.parse(_aniosCtrl.text);

    proveedor.procesarSimulacionSimple(tasa, anios);
  }

  @override
  void dispose() {
    _tasaCtrl.dispose();
    _aniosCtrl.dispose();
    _nodoTasa.dispose();
    _nodoAnios.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _llaveFormulario,
        child: ListView(
          children: [
            const Text(
              'Configuración del Sistema de Riego',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Defina los activos del proyecto. La Inversión Requerida se calcula automáticamente.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),

            // === SECCIÓN ACTIVOS (NUEVA) ===
            const SeccionActivos(),
            const SizedBox(height: 32),

            // Divisor visual
            Divider(color: Colors.grey.shade300, thickness: 1),
            const SizedBox(height: 24),

            // === PARÁMETROS FINANCIEROS ===
            const Text(
              'Parámetros de Evaluación Financiera',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Campo 1: Tasa de Descuento
            TextFormField(
              controller: _tasaCtrl,
              focusNode: _nodoTasa,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_nodoAnios),
              decoration: const InputDecoration(
                labelText: 'Tasa de Descuento (%) *',
                hintText: 'Ej: 12.5',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.percent),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
              ],
              validator: (valor) {
                if (valor == null || valor.isEmpty) return 'Requerido';
                final numero = double.tryParse(valor);
                if (numero == null) return 'Número inválido';
                if (numero <= 0 || numero > 100) return 'La tasa debe estar entre 0.01 y 100';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Campo 2: Horizonte de Inversión
            TextFormField(
              controller: _aniosCtrl,
              focusNode: _nodoAnios,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _enviarFormulario(context.read<ProveedorSimulador>()),
              decoration: const InputDecoration(
                labelText: 'Horizonte de Inversión (Años) *',
                hintText: 'Ej: 10',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              validator: (valor) {
                if (valor == null || valor.isEmpty) return 'Requerido';
                final numero = int.tryParse(valor);
                if (numero == null) return 'Debe ser un número entero';
                if (numero <= 0) return 'El horizonte debe ser de al menos 1 año';
                if (numero > 50) return 'Horizonte irreal para equipamiento de riego';
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Botón Calcular
            Consumer<ProveedorSimulador>(
              builder: (context, proveedor, child) {
                final tieneActivos = proveedor.inversionRequerida.activos.isNotEmpty;
                final montoTotal = proveedor.inversionRequerida.total;

                return Column(
                  children: [
                    if (!tieneActivos)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Agregue al menos un activo para habilitar el cálculo',
                                style: TextStyle(color: Colors.orange.shade800),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green.shade700),
                            const SizedBox(width: 12),
                            Text(
                              'Inversión Requerida calculada: ',
                              style: TextStyle(color: Colors.green.shade800),
                            ),
                            Text(
                              _formatCurrency(montoTotal),
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (proveedor.estaCargando || !tieneActivos)
                            ? null
                            : () => _enviarFormulario(proveedor),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(200, 56),
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: proveedor.estaCargando
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Text(
                                'Calcular Rentabilidad',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}