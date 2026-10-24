import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controladores/proveedor_simulador.dart';
import 'seccion_activos.dart';
import 'seccion_ingresos.dart';
import 'seccion_costos_variables.dart';
import 'seccion_costos_fijos.dart';
import 'vista_config_temporal.dart';
import 'vista_financiamiento.dart';

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

    // Pasar contexto para PDF/dialogs
    proveedor.setContext(context);

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
    return Consumer<ProveedorSimulador>(
      builder: (context, proveedor, _) {
        final estaConfigurado = proveedor.estaConfigurado;
        final tieneFinanciamiento = proveedor.estructuraCapital != null;

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _llaveFormulario,
            child: ListView(
              children: [
                // === PASO 0: CONFIGURACIÓN TEMPORAL (OBLIGATORIO) ===
                if (!estaConfigurado) ...[
                  const VistaConfigTemporal(),
                  const SizedBox(height: 24),
                  _buildStepIndicator(0, 4, 'Configuración Temporal'),
                ] else ...[
                  // Mostrar resumen de configuración y botón para cambiarla
                  _buildConfigSummary(proveedor),
                  const SizedBox(height: 24),
                  _buildStepIndicator(1, 4, 'Activos e Inversión'),
                  
                  // === PASO 1: SECCIÓN ACTIVOS ===
                  const SeccionActivos(),
                  const SizedBox(height: 32),

                  // Divisor visual
                  Divider(color: Colors.grey.shade300, thickness: 1),
                  const SizedBox(height: 24),

                  // === PASO 2: FINANCIAMIENTO (si no configurado) O RESUMEN ===
                  if (!tieneFinanciamiento) ...[
                    _buildStepIndicator(2, 4, 'Estructura de Financiamiento'),
                    const VistaFinanciamiento(),
                    const SizedBox(height: 32),
                    Divider(color: Colors.grey.shade300, thickness: 1),
                    const SizedBox(height: 24),
                  ] else ...[
                    _buildFinanciamientoSummary(proveedor),
                    const SizedBox(height: 24),
                    Divider(color: Colors.grey.shade300, thickness: 1),
                    const SizedBox(height: 24),
                  ],

                  // === PASO 3: INGRESOS ESTIMADOS ===
                  _buildStepIndicator(3, 6, 'Ingresos Estimados'),
                  const SeccionIngresos(),
                  const SizedBox(height: 32),
                  Divider(color: Colors.grey.shade300, thickness: 1),
                  const SizedBox(height: 24),

                  // === PASO 4: COSTOS VARIABLES ===
                  _buildStepIndicator(4, 7, 'Costos Variables'),
                  const SeccionCostosVariables(),
                  const SizedBox(height: 32),
                  Divider(color: Colors.grey.shade300, thickness: 1),
                  const SizedBox(height: 24),

                  // === PASO 5: COSTOS FIJOS ===
                  _buildStepIndicator(5, 7, 'Costos Fijos'),
                  const SeccionCostosFijos(),
                  const SizedBox(height: 32),
                  Divider(color: Colors.grey.shade300, thickness: 1),
                  const SizedBox(height: 24),

                  // === PASO 6: PARÁMETROS FINANCIEROS ===
                  _buildStepIndicator(6, 7, 'Parámetros de Evaluación'),

                  const Text(
                    'Parámetros de Evaluación Financiera',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'La Tasa de Descuento (TREMA) es la rentabilidad mínima esperada. '
                    'El Horizonte debe ser ≤ a los años de proyección configurados.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),

                  // Campo 1: Tasa de Descuento (TREMA)
                  TextFormField(
                    controller: _tasaCtrl,
                    focusNode: _nodoTasa,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_nodoAnios),
                    decoration: const InputDecoration(
                      labelText: 'Tasa de Descuento - TREMA (%) *',
                      hintText: 'Ej: 12.5',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.percent),
                      helperText: 'Tasa Mínima de Rentabilidad Esperada',
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

                  // Campo 2: Horizonte de Evaluación
                  TextFormField(
                    controller: _aniosCtrl,
                    focusNode: _nodoAnios,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _enviarFormulario(context.read<ProveedorSimulador>()),
                    decoration: InputDecoration(
                      labelText: 'Horizonte de Evaluación (Años) *',
                      hintText: 'Ej: 5',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.calendar_today),
                      helperText: 'Máx. ${proveedor.configTemporal.anosProyeccion} años (configuración temporal)',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (valor) {
                      if (valor == null || valor.isEmpty) return 'Requerido';
                      final numero = int.tryParse(valor);
                      if (numero == null) return 'Debe ser un número entero';
                      if (numero <= 0) return 'El horizonte debe ser de al menos 1 año';
                      final maxAnos = proveedor.configTemporal.anosProyeccion;
                      if (numero > maxAnos) return 'No puede exceder los $maxAnos años de proyección';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Botón Calcular
                  _buildCalculateButton(proveedor, tieneFinanciamiento),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFinanciamientoSummary(ProveedorSimulador proveedor) {
    final fin = proveedor.estructuraCapital!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.purple.shade700),
              const SizedBox(width: 12),
              Text(
                'Financiamiento Definido',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade800,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => proveedor.reiniciarFinanciamiento(),
                icon: Icon(Icons.edit, size: 18, color: Colors.purple.shade700),
                label: Text('Cambiar', style: TextStyle(color: Colors.purple.shade700)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.purple.shade700,
                  side: BorderSide(color: Colors.purple.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _ConfigChip(label: 'Capital Propio', value: '${fin.pctPropio.toStringAsFixed(1)}%', icon: Icons.person, highlight: true),
              _ConfigChip(label: 'Deuda', value: '${fin.pctDeuda.toStringAsFixed(1)}%', icon: Icons.credit_card),
              if (fin.tieneDeuda) ...[
                _ConfigChip(label: 'Préstamo', value: _formatCurrency(fin.montoPrestamo), icon: Icons.attach_money),
                _ConfigChip(label: 'Cuota/mes', value: _formatCurrency(fin.cuotaMensual), icon: Icons.payments),
                _ConfigChip(label: 'Tasa', value: '${fin.tasaInteresAnual?.toStringAsFixed(2)}%', icon: Icons.percent),
                _ConfigChip(label: 'Plazo', value: '${fin.plazoMeses} meses', icon: Icons.calendar_month),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigSummary(ProveedorSimulador proveedor) {
    final config = proveedor.configTemporal;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Text(
                'Configuración Temporal Definida',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => proveedor.reiniciarConfiguracionTemporal(),
                icon: Icon(Icons.edit, size: 18, color: Colors.blue.shade700),
                label: Text('Cambiar', style: TextStyle(color: Colors.blue.shade700)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  side: BorderSide(color: Colors.blue.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _ConfigChip(label: 'Periodo', value: '${config.mesesPorPeriodo} meses', icon: Icons.calendar_month),
              _ConfigChip(label: 'Proyección', value: '${config.anosProyeccion} años', icon: Icons.date_range),
              _ConfigChip(label: 'Ciclos/año', value: '${config.cosechasPorAnio}', icon: Icons.agriculture),
              _ConfigChip(label: 'Total Periodos', value: '${config.totalPeriodos}', icon: Icons.format_list_numbered, highlight: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int actual, int total, String titulo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          for (int i = 1; i <= total; i++) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: i <= actual ? Colors.green.shade700 : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$i',
                  style: TextStyle(
                    color: i <= actual ? Colors.white : Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            if (i < total)
              Expanded(
                child: Container(
                  height: 2,
                  color: i < actual ? Colors.green.shade700 : Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
          ],
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Paso $actual de $total: $titulo',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: actual <= total ? Colors.green.shade700 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculateButton(ProveedorSimulador proveedor, bool tieneFinanciamiento) {
    final tieneActivos = proveedor.inversionRequerida.activos.isNotEmpty;
    final montoTotal = proveedor.inversionRequerida.total;
    final ingresosCompletos = proveedor.ingresosCompletos;
    final costosVariablesCompletos = proveedor.costosVariablesCompletos;
    final costosFijosCompletos = proveedor.costosFijosCompletos;
    final listoParaCalcular = tieneActivos && tieneFinanciamiento && ingresosCompletos && costosVariablesCompletos && costosFijosCompletos;

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
                    'Agregue al menos un activo en Paso 1',
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          )
        else if (!tieneFinanciamiento)
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
                    'Complete la Estructura de Financiamiento en Paso 2',
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          )
        else if (!ingresosCompletos)
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
                    'Complete Ingresos Estimados en Paso 3 (${proveedor.configTemporal.totalPeriodos} periodos)',
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          )
        else if (!costosVariablesCompletos)
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
                    'Complete Costos Variables en Paso 4',
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          )
        else if (!costosFijosCompletos)
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
                    'Complete Costos Fijos en Paso 5',
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
                  'Inversión Requerida: ',
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
                if (proveedor.tieneDeuda) ...[
                  const SizedBox(width: 16),
                  Text(
                    '(Aporte Propio: ${_formatCurrency(proveedor.aportePropio)})',
                    style: TextStyle(color: Colors.green.shade700, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (proveedor.estaCargando || !listoParaCalcular)
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
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}

class _ConfigChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  const _ConfigChip({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? Colors.blue.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: highlight ? Colors.blue.shade300 : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: highlight ? Colors.blue.shade700 : Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.blue.shade800 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}