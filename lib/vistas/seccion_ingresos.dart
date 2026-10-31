import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../controladores/proveedor_simulador.dart';
import '../modelos/ingreso_periodo.dart';

/// Sección para ingresar Ingresos Estimados por periodo.
/// 
/// El número de periodos (N) viene de la Configuración Temporal (Fase 0).
/// Para cada periodo 1..N, el usuario ingresa:
/// - Precio unitario
/// - Demanda (cantidad)
/// - Ingreso = Precio × Demanda (calculado automáticamente, no editable)
class SeccionIngresos extends StatefulWidget {
  const SeccionIngresos({super.key});

  @override
  State<SeccionIngresos> createState() => _SeccionIngresosState();
}

class _SeccionIngresosState extends State<SeccionIngresos> {
  /// Cantidad de periodos que se dibujan actualmente (paginación visual).
  int _periodosVisibles = 1;

  @override
  Widget build(BuildContext context) {
    return Consumer<ProveedorSimulador>(
      builder: (context, proveedor, _) {
        final config = proveedor.configTemporal;
        final totalPeriodos = config?.totalPeriodos ?? 0;
        final ingresos = proveedor.ingresos;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con resumen
            _buildHeader(totalPeriodos, ingresos.length),
            const SizedBox(height: 16),

            // Tabla de ingresos
            _buildIngresosTable(proveedor, totalPeriodos, ingresos),
            const SizedBox(height: 16),

            // Resumen totales
            if (ingresos.isNotEmpty) _buildTotalesCard(ingresos),
            const SizedBox(height: 16),

            // Botón llenar rápido / limpiar
            _buildActionButtons(proveedor, totalPeriodos),
          ],
        );
      },
    );
  }

  Widget _buildHeader(int totalPeriodos, int completados) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.trending_up, size: 28, color: Colors.teal.shade700),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ingresos Estimados por Periodo',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Total de periodos: $totalPeriodos  •  Completados: $completados/$totalPeriodos',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              Text(
                'Ingreso = Precio × Demanda  (se calcula automáticamente)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIngresosTable(ProveedorSimulador proveedor, int totalPeriodos, List<IngresoPeriodo> ingresos) {
    // Crear mapa para acceso rápido
    final mapaIngresos = {for (var i in ingresos) i.periodo: i};

    // Paginación visual: solo se dibujan los periodos ya revelados
    final periodosVisibles = totalPeriodos == 0
        ? 0
        : _periodosVisibles.clamp(1, totalPeriodos);
    final puedeAgregar = periodosVisibles < totalPeriodos;

    return Column(
      children: [
        // Encabezado tabla
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.teal.shade100,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              SizedBox(width: 80, child: Text('PERÍODO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              SizedBox(width: 140, child: Text('PRECIO UNITARIO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
              SizedBox(width: 140, child: Text('DEMANDA (UNIDADES)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
              SizedBox(width: 160, child: Text('INGRESO CALCULADO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
              SizedBox(width: 60, child: Text('ACCIONES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
            ],
          ),
        ),
        // Filas visibles
        _buildPeriodosRows(proveedor, periodosVisibles, mapaIngresos),
        // Botón para revelar el siguiente periodo
        if (puedeAgregar) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => setState(() => _periodosVisibles++),
            icon: Icon(Icons.add_circle_outline, size: 18, color: Colors.teal.shade700),
            label: Text(
              'Agregar Periodo ${periodosVisibles + 1}',
              style: TextStyle(color: Colors.teal.shade700),
            ),
          ),
        ] else ...[
          const SizedBox.shrink(),
        ],
        // Borde inferior
        Container(
          height: 1,
          color: Colors.grey.shade300,
        ),
      ],
    );
  }

  Widget _buildPeriodosRows(ProveedorSimulador proveedor, int count, Map<int, IngresoPeriodo> mapaIngresos) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
      itemBuilder: (context, index) {
        final periodo = index + 1;
        final ingreso = mapaIngresos[periodo];
        final tieneDatos = ingreso != null;
        
        return _IngresoRow(
          periodo: periodo,
          precioInicial: tieneDatos ? ingreso.precio : null,
          demandaInicial: tieneDatos ? ingreso.demanda : null,
          onSave: (precio, demanda) => proveedor.actualizarIngreso(
            IngresoPeriodo(periodo: periodo, precio: precio, demanda: demanda),
          ),
          onDelete: () => proveedor.eliminarIngreso(periodo),
        );
      },
    );
  }

  Widget _buildTotalesCard(List<IngresoPeriodo> ingresos) {
    final totalIngresos = ingresos.fold<double>(0, (sum, i) => sum + i.ingreso);
    final promedioPrecio = ingresos.isNotEmpty 
        ? ingresos.fold<double>(0, (sum, i) => sum + i.precio) / ingresos.length 
        : 0.0;
    final totalDemanda = ingresos.fold<double>(0, (sum, i) => sum + i.demanda);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize, color: Colors.teal.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Resumen de Ingresos Proyectados',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatChip(label: 'Total Ingresos', value: _formatCurrency(totalIngresos), icon: Icons.attach_money, color: Colors.teal)),
              const SizedBox(width: 12),
              Expanded(child: _StatChip(label: 'Promedio Precio', value: _formatCurrency(promedioPrecio), icon: Icons.price_change, color: Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _StatChip(label: 'Total Demanda', value: _formatNumber(totalDemanda), icon: Icons.inventory, color: Colors.green)),
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
            icon: const Icon(Icons.auto_fix_high, size: 20),
            label: const Text('Llenar con Patrón'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.teal.shade400, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              foregroundColor: Colors.teal.shade700,
            ),
            onPressed: () => _showPatronDialog(proveedor, totalPeriodos),
          ),
        ),
        const SizedBox(width: 12),
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

  Future<void> _showPatronDialog(ProveedorSimulador proveedor, int totalPeriodos) async {
    final precioBaseCtrl = TextEditingController(text: '10');
    final demandaBaseCtrl = TextEditingController(text: '6000');
    final crecimientoPrecioCtrl = TextEditingController(text: '5');
    final crecimientoDemandaCtrl = TextEditingController(text: '3');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Llenar Ingresos con Patrón de Crecimiento'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Se generarán $totalPeriodos periodos con crecimiento compuesto anual.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: precioBaseCtrl,
                decoration: const InputDecoration(labelText: 'Precio Base Periodo 1', prefixText: '\$ ', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: demandaBaseCtrl,
                decoration: const InputDecoration(labelText: 'Demanda Base Periodo 1', suffixText: ' unid.', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: crecimientoPrecioCtrl,
                decoration: const InputDecoration(labelText: 'Crecimiento Precio % por Periodo', suffixText: '%', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: crecimientoDemandaCtrl,
                decoration: const InputDecoration(labelText: 'Crecimiento Demanda % por Periodo', suffixText: '%', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final precioBase = double.tryParse(precioBaseCtrl.text) ?? 0;
              final demandaBase = double.tryParse(demandaBaseCtrl.text) ?? 0;
              final crecPrecio = (double.tryParse(crecimientoPrecioCtrl.text) ?? 0) / 100;
              final crecDemanda = (double.tryParse(crecimientoDemandaCtrl.text) ?? 0) / 100;

              if (precioBase <= 0 || demandaBase <= 0) return;

              for (int p = 1; p <= totalPeriodos; p++) {
                final precio = precioBase * (p == 1 ? 1 : math.pow(1 + crecPrecio, p - 1));
                final demanda = demandaBase * (p == 1 ? 1 : math.pow(1 + crecDemanda, p - 1));
                proveedor.actualizarIngreso(IngresoPeriodo(
                  periodo: p,
                  precio: precio.toDouble(),
                  demanda: demanda.toDouble(),
                ));
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Ingresos generados para $totalPeriodos periodos'), backgroundColor: Colors.green),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Generar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarLimpiar(ProveedorSimulador proveedor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Limpiar todos los ingresos?'),
        content: const Text('Se eliminarán los datos de Precio y Demanda de todos los periodos.'),
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
      proveedor.limpiarIngresos();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresos limpiados'), backgroundColor: Colors.orange),
      );
    }
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  String _formatNumber(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}

class _IngresoRow extends StatefulWidget {
  final int periodo;
  final double? precioInicial;
  final double? demandaInicial;
  final Function(double precio, double demanda) onSave;
  final VoidCallback onDelete;

  const _IngresoRow({
    required this.periodo,
    this.precioInicial,
    this.demandaInicial,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_IngresoRow> createState() => _IngresoRowState();
}

class _IngresoRowState extends State<_IngresoRow> {
  late final TextEditingController _precioCtrl;
  late final TextEditingController _demandaCtrl;
  bool _editando = false;

  @override
  void initState() {
    super.initState();
    _precioCtrl = TextEditingController(text: widget.precioInicial?.toStringAsFixed(2) ?? '');
    _demandaCtrl = TextEditingController(text: widget.demandaInicial?.toStringAsFixed(0) ?? '');
  }

  @override
  void dispose() {
    _precioCtrl.dispose();
    _demandaCtrl.dispose();
    super.dispose();
  }

  double get _ingresoCalculado {
    final precio = double.tryParse(_precioCtrl.text) ?? 0;
    final demanda = double.tryParse(_demandaCtrl.text) ?? 0;
    return precio * demanda;
  }

  void _toggleEdit() {
    setState(() => _editando = !_editando);
    if (!_editando) _guardar();
  }

  void _guardar() {
    final precio = double.tryParse(_precioCtrl.text);
    final demanda = double.tryParse(_demandaCtrl.text);
    if (precio != null && demanda != null && precio > 0 && demanda > 0) {
      widget.onSave(precio, demanda);
    } else if (_editando) {
      setState(() => _editando = true); // Keep editing if invalid
    }
  }

  @override
  Widget build(BuildContext context) {
    final tieneDatos = widget.precioInicial != null;
    final ingreso = _ingresoCalculado;

    return Container(
      color: _editando 
          ? Colors.teal.withValues(alpha: 0.15) 
          : (tieneDatos ? Colors.teal.withValues(alpha: 0.05) : Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Período
          SizedBox(
            width: 80,
            child: Text(
              'P${widget.periodo}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: _editando ? Colors.teal.shade800 : (tieneDatos ? Colors.teal.shade700 : Colors.grey.shade500),
              ),
            ),
          ),
          // Precio
          SizedBox(
            width: 140,
            child: _editando
                ? TextFormField(
                    controller: _precioCtrl,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), prefixText: '\$ '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    onFieldSubmitted: (_) => _guardar(),
                  )
                : Text(
                    tieneDatos ? '\$${_formatCurrency(widget.precioInicial ?? 0)}' : '—',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tieneDatos ? Colors.black87 : Colors.grey.shade400),
                  ),
          ),
          // Demanda
          SizedBox(
            width: 140,
            child: _editando
                ? TextFormField(
                    controller: _demandaCtrl,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onFieldSubmitted: (_) => _guardar(),
                  )
                : Text(
                    tieneDatos ? _formatNumber(widget.demandaInicial ?? 0) : '—',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tieneDatos ? Colors.black87 : Colors.grey.shade400),
                  ),
          ),
          // Ingreso (solo lectura, calculado)
          SizedBox(
            width: 160,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: _editando ? Colors.teal.shade100 : (tieneDatos ? Colors.green.shade50 : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _editando ? Colors.teal.shade300 : (tieneDatos ? Colors.green.shade200 : Colors.grey.shade200)),
              ),
              child: Text(
                tieneDatos || _editando ? '\$${_formatCurrency(ingreso)}' : '—',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: _editando ? Colors.teal.shade800 : (tieneDatos ? Colors.green.shade800 : Colors.grey.shade400),
                ),
              ),
            ),
          ),
          // Acciones
          SizedBox(
            width: 60,
            child: _editando
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Guardar',
                        icon: Icon(Icons.check, color: Colors.green.shade700, size: 20),
                        onPressed: _toggleEdit,
                      ),
                      IconButton(
                        tooltip: 'Cancelar',
                        icon: Icon(Icons.close, color: Colors.grey.shade600, size: 20),
                        onPressed: () => setState(() {
                          _editando = false;
                          _precioCtrl.text = widget.precioInicial?.toStringAsFixed(2) ?? '';
                          _demandaCtrl.text = widget.demandaInicial?.toStringAsFixed(0) ?? '';
                        }),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (tieneDatos)
                        IconButton(
                          tooltip: 'Editar',
                          icon: Icon(Icons.edit_outlined, color: Colors.teal.shade600, size: 20),
                          onPressed: () => setState(() => _editando = true),
                        ),
                      if (tieneDatos)
                        IconButton(
                          tooltip: 'Eliminar',
                          icon: Icon(Icons.delete_outline, color: Colors.red.shade600, size: 20),
                          onPressed: () => _confirmarEliminar(context),
                        )
                      else
                        IconButton(
                          tooltip: 'Agregar',
                          icon: Icon(Icons.add_circle_outline, color: Colors.teal.shade600, size: 20),
                          onPressed: () => setState(() => _editando = true),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarEliminar(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Ingreso'),
        content: Text('¿Eliminar datos del Periodo ${widget.periodo}?'),
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
    if (confirm == true) widget.onDelete();
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  String _formatNumber(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
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