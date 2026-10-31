import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controladores/proveedor_simulador.dart';
import '../modelos/estructura_capital.dart';
import '../modelos/configuracion_temporal.dart';

/// Paso 1: Estructura de Financiamiento (Capital Propio vs Deuda).
/// 
/// Define el % de capital propio y % de deuda (deben sumar 100%).
/// Si hay deuda (>0%), solicita Tasa de Interés Anual y Plazo en Meses.
/// Calcula y muestra: Monto Préstamo, Aporte Propio, Cuota Mensual (Sistema Francés).
class VistaFinanciamiento extends StatefulWidget {
  const VistaFinanciamiento({super.key});

  @override
  State<VistaFinanciamiento> createState() => _VistaFinanciamientoState();
}

class _VistaFinanciamientoState extends State<VistaFinanciamiento> {
  final _formKey = GlobalKey<FormState>();
  
  final _pctPropioCtrl = TextEditingController();
  final _pctDeudaCtrl = TextEditingController();
  final _tasaInteresCtrl = TextEditingController();
  final _plazoMesesCtrl = TextEditingController();
  
  final _pctPropioFocus = FocusNode();
  final _pctDeudaFocus = FocusNode();
  final _tasaFocus = FocusNode();
  final _plazoFocus = FocusNode();

  // Para sincronizar % propio + % deuda = 100
  bool _actualizandoPropio = false;
  bool _actualizandoDeuda = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pctPropioCtrl.dispose();
    _pctDeudaCtrl.dispose();
    _tasaInteresCtrl.dispose();
    _plazoMesesCtrl.dispose();
    _pctPropioFocus.dispose();
    _pctDeudaFocus.dispose();
    _tasaFocus.dispose();
    _plazoFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProveedorSimulador>(
      builder: (context, proveedor, _) {
        final inversion = proveedor.inversionRequerida.total;
        final config = proveedor.estaConfigurado ? proveedor.configTemporal : null;
        final financiamientoActual = proveedor.estructuraCapital;

        // Valores por defecto o actuales
        if (_pctPropioCtrl.text.isEmpty && financiamientoActual == null) {
          _pctPropioCtrl.text = '70';
          _pctDeudaCtrl.text = '30';
        } else if (financiamientoActual != null && _pctPropioCtrl.text.isEmpty) {
          _pctPropioCtrl.text = financiamientoActual.pctPropio.toStringAsFixed(1);
          _pctDeudaCtrl.text = financiamientoActual.pctDeuda.toStringAsFixed(1);
          _tasaInteresCtrl.text = financiamientoActual.tasaInteresAnual?.toStringAsFixed(2) ?? '';
          _plazoMesesCtrl.text = financiamientoActual.plazoMeses?.toString() ?? '';
        }

        final pctPropio = double.tryParse(_pctPropioCtrl.text) ?? 0;
        final pctDeuda = double.tryParse(_pctDeudaCtrl.text) ?? 0;
        final suma = pctPropio + pctDeuda;
        final sumaValida = (suma - 100).abs() < 0.01;
        final tieneDeuda = pctDeuda > 0;
        final tasa = double.tryParse(_tasaInteresCtrl.text) ?? 0;
        final plazo = int.tryParse(_plazoMesesCtrl.text) ?? 0;

        // Crear estructura temporal para preview
        final estructuraPreview = (sumaValida && inversion > 0)
            ? EstructuraCapital(
                pctPropio: pctPropio,
                pctDeuda: pctDeuda,
                tasaInteresAnual: tieneDeuda && tasa > 0 ? tasa : null,
                plazoMeses: tieneDeuda && plazo > 0 ? plazo : null,
                inversionRequerida: inversion,
              )
            : null;

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Header
                _buildHeader(inversion),
                const SizedBox(height: 24),

                // Advertencia si ya guardado
                if (financiamientoActual != null) _buildWarningCard(proveedor),
                if (financiamientoActual != null) const SizedBox(height: 16),

                // === SECCIÓN: ESTRUCTURA DE CAPITAL ===
                _buildSectionTitle('Estructura de Capital', Icons.account_balance_wallet),
                const SizedBox(height: 12),
                Text(
                  'Defina cómo se financia la Inversión Requerida. La suma debe ser 100%.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    // % Capital Propio
                    Expanded(
                      child: TextFormField(
                        controller: _pctPropioCtrl,
                        focusNode: _pctPropioFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_pctDeudaFocus),
                        onChanged: (v) => _onPctPropioChanged(v, pctDeuda),
                        decoration: InputDecoration(
                          labelText: 'Capital Propio (%) *',
                          hintText: 'Ej: 70',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.person),
                          suffixText: '%',
                          errorText: !sumaValida && _pctPropioCtrl.text.isNotEmpty 
                              ? 'Debe sumar 100% con Deuda' : null,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requerido';
                          final n = double.tryParse(v);
                          if (n == null || n < 0 || n > 100) return '0-100%';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // % Deuda
                    Expanded(
                      child: TextFormField(
                        controller: _pctDeudaCtrl,
                        focusNode: _pctDeudaFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => tieneDeuda 
                            ? FocusScope.of(context).requestFocus(_tasaFocus)
                            : null,
                        onChanged: (v) => _onPctDeudaChanged(v, pctPropio),
                        decoration: InputDecoration(
                          labelText: 'Financiamiento / Deuda (%) *',
                          hintText: 'Ej: 30',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.credit_card),
                          suffixText: '%',
                          errorText: !sumaValida && _pctDeudaCtrl.text.isNotEmpty 
                              ? 'Debe sumar 100% con Propio' : null,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requerido';
                          final n = double.tryParse(v);
                          if (n == null || n < 0 || n > 100) return '0-100%';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                // Barra de progreso visual 100%
                const SizedBox(height: 12),
                _buildPctBar(pctPropio, pctDeuda, sumaValida),
                const SizedBox(height: 24),

                // === SECCIÓN CONDICIONAL: DETALLES DE DEUDA ===
                AnimatedCrossFade(
                  firstChild: _buildDeudaDetails(tasa, plazo, inversion, estructuraPreview),
                  secondChild: _buildSinDeudaMessage(),
                  crossFadeState: tieneDeuda ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                  duration: const Duration(milliseconds: 300),
                ),
                const SizedBox(height: 24),

                // === PREVIEW CARD ===
                if (estructuraPreview != null && sumaValida) _buildPreviewCard(estructuraPreview, config),
                const SizedBox(height: 24),

                // === BOTÓN GUARDAR ===
                _buildSaveButton(proveedor, sumaValida, tieneDeuda, tasa, plazo),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(double inversion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.account_balance, size: 28, color: Colors.purple.shade700),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estructura de Financiamiento',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Inversión Requerida: ${_formatCurrency(inversion)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWarningCard(ProveedorSimulador proveedor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              Text(
                'Cambiar financiamiento reinicia datos posteriores',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Modificar la estructura de capital borrará: Ingresos, Costos Variables, Costos Fijos y resultados previos.',
            style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => proveedor.reiniciarFinanciamiento(),
            icon: Icon(Icons.refresh, color: Colors.orange.shade700, size: 18),
            label: Text('Confirmar y reiniciar', style: TextStyle(color: Colors.orange.shade700)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange.shade700,
              side: BorderSide(color: Colors.orange.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.purple.shade700, size: 22),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple.shade800)),
      ],
    );
  }

  Widget _buildPctBar(double propio, double deuda, bool valido) {
    final total = propio + deuda;
    final pPropio = total > 0 ? propio / total : 0.0;
    final pDeuda = total > 0 ? deuda / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Capital Propio', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
            Text('${propio.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pPropio,
            minHeight: 8,
            backgroundColor: Colors.red.shade100,
            valueColor: AlwaysStoppedAnimation(Colors.green.shade600),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Financiamiento', style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
            Text('${deuda.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pDeuda,
            minHeight: 8,
            backgroundColor: Colors.green.shade100,
            valueColor: AlwaysStoppedAnimation(Colors.red.shade600),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              valido ? Icons.check_circle : Icons.error,
              color: valido ? Colors.green : Colors.red,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              valido ? 'Suma = 100% ✓' : 'Suma = ${total.toStringAsFixed(1)}% (debe ser 100%)',
              style: TextStyle(
                color: valido ? Colors.green.shade700 : Colors.red.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeudaDetails(double tasa, int plazo, double inversion, EstructuraCapital? preview) {
    final tieneDeuda = (double.tryParse(_pctDeudaCtrl.text) ?? 0) > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Condiciones del Crédito Bancario', Icons.business),
        const SizedBox(height: 12),
        Text(
          'Complete los datos del préstamo para calcular la amortización (Sistema Francés).',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            // Tasa Interés Anual
            Expanded(
              child: TextFormField(
                controller: _tasaInteresCtrl,
                focusNode: _tasaFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_plazoFocus),
                decoration: const InputDecoration(
                  labelText: 'Tasa de Interés Anual (%) *',
                  hintText: 'Ej: 12.5',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.percent),
                  helperText: 'Tasa nominal anual del banco',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                validator: (v) {
                  if (!tieneDeuda) return null;
                  if (v == null || v.isEmpty) return 'Requerido si hay deuda';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0 || n > 100) return '0.01-100%';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            // Plazo en Meses
            Expanded(
              child: TextFormField(
                controller: _plazoMesesCtrl,
                focusNode: _plazoFocus,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Plazo del Crédito (meses) *',
                  hintText: 'Ej: 24, 36, 60',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_month),
                  helperText: 'Duración del préstamo',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (!tieneDeuda) return null;
                  if (v == null || v.isEmpty) return 'Requerido si hay deuda';
                  final n = int.tryParse(v);
                  if (n == null || n <= 0 || n > 360) return '1-360 meses';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (preview != null && preview.tieneDeuda) ...[
          _buildDeudaPreview(preview),
        ],
      ],
    );
  }

  Widget _buildDeudaPreview(EstructuraCapital estructura) {
    // final tabla = estructura.resumenPorPeriodos(
    //   estructura.inversionRequerida > 0 ? 3 : 1,
    //   10,
    // );
    
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
              Icon(Icons.preview, color: Colors.purple.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Preview del Crédito (Sistema Francés)',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade800, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PreviewRow(label: 'Monto Préstamo', value: _formatCurrency(estructura.montoPrestamo), highlight: true),
          _PreviewRow(label: 'Aporte Capital Propio', value: _formatCurrency(estructura.aportePropio)),
          _PreviewRow(label: 'Tasa Anual', value: '${estructura.tasaInteresAnual?.toStringAsFixed(2)}%'),
          _PreviewRow(label: 'Plazo', value: '${estructura.plazoMeses} meses'),
          _PreviewRow(label: 'Cuota Mensual', value: _formatCurrency(estructura.cuotaMensual), highlight: true),
          _PreviewRow(label: 'Cuota por Periodo (3m)', value: _formatCurrency(estructura.cuotaMensual * 3)),
          const Divider(height: 16),
          _PreviewRow(
            label: 'Total Intereses (vida préstamo)', 
            value: _formatCurrency(estructura.generarTablaAmortizacion().fold(0.0, (s, a) => s + a.interes)),
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSinDeudaMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade400),
          const SizedBox(height: 12),
          Text(
            'Proyecto 100% Capital Propio',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade800),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay cuotas bancarias, ni intereses, ni amortización de capital. '
            'El flujo de caja libre será mayor, pero el aporte inicial es el 100% de la inversión.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(EstructuraCapital estructura, ConfiguracionTemporal? config) {
    final mesesPeriodo = config?.mesesPorPeriodo ?? 3;
    final totalPeriodos = config?.totalPeriodos ?? 10;
    final resumenPeriodos = estructura.resumenPorPeriodos(mesesPeriodo, totalPeriodos);

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
              Icon(Icons.table_chart, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Resumen de Amortización por Periodos del Proyecto',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(Colors.blue.shade100),
              columns: const [
                DataColumn(label: Text('Periodo')),
                DataColumn(label: Text('Cuotas Totales'), numeric: true),
                DataColumn(label: Text('Interés (P&G)'), numeric: true),
                DataColumn(label: Text('Capital (Flujo)'), numeric: true),
                DataColumn(label: Text('Saldo Final'), numeric: true),
              ],
              rows: resumenPeriodos.map((p) => DataRow(cells: [
                DataCell(Text('${p.periodo}')),
                DataCell(Text(_formatCurrency(p.totalCuotas))),
                DataCell(Text(_formatCurrency(p.totalInteres))),
                DataCell(Text(_formatCurrency(p.totalCapital))),
                DataCell(Text(_formatCurrency(p.saldoFinal))),
              ])).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nota: Interés va en Estado de Resultados (no flujo). Capital va en Flujo de Caja (salida). '
            'Saldo final del último periodo productivo se liquida en el Motor FEN.',
            style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(ProveedorSimulador proveedor, bool sumaValida, bool tieneDeuda, double tasa, int plazo) {
    final puedeGuardar = sumaValida && (!tieneDeuda || (tasa > 0 && plazo > 0));

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        icon: Icon(proveedor.estructuraCapital != null ? Icons.update : Icons.save, size: 22),
        label: Text(
          proveedor.estructuraCapital != null ? 'Actualizar Financiamiento' : 'Guardar y Continuar',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.purple.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: puedeGuardar && !proveedor.estaCargando
            ? () => _guardar(proveedor, tieneDeuda, tasa, plazo)
            : null,
      ),
    );
  }

  void _onPctPropioChanged(String value, double pctDeudaActual) {
    if (_actualizandoPropio) return;
    _actualizandoPropio = true;
    final n = double.tryParse(value) ?? 0;
    if (n >= 0 && n <= 100) {
      _pctDeudaCtrl.text = (100 - n).toStringAsFixed(1);
    }
    _actualizandoPropio = false;
    setState(() {}); // Trigger preview update
  }

  void _onPctDeudaChanged(String value, double pctPropioActual) {
    if (_actualizandoDeuda) return;
    _actualizandoDeuda = true;
    final n = double.tryParse(value) ?? 0;
    if (n >= 0 && n <= 100) {
      _pctPropioCtrl.text = (100 - n).toStringAsFixed(1);
    }
    _actualizandoDeuda = false;
    setState(() {}); // Trigger preview update
  }

  void _guardar(ProveedorSimulador proveedor, bool tieneDeuda, double tasa, int plazo) {
    if (_formKey.currentState?.validate() != true) return;

    final pctPropio = double.parse(_pctPropioCtrl.text);
    final pctDeuda = double.parse(_pctDeudaCtrl.text);
    final inversion = proveedor.inversionRequerida.total;

    final estructura = EstructuraCapital(
      pctPropio: pctPropio,
      pctDeuda: pctDeuda,
      tasaInteresAnual: tieneDeuda ? tasa : null,
      plazoMeses: tieneDeuda ? plazo : null,
      inversionRequerida: inversion,
    );

    proveedor.configurarFinanciamiento(estructura);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tieneDeuda 
              ? 'Financiamiento guardado: ${pctPropio.toStringAsFixed(1)}% Propio / ${pctDeuda.toStringAsFixed(1)}% Deuda (Cuota: ${_formatCurrency(estructura.cuotaMensual)}/mes)'
              : 'Financiamiento guardado: 100% Capital Propio',
        ),
        backgroundColor: Colors.green,
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

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _PreviewRow({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: highlight ? Colors.purple.shade800 : null,
            ),
          ),
        ],
      ),
    );
  }
}