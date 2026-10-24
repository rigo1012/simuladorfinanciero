import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../controladores/proveedor_simulador.dart';
import '../modelos/costo_fijo.dart';

/// Sección para Costos Fijos por Periodo.
/// 
/// Lista simple de items por periodo (sueldos admin, rentas, seguros, etc.).
/// Cada item: Nombre | Monto por Periodo | Toggle "Aplicar Inflación".
/// Inflación opcional por item (default: false).
class SeccionCostosFijos extends StatefulWidget {
  const SeccionCostosFijos({super.key});

  @override
  State<SeccionCostosFijos> createState() => _SeccionCostosFijosState();
}

class _SeccionCostosFijosState extends State<SeccionCostosFijos> {
  final _inflacionGlobalCtrl = TextEditingController(text: '5.0');

  @override
  void dispose() {
    _inflacionGlobalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProveedorSimulador>(
      builder: (context, proveedor, _) {
        // Validar prerrequisitos
        if (!proveedor.estaConfigurado) {
          return _buildPrerequisitoFaltante('Configuración Temporal (Paso 0)');
        }
        if (proveedor.inversionRequerida.activos.isEmpty) {
          return _buildPrerequisitoFaltante('Activos e Inversión (Paso 1)');
        }
        if (proveedor.estructuraCapital == null) {
          return _buildPrerequisitoFaltante('Estructura de Financiamiento (Paso 2)');
        }
        if (!proveedor.ingresosCompletos) {
          return _buildPrerequisitoFaltante('Ingresos Estimados (Paso 3)');
        }
        if (!proveedor.costosVariablesCompletos) {
          return _buildPrerequisitoFaltante('Costos Variables (Paso 4)');
        }

        final config = proveedor.configTemporal;
        final totalPeriodos = config.totalPeriodos;
        final mesesPorPeriodo = config.mesesPorPeriodo;
        
        final costosFijos = proveedor.costosFijos;
        final mapaCostos = {for (var c in costosFijos) c.periodo: c};
        
        final inflacionGlobal = double.tryParse(_inflacionGlobalCtrl.text) ?? 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(totalPeriodos),
            const SizedBox(height: 16),

            // Inflación global de referencia
            _buildInflacionReference(inflacionGlobal, proveedor),
            const SizedBox(height: 16),

            // Lista de periodos con items
            _buildPeriodosList(proveedor, totalPeriodos, mesesPorPeriodo, inflacionGlobal, mapaCostos),
            const SizedBox(height: 16),

            // Resumen totales
            if (costosFijos.isNotEmpty) _buildResumenTotales(proveedor, totalPeriodos, mesesPorPeriodo, inflacionGlobal, mapaCostos),
            const SizedBox(height: 16),

            // Botones de acción
            _buildActionButtons(proveedor, totalPeriodos),
          ],
        );
      },
    );
  }

  Widget _buildPrerequisitoFaltante(String paso) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.hourglass_empty, size: 64, color: Colors.orange.shade300),
          const SizedBox(height: 16),
          Text(
            'Paso previo requerido',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete primero: $paso',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int totalPeriodos) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.receipt_long, size: 28, color: Colors.indigo.shade700),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Costos Fijos por Periodo',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '$totalPeriodos periodos  •  Montos planos por periodo',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              Text(
                'Ej: Sueldos admin, renta, seguros, servicios. Inflación opcional por item.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInflacionReference(double inflacion, ProveedorSimulador proveedor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.indigo.shade700),
              const SizedBox(width: 12),
              Text(
                'Inflación de Referencia (para items con toggle activado)',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade800, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _inflacionGlobalCtrl,
            decoration: const InputDecoration(
              labelText: 'Inflación Anual % Referencia',
              hintText: 'Ej: 5.0',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.trending_up),
              suffixText: '%',
              helperText: 'Se usa solo en items donde "Aplicar Inflación" = SÍ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          if (proveedor.estaConfigurado) ...[
            Text('Factores de referencia por periodo:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.indigo.shade700)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: List.generate(proveedor.configTemporal.totalPeriodos, (i) {
                final periodo = i + 1;
                final factor = periodo <= 1 ? 1.0 : math.pow(1 + inflacion / 100, (proveedor.configTemporal.mesesPorPeriodo / 12) * (periodo - 1));
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Text(
                    'P$periodo: ×${factor.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.indigo.shade700),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodosList(ProveedorSimulador proveedor, int totalPeriodos, int mesesPorPeriodo, double inflacion, Map<int, CostoFijoPeriodo> mapaCostos) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalPeriodos,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final periodo = index + 1;
        final costoPeriodo = mapaCostos[periodo];
        final items = costoPeriodo?.items ?? [];
        final totalBase = items.fold<double>(0, (s, i) => s + i.monto);
        final totalConInf = costoPeriodo?.totalConInflacion ?? totalBase;
        final factor = periodo <= 1 ? 1.0 : math.pow(1 + inflacion / 100, (mesesPorPeriodo / 12) * (periodo - 1));

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.indigo.shade100,
              child: Text('P$periodo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo.shade800)),
            ),
            title: Text('Periodo $periodo', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.indigo.shade800)),
            subtitle: Text(
              items.isEmpty 
                  ? 'Sin costos fijos definidos'
                  : '${items.length} item(s)  •  Base: ${_formatCurrency(totalBase)}  •  c/Inflación: ${_formatCurrency(totalConInf)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: items.isNotEmpty
                ? Chip(
                    label: Text('×${factor.toStringAsFixed(4)}', style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.indigo.shade100,
                    labelStyle: TextStyle(color: Colors.indigo.shade800),
                  )
                : null,
            children: [
              // Lista de items
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(child: Text('No hay costos fijos. Agregue uno nuevo.', style: TextStyle(color: Colors.grey.shade500))),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final costoConInf = item.costoConInflacion(periodo, mesesPorPeriodo, inflacion);
                    return _buildItemRow(item, periodo, mesesPorPeriodo, inflacion, costoConInf);
                  },
                ),
              // Botón agregar item
              Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar Costo Fijo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo.shade700,
                    side: BorderSide(color: Colors.indigo.shade400),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showAddItemDialog(proveedor, periodo),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemRow(ItemCostoFijo item, int periodo, int mesesPorPeriodo, double inflacion, double costoConInf) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: item.aplicarInflacion ? Colors.indigo.shade100 : Colors.green.shade100,
        child: Icon(
          item.aplicarInflacion ? Icons.trending_up : Icons.remove_circle_outline,
          size: 16,
          color: item.aplicarInflacion ? Colors.indigo.shade800 : Colors.green.shade800,
        ),
      ),
      title: Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        'Base: ${_formatCurrency(item.monto)}/periodo  ${item.aplicarInflacion ? '• Con inflación: ' + _formatCurrency(costoConInf) : ''}',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatCurrency(costoConInf),
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) {
              if (value == 'edit') {
                _showEditItemDialog(item, periodo);
              } else if (value == 'delete') {
                _confirmarEliminar(item, periodo);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Editar')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAddItemDialog(ProveedorSimulador proveedor, int periodo) async {
    final nombreCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    bool aplicarInflacion = false;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nuevo Costo Fijo'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre del Costo', border: OutlineInputBorder(), hintText: 'Ej: Sueldo gerente, Renta bodega, Seguro'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: montoCtrl,
                    decoration: const InputDecoration(labelText: 'Monto por Periodo', prefixText: '\$ ', border: OutlineInputBorder(), hintText: 'Ej: 50000'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'Debe ser > 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Aplicar Inflación'),
                    subtitle: Text(
                      'Si SÍ, el monto crecerá con la inflación de referencia cada periodo',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    value: aplicarInflacion,
                    onChanged: (v) => setDialogState(() => aplicarInflacion = v),
                    activeColor: Colors.indigo,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final nuevo = ItemCostoFijo(
                  id: 'cf_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}',
                  nombre: nombreCtrl.text.trim(),
                  monto: double.parse(montoCtrl.text),
                  aplicarInflacion: aplicarInflacion,
                );
                proveedor.agregarItemCostoFijo(periodo, nuevo);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Costo fijo agregado al Periodo $periodo'), backgroundColor: Colors.green),
                );
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditItemDialog(ItemCostoFijo item, int periodo) {
    final nombreCtrl = TextEditingController(text: item.nombre);
    final montoCtrl = TextEditingController(text: item.monto.toStringAsFixed(2));
    bool aplicarInflacion = item.aplicarInflacion;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Editar Costo Fijo'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre del Costo', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: montoCtrl,
                    decoration: const InputDecoration(labelText: 'Monto por Periodo', prefixText: '\$ ', border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'Debe ser > 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Aplicar Inflación'),
                    value: aplicarInflacion,
                    onChanged: (v) => setDialogState(() => aplicarInflacion = v),
                    activeColor: Colors.indigo,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final actualizado = item.copyWith(
                  nombre: nombreCtrl.text.trim(),
                  monto: double.parse(montoCtrl.text),
                  aplicarInflacion: aplicarInflacion,
                );
                // Provider necesita método actualizar - por ahora eliminar y agregar
                final prov = context.read<ProveedorSimulador>();
                prov.eliminarItemCostoFijo(periodo, item.id);
                prov.agregarItemCostoFijo(periodo, actualizado);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Costo fijo actualizado'), backgroundColor: Colors.blue),
                );
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarEliminar(ItemCostoFijo item, int periodo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Costo Fijo'),
        content: Text('¿Eliminar "${item.nombre}" del Periodo $periodo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      context.read<ProveedorSimulador>().eliminarItemCostoFijo(periodo, item.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Costo fijo eliminado'), backgroundColor: Colors.orange),
      );
    }
  }

  Widget _buildResumenTotales(ProveedorSimulador proveedor, int totalPeriodos, int mesesPorPeriodo, double inflacion, Map<int, CostoFijoPeriodo> mapaCostos) {
    double granTotalBase = 0;
    double granTotalConInf = 0;
    for (int p = 1; p <= totalPeriodos; p++) {
      final cp = mapaCostos[p];
      if (cp != null) {
        granTotalBase += cp.totalBase;
        granTotalConInf += cp.totalConInflacion;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize, color: Colors.indigo.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Resumen Costos Fijos Totales (Todos los Periodos)',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade800, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatChip(label: 'Total Base', value: _formatCurrency(granTotalBase), icon: Icons.receipt, color: Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _StatChip(label: 'Total c/Inflación', value: _formatCurrency(granTotalConInf), icon: Icons.trending_up, color: Colors.indigo)),
              const SizedBox(width: 12),
              Expanded(child: _StatChip(label: 'Promedio/Periodo', value: _formatCurrency(granTotalConInf / totalPeriodos), icon: Icons.analytics, color: Colors.green)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ProveedorSimulador proveedor, int totalPeriodos) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.clear_all, size: 20),
            label: const Text('Limpiar Todo'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.red.shade400, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              foregroundColor: Colors.red.shade700,
            ),
            onPressed: () => _confirmarLimpiar(proveedor),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmarLimpiar(ProveedorSimulador proveedor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Limpiar todos los Costos Fijos?'),
        content: const Text('Se eliminarán todos los items de todos los periodos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, limpiar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      proveedor.limpiarCostosFijos();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Costos Fijos limpiados'), backgroundColor: Colors.orange),
      );
    }
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}