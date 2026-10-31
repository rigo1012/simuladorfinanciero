import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../controladores/proveedor_simulador.dart';
import '../modelos/costo_variable.dart';

/// Sección para Costos Variables por Periodo.
/// 
/// Tres subcategorías dinámicas (usuario agrega items):
/// 1. Materia Prima: Nombre | Cantidad Unitaria | Costo Unitario
/// 2. Mano de Obra: Operación | Costo Unitario por Operación
/// 3. Cargos Indirectos: Recurso | Cantidad | Costo Unitario
/// 
/// Inflación compuesta por periodo: costoPeriodoN = costoBase × (1+i)^(meses/12 × (N-1))
class SeccionCostosVariables extends StatefulWidget {
  const SeccionCostosVariables({super.key});

  @override
  State<SeccionCostosVariables> createState() => _SeccionCostosVariablesState();
}

class _SeccionCostosVariablesState extends State<SeccionCostosVariables> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Controllers para inflación
  final _inflacionCtrl = TextEditingController(text: '5.0');
  final _inflacionFocus = FocusNode();

  /// Cantidad de periodos que se dibujan actualmente (paginación visual).
  int _periodosVisibles = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inflacionCtrl.dispose();
    _inflacionFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProveedorSimulador>(
      builder: (context, proveedor, _) {
        final config = proveedor.configTemporal;
        final totalPeriodos = config?.totalPeriodos ?? 0;
        final mesesPorPeriodo = config?.mesesPorPeriodo ?? 0;
        
        // Obtener costos variables existentes
        final costosExistentes = proveedor.costosVariables;
        final mapaCostos = {for (var c in costosExistentes) c.periodo: c};

        // Inflación global
        final inflacion = double.tryParse(_inflacionCtrl.text) ?? 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(totalPeriodos, mesesPorPeriodo),
            const SizedBox(height: 16),

            // Inflación global
            _buildInflacionField(inflacion, proveedor),
            const SizedBox(height: 16),

            // Tabs para las 3 subcategorías
            _buildTabs(proveedor, totalPeriodos, mesesPorPeriodo, inflacion, mapaCostos),
            const SizedBox(height: 16),

            // Resumen por periodo (costos totales con inflación)
            _buildResumenPeriodos(proveedor, totalPeriodos, mesesPorPeriodo, inflacion, mapaCostos),
            const SizedBox(height: 16),

            // Botones de acción
            _buildActionButtons(proveedor, totalPeriodos),
          ],
        );
      },
    );
  }

  Widget _buildHeader(int totalPeriodos, int mesesPorPeriodo) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.deepOrange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.factory, size: 28, color: Colors.deepOrange.shade700),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Costos Variables por Periodo',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '$totalPeriodos periodos de ${mesesPorPeriodo} meses cada uno',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              Text(
                'Tres categorías: Materia Prima • Mano de Obra • Cargos Indirectos',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInflacionField(double inflacionActual, ProveedorSimulador proveedor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepOrange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepOrange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.percent, color: Colors.deepOrange.shade700),
              const SizedBox(width: 12),
              Text(
                'Inflación Anual Estimada',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange.shade800, fontSize: 16),
              ),
              const Spacer(),
              Text(
                '(Consultar BANXICO)',
                style: TextStyle(fontSize: 12, color: Colors.deepOrange.shade600, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _inflacionCtrl,
            focusNode: _inflacionFocus,
            decoration: const InputDecoration(
              labelText: 'Inflación Anual %',
              hintText: 'Ej: 5.0',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.trending_up),
              suffixText: '%',
              helperText: 'Se aplica compuesto: costo × (1+i)^(meses/12 × (periodo-1))',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            onChanged: (_) => setState(() {}), // Rebuild para actualizar preview
          ),
          const SizedBox(height: 8),
          // Preview del factor de inflación por periodo
          if (proveedor.estaConfigurado) ...[
            Text('Factores de inflación por periodo:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.deepOrange.shade700)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: List.generate(proveedor.configTemporal?.totalPeriodos ?? 0, (i) {
                final periodo = i + 1;
                final factor = periodo <= 1 ? 1.0 : math.pow(1 + inflacionActual / 100, ((proveedor.configTemporal?.mesesPorPeriodo ?? 0) / 12) * (periodo - 1));
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.deepOrange.shade200),
                  ),
                  child: Text(
                    'P$periodo: ×${factor.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.deepOrange.shade700),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabs(ProveedorSimulador proveedor, int totalPeriodos, int mesesPorPeriodo, double inflacion, Map<int, CostoVariablePeriodo> mapaCostos) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Colors.deepOrange.shade700,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.deepOrange.shade700,
          tabs: const [
            Tab(icon: Icon(Icons.grain), text: 'Materia Prima'),
            Tab(icon: Icon(Icons.engineering), text: 'Mano de Obra'),
            Tab(icon: Icon(Icons.local_gas_station), text: 'Cargos Indirectos'),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 450,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCategoriaTab(
                proveedor, totalPeriodos, mesesPorPeriodo, inflacion, mapaCostos,
                TipoCostoVariable.materiaPrima,
                'Materia Prima',
                'Nombre del insumo',
                'Cant. unitaria',
                'Costo unitario',
                Icons.grain,
              ),
              _buildCategoriaTab(
                proveedor, totalPeriodos, mesesPorPeriodo, inflacion, mapaCostos,
                TipoCostoVariable.manoObra,
                'Mano de Obra',
                'Nombre de la operación',
                'Costo por operación',
                '',
                Icons.engineering,
              ),
              _buildCategoriaTab(
                proveedor, totalPeriodos, mesesPorPeriodo, inflacion, mapaCostos,
                TipoCostoVariable.cargosIndirectos,
                'Cargos Indirectos',
                'Recurso',
                'Cantidad',
                'Costo unitario',
                Icons.local_gas_station,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriaTab(
    ProveedorSimulador proveedor,
    int totalPeriodos,
    int mesesPorPeriodo,
    double inflacion,
    Map<int, CostoVariablePeriodo> mapaCostos,
    TipoCostoVariable tipo,
    String titulo,
    String labelNombre,
    String labelCantidad,
    String labelCosto,
    IconData icon,
  ) {
    final periodosVisibles = totalPeriodos == 0
        ? 0
        : _periodosVisibles.clamp(1, totalPeriodos);
    final puedeAgregar = periodosVisibles < totalPeriodos;

    return ListView(
      children: [
        // Para cada periodo visible, mostrar items de esta categoría
        for (int p = 1; p <= periodosVisibles; p++) ...[
          _buildPeriodoCategoriaCard(
            proveedor, p, totalPeriodos, mesesPorPeriodo, inflacion, mapaCostos,
            tipo, titulo, labelNombre, labelCantidad, labelCosto, icon,
          ),
        ],
        // Botón para revelar el siguiente periodo
        if (puedeAgregar)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _periodosVisibles++),
                icon: Icon(Icons.add_circle_outline, size: 18, color: Colors.deepOrange.shade700),
                label: Text(
                  'Agregar Periodo ${periodosVisibles + 1}',
                  style: TextStyle(color: Colors.deepOrange.shade700),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPeriodoCategoriaCard(
    ProveedorSimulador proveedor,
    int periodo,
    int totalPeriodos,
    int mesesPorPeriodo,
    double inflacion,
    Map<int, CostoVariablePeriodo> mapaCostos,
    TipoCostoVariable tipo,
    String titulo,
    String labelNombre,
    String labelCantidad,
    String labelCosto,
    IconData icon,
  ) {
    final costoPeriodo = mapaCostos[periodo];
    final items = costoPeriodo?.items.where((i) => i.tipo == tipo).toList() ?? [];
    final subtotalBase = items.fold<double>(0, (s, i) => s + i.costoTotal);
    final factor = periodo <= 1 ? 1.0 : math.pow(1 + inflacion / 100, (mesesPorPeriodo / 12) * (periodo - 1));
    final subtotalConInflacion = subtotalBase * factor;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepOrange.shade100,
          child: Text('P$periodo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepOrange.shade800)),
        ),
        title: Row(
          children: [
            Icon(icon, size: 18, color: Colors.deepOrange.shade700),
            const SizedBox(width: 8),
            Text('$titulo', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.deepOrange.shade800)),
          ],
        ),
        subtitle: Text(
          items.isEmpty 
              ? 'Sin items agregados'
              : '${items.length} item(s)  •  Base: ${_formatCurrency(subtotalBase)}  •  Con inflación: ${_formatCurrency(subtotalConInflacion)}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: items.isNotEmpty
            ? Chip(
                label: Text('×${factor.toStringAsFixed(4)}', style: const TextStyle(fontSize: 11)),
                backgroundColor: Colors.deepOrange.shade100,
                labelStyle: TextStyle(color: Colors.deepOrange.shade800),
              )
            : null,
        children: [
          // Lista de items
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No hay items. Agregue uno nuevo.', style: TextStyle(color: Colors.grey.shade500)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildItemRow(item, tipo, labelNombre, labelCantidad, labelCosto);
              },
            ),
          // Botón agregar item
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text('Agregar $titulo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepOrange.shade700,
                side: BorderSide(color: Colors.deepOrange.shade400),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _showAddItemDialog(
                proveedor, periodo, tipo, titulo, labelNombre, labelCantidad, labelCosto, icon,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(ItemCostoVariable item, TipoCostoVariable tipo, String labelNombre, String labelCantidad, String labelCosto) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.deepOrange.shade100,
        child: Text('${item.costoTotal.toStringAsFixed(0)}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepOrange.shade800)),
      ),
      title: Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(_buildItemSubtitle(item, tipo, labelCantidad, labelCosto), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      trailing: Text(
        _formatCurrency(item.costoTotal),
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange.shade700),
      ),
      onTap: () => _showEditItemDialog(item, tipo, labelNombre, labelCantidad, labelCosto),
    );
  }

  String _buildItemSubtitle(ItemCostoVariable item, TipoCostoVariable tipo, String labelCantidad, String labelCosto) {
    switch (tipo) {
      case TipoCostoVariable.materiaPrima:
      case TipoCostoVariable.cargosIndirectos:
        return '$labelCantidad: ${item.cantidadUnitaria.toStringAsFixed(2)}  |  $labelCosto: ${_formatCurrency(item.costoUnitario)}';
      case TipoCostoVariable.manoObra:
        return '$labelCosto: ${_formatCurrency(item.costoPorOperacion)}';
    }
  }

  Future<void> _showAddItemDialog(
    ProveedorSimulador proveedor,
    int periodo,
    TipoCostoVariable tipo,
    String titulo,
    String labelNombre,
    String labelCantidad,
    String labelCosto,
    IconData icon,
  ) async {
    final nombreCtrl = TextEditingController();
    final cantidadCtrl = TextEditingController();
    final costoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [Icon(icon, color: Colors.deepOrange.shade700), const SizedBox(width: 8), Text('Nuevo $titulo')]),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombreCtrl,
                  decoration: InputDecoration(labelText: labelNombre, border: const OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                if (tipo != TipoCostoVariable.manoObra) ...[
                  TextFormField(
                    controller: cantidadCtrl,
                    decoration: InputDecoration(labelText: labelCantidad, border: const OutlineInputBorder()),
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
                ],
                TextFormField(
                  controller: costoCtrl,
                  decoration: InputDecoration(labelText: labelCosto, prefixText: '\$ ', border: const OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'Debe ser > 0';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              final nuevo = ItemCostoVariable(
                id: 'cv_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}',
                tipo: tipo,
                nombre: nombreCtrl.text.trim(),
                cantidadUnitaria: tipo != TipoCostoVariable.manoObra ? double.parse(cantidadCtrl.text) : 0,
                costoUnitario: tipo != TipoCostoVariable.manoObra ? double.parse(costoCtrl.text) : 0,
                costoPorOperacion: tipo == TipoCostoVariable.manoObra ? double.parse(costoCtrl.text) : 0,
              );
              proveedor.agregarItemCostoVariable(periodo, nuevo, proveedor.configTemporal?.mesesPorPeriodo ?? 1, double.tryParse(_inflacionCtrl.text) ?? 0.0);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$titulo agregado al Periodo $periodo'), backgroundColor: Colors.green),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _showEditItemDialog(ItemCostoVariable item, TipoCostoVariable tipo, String labelNombre, String labelCantidad, String labelCosto) {
    // Implementar similar a agregar pero con valores pre-cargados
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Edición de items: por implementar'), backgroundColor: Colors.blue),
    );
  }

  Widget _buildResumenPeriodos(ProveedorSimulador proveedor, int totalPeriodos, int mesesPorPeriodo, double inflacion, Map<int, CostoVariablePeriodo> mapaCostos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepOrange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepOrange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.table_chart, color: Colors.deepOrange.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Resumen Costos Variables por Periodo (con Inflación)',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange.shade800, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(Colors.deepOrange.shade100),
              columns: const [
                DataColumn(label: Text('Periodo')),
                DataColumn(label: Text('Materia Prima'), numeric: true),
                DataColumn(label: Text('Mano de Obra'), numeric: true),
                DataColumn(label: Text('Cargos Ind.'), numeric: true),
                DataColumn(label: Text('Total Base'), numeric: true),
                DataColumn(label: Text('Factor Inf.'), numeric: true),
                DataColumn(label: Text('Total c/Inf.'), numeric: true),
              ],
              rows: List.generate(totalPeriodos, (i) {
                final p = i + 1;
                final cp = mapaCostos[p];
                final mp = cp?.subtotalMateriaPrima ?? 0;
                final mo = cp?.subtotalManoObra ?? 0;
                final ci = cp?.subtotalCargosIndirectos ?? 0;
                final base = mp + mo + ci;
                final factor = p <= 1 ? 1.0 : math.pow(1 + inflacion / 100, (mesesPorPeriodo / 12) * (p - 1));
                final conInf = base * factor;
                return DataRow(cells: [
                  DataCell(Text('P$p', style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(_formatCurrency(mp))),
                  DataCell(Text(_formatCurrency(mo))),
                  DataCell(Text(_formatCurrency(ci))),
                  DataCell(Text(_formatCurrency(base))),
                  DataCell(Text('×${factor.toStringAsFixed(4)}')),
                  DataCell(Text(_formatCurrency(conInf), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange.shade800))),
                ]);
              }),
            ),
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
        title: const Text('¿Limpiar todos los Costos Variables?'),
        content: const Text('Se eliminarán todos los items de Materia Prima, Mano de Obra y Cargos Indirectos de todos los periodos.'),
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
      proveedor.limpiarCostosVariables();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Costos Variables limpiados'), backgroundColor: Colors.orange),
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