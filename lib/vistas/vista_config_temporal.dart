import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controladores/proveedor_simulador.dart';
import '../modelos/configuracion_temporal.dart';

/// Paso 0 obligatorio: Configuración Temporal del Proyecto.
/// 
/// Define la granularidad matemática (meses por periodo) y el horizonte
/// de evaluación (años, rotación de cultivos). Sin esto, el resto
/// del simulador no puede calcular inflación fraccionada ni amortización.
class VistaConfigTemporal extends StatefulWidget {
  const VistaConfigTemporal({super.key});

  @override
  State<VistaConfigTemporal> createState() => _VistaConfigTemporalState();
}

class _VistaConfigTemporalState extends State<VistaConfigTemporal> {
  final _formKey = GlobalKey<FormState>();
  
  final _mesesCtrl = TextEditingController();
  final _anosCtrl = TextEditingController();
  final _cosechasCtrl = TextEditingController();
  
  final _mesesFocus = FocusNode();
  final _anosFocus = FocusNode();
  final _cosechasFocus = FocusNode();

  // Valores por defecto recomendados
  static const int _defaultMeses = 3;
  static const int _defaultAnos = 5;
  static const int _defaultCosechas = 2;

  @override
  void initState() {
    super.initState();
    _mesesCtrl.text = _defaultMeses.toString();
    _anosCtrl.text = _defaultAnos.toString();
    _cosechasCtrl.text = _defaultCosechas.toString();
  }

  @override
  void dispose() {
    _mesesCtrl.dispose();
    _anosCtrl.dispose();
    _cosechasCtrl.dispose();
    _mesesFocus.dispose();
    _anosFocus.dispose();
    _cosechasFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProveedorSimulador>(
      builder: (context, proveedor, _) {
        final yaConfigurado = proveedor.estaConfigurado;
        final config = yaConfigurado ? proveedor.configTemporal : null;

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(yaConfigurado, config),
                const SizedBox(height: 24),

                // Advertencia si ya configurado
                if (yaConfigurado) _buildWarningCard(proveedor),
                if (yaConfigurado) const SizedBox(height: 16),

                // Campos de configuración
                _buildMesesField(),
                const SizedBox(height: 20),
                _buildAnosField(),
                const SizedBox(height: 20),
                _buildCosechasField(),
                const SizedBox(height: 24),

                // Resumen calculado (preview)
                if (_formKey.currentState != null) _buildPreviewCard(),
                const SizedBox(height: 24),

                // Presets rápidos
                _buildPresets(),
                const SizedBox(height: 24),

                // Botón guardar
                _buildSaveButton(proveedor, yaConfigurado),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool yaConfigurado, ConfiguracionTemporal? config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.schedule, size: 28, color: Colors.blue.shade700),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    yaConfigurado ? 'Reconfigurar Horizonte Temporal' : 'Configuración Temporal Inicial',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Define la base matemática del simulador. Obligatorio antes de continuar.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (yaConfigurado && config != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Configuración actual: ${config.mesesPorPeriodo} meses/periodo • ${config.anosProyeccion} años • ${config.cosechasPorAnio} ciclos/año = ${config.totalPeriodos} periodos',
                    style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
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
                'Cambiar configuración reinicia datos',
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
            'Modificar la base temporal borrará: Activos, Ingresos, Costos Variables, Costos Fijos y Financiamiento. Los resultados previos se perderán.',
            style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _confirmarReinicio(proveedor),
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

  Future<void> _confirmarReinicio(ProveedorSimulador proveedor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Reiniciar configuración?'),
        content: const Text('Se perderán todos los datos ingresados (Activos, Ingresos, Costos, Financiamiento). ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Sí, reiniciar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      proveedor.reiniciarConfiguracionTemporal();
      _resetForm();
    }
  }

  void _resetForm() {
    _mesesCtrl.text = _defaultMeses.toString();
    _anosCtrl.text = _defaultAnos.toString();
    _cosechasCtrl.text = _defaultCosechas.toString();
    _formKey.currentState?.reset();
  }

  Widget _buildMesesField() {
    return TextFormField(
      controller: _mesesCtrl,
      focusNode: _mesesFocus,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_anosFocus),
      decoration: InputDecoration(
        labelText: 'Duración del Periodo (meses) *',
        hintText: 'Ej: 3 (trimestral), 4 (cuatrimestral), 6 (semestral)...',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.calendar_month),
        helperText: 'Libre según ciclo de cultivo. Rábano=2-3, Cilantro=1-2, Maíz=4-6',
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (v) {
        if (v == null || v.isEmpty) return 'Requerido';
        final n = int.tryParse(v);
        if (n == null || n < 1) return 'Debe ser ≥ 1';
        if (n > 60) return 'Máximo 60 meses (5 años)';
        return null;
      },
    );
  }

  Widget _buildAnosField() {
    return TextFormField(
      controller: _anosCtrl,
      focusNode: _anosFocus,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_cosechasFocus),
      decoration: InputDecoration(
        labelText: 'Años de Proyección Fiscal *',
        hintText: 'Ej: 3, 5, 7...',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.date_range),
        helperText: 'Horizonte de evaluación del proyecto. Estándar: 3-5 años para infraestructura.',
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (v) {
        if (v == null || v.isEmpty) return 'Requerido';
        final n = int.tryParse(v);
        if (n == null || n < 1) return 'Debe ser ≥ 1';
        if (n > 20) return 'Máximo 20 años';
        return null;
      },
    );
  }

  Widget _buildCosechasField() {
    return TextFormField(
      controller: _cosechasCtrl,
      focusNode: _cosechasFocus,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _guardar(context.read<ProveedorSimulador>()),
      decoration: InputDecoration(
        labelText: 'Cosechas / Ciclos por Año *',
        hintText: 'Ej: 1, 2, 3...',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.agriculture),
        helperText: 'Rotación de cultivos. Clima templado=2, Tropical=3, Invernadero=4+',
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (v) {
        if (v == null || v.isEmpty) return 'Requerido';
        final n = int.tryParse(v);
        if (n == null || n < 1) return 'Debe ser ≥ 1';
        if (n > 12) return 'Máximo 12 ciclos/año';
        return null;
      },
    );
  }

  Widget _buildPreviewCard() {
    final meses = int.tryParse(_mesesCtrl.text) ?? _defaultMeses;
    final anos = int.tryParse(_anosCtrl.text) ?? _defaultAnos;
    final cosechas = int.tryParse(_cosechasCtrl.text) ?? _defaultCosechas;
    
    final config = ConfiguracionTemporal(
      mesesPorPeriodo: meses,
      anosProyeccion: anos,
      cosechasPorAnio: cosechas,
    );
    
    final error = config.validar();
    final totalPeriodos = config.totalPeriodos;
    final totalMeses = config.totalMeses;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: error != null ? Colors.red.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: error != null ? Colors.red.shade200 : Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                error != null ? Icons.error_outline : Icons.preview,
                color: error != null ? Colors.red.shade700 : Colors.blue.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                error != null ? 'Error de configuración' : 'Resumen del Horizonte',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: error != null ? Colors.red.shade800 : Colors.blue.shade800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (error != null) ...[
            Text(error, style: TextStyle(color: Colors.red.shade700)),
          ] else ...[
            _PreviewRow(label: 'Meses por periodo', value: '$meses meses'),
            _PreviewRow(label: 'Años de proyección', value: '$anos años'),
            _PreviewRow(label: 'Cosechas por año', value: '$cosechas ciclos'),
            const Divider(height: 16),
            _PreviewRow(label: 'Total de periodos', value: '$totalPeriodos', bold: true),
            _PreviewRow(label: 'Total de meses', value: '$totalMeses meses'),
            _PreviewRow(label: 'Meses productivos/año', value: '${(12 / cosechas).round()} meses/ciclo × $cosechas = ${(12 / cosechas).round() * cosechas} meses'),
          ],
        ],
      ),
    );
  }

  Widget _buildPresets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Configuraciones rápidas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ConfiguracionesPredefinidas.comunes.map((preset) {
            return ActionChip(
              label: Text('${preset.mesesPorPeriodo}m/${preset.anosProyeccion}a/${preset.cosechasPorAnio}c (${preset.totalPeriodos}p)'),
              onPressed: () => _aplicarPreset(preset),
              backgroundColor: Colors.grey.shade100,
              side: BorderSide(color: Colors.grey.shade300),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _aplicarPreset(ConfiguracionTemporal preset) {
    setState(() {
      _mesesCtrl.text = preset.mesesPorPeriodo.toString();
      _anosCtrl.text = preset.anosProyeccion.toString();
      _cosechasCtrl.text = preset.cosechasPorAnio.toString();
    });
    _formKey.currentState?.validate(); // Trigger preview update
  }

  Widget _buildSaveButton(ProveedorSimulador proveedor, bool yaConfigurado) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        icon: Icon(yaConfigurado ? Icons.update : Icons.save, size: 22),
        label: Text(
          yaConfigurado ? 'Actualizar Configuración' : 'Guardar y Continuar',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _guardar(proveedor),
      ),
    );
  }

  void _guardar(ProveedorSimulador proveedor) {
    if (_formKey.currentState?.validate() != true) return;

    final config = ConfiguracionTemporal(
      mesesPorPeriodo: int.parse(_mesesCtrl.text),
      anosProyeccion: int.parse(_anosCtrl.text),
      cosechasPorAnio: int.parse(_cosechasCtrl.text),
    );

    final error = config.validar();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }

    proveedor.configurarTemporal(config);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Configuración guardada: ${config.totalPeriodos} periodos (${config.totalMeses} meses)'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _PreviewRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}