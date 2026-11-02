import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../controladores/proveedor_simulador.dart';
import '../modelos/ingreso_periodo.dart';
import 'ayuda_concepto.dart';

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
            _buildActionButtons(proveedor, totalPeriodos, config?.mesesPorPeriodo ?? 0),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ingreso = Precio × Demanda + otros ingresos  (se calcula automáticamente)',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                    ),
                  ),
                  const AyudaConcepto(termino: 'otros_ingresos'),
                ],
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
              SizedBox(width: 120, child: Text('PRECIO UNITARIO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
              SizedBox(width: 120, child: Text('DEMANDA (UNIDADES)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
              SizedBox(width: 150, child: Text('INGRESO CALCULADO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
              SizedBox(width: 96, child: Text('ACCIONES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
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
          otrosIngresosInicial: tieneDatos ? ingreso.otrosIngresos : 0,
          onSave: (precio, demanda) => proveedor.actualizarIngreso(
            IngresoPeriodo(
              periodo: periodo,
              precio: precio,
              demanda: demanda,
              otrosIngresos: tieneDatos ? ingreso.otrosIngresos : 0,
            ),
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

  Widget _buildActionButtons(ProveedorSimulador proveedor, int totalPeriodos, int mesesPorPeriodo) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.calculate_outlined, size: 20),
          label: const Text('Calculadora de Beneficios'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            side: BorderSide(color: Colors.blue.shade400, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            foregroundColor: Colors.blue.shade700,
          ),
          onPressed: () => _showCalculadoraBeneficios(proveedor, totalPeriodos, mesesPorPeriodo),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.auto_fix_high, size: 20),
          label: const Text('Llenar con Patrón'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            side: BorderSide(color: Colors.teal.shade400, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            foregroundColor: Colors.teal.shade700,
          ),
          onPressed: () => _showPatronDialog(proveedor, totalPeriodos),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.clear_all, size: 20),
          label: const Text('Limpiar Todo'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            side: BorderSide(color: Colors.red.shade400, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            foregroundColor: Colors.red.shade700,
          ),
          onPressed: () => _confirmarLimpiar(proveedor),
        ),
      ],
    );
  }

  Future<void> _showCalculadoraBeneficios(
    ProveedorSimulador proveedor,
    int totalPeriodos,
    int mesesPorPeriodo,
  ) async {
    final superficieCtrl = TextEditingController();
    final cultivoCtrl = TextEditingController();
    final rendSinCtrl = TextEditingController();
    final rendConCtrl = TextEditingController();
    final precioKgCtrl = TextEditingController();
    final ciclosAnioCtrl = TextEditingController();
    final ahorroAguaCtrl = TextEditingController();
    final costoAguaCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final superficie = double.tryParse(superficieCtrl.text);
          final rendSin = double.tryParse(rendSinCtrl.text);
          final rendCon = double.tryParse(rendConCtrl.text);
          final precioKg = double.tryParse(precioKgCtrl.text);
          final ciclosAnio = int.tryParse(ciclosAnioCtrl.text);
          final ahorroAgua = double.tryParse(ahorroAguaCtrl.text);
          final costoAgua = double.tryParse(costoAguaCtrl.text);

          final datosValidos = superficie != null &&
              superficie > 0 &&
              rendSin != null &&
              rendSin >= 0 &&
              rendCon != null &&
              rendCon > rendSin &&
              precioKg != null &&
              precioKg > 0 &&
              ciclosAnio != null &&
              ciclosAnio > 0 &&
              ahorroAgua != null &&
              ahorroAgua >= 0 &&
              costoAgua != null &&
              costoAgua >= 0;

          final kgPorCiclo = datosValidos ? ((rendCon ?? 0) - (rendSin ?? 0)) * (superficie ?? 0) : 0.0;
          final ciclosPorPeriodo = datosValidos && mesesPorPeriodo > 0
              ? (ciclosAnio ?? 0) * mesesPorPeriodo / 12.0
              : 0.0;
          final demandaPeriodo = kgPorCiclo * ciclosPorPeriodo;
          final ahorroPeriodo = datosValidos ? (ahorroAgua ?? 0) * ciclosPorPeriodo : 0.0;
          final otrosIngresosPeriodo = ahorroPeriodo * (costoAgua ?? 0);
          final ingresoPeriodo = demandaPeriodo * (precioKg ?? 0) + otrosIngresosPeriodo;

          return AlertDialog(
            title: const Row(
              children: [
                Expanded(child: Text('Calculadora de Beneficios')),
                AyudaConcepto(termino: 'calculadora_beneficios'),
              ],
            ),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Capture los datos del cultivo. No hay valores predeterminados.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: cultivoCtrl,
                        decoration: const InputDecoration(labelText: 'Cultivo *', hintText: 'Texto libre', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: superficieCtrl,
                              decoration: const InputDecoration(labelText: 'Superficie (m²) *', border: OutlineInputBorder()),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              onChanged: (_) => setDialogState(() {}),
                              validator: _validarPositivo,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: ciclosAnioCtrl,
                              decoration: const InputDecoration(labelText: 'Ciclos por año *', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (_) => setDialogState(() {}),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Requerido';
                                final n = int.tryParse(v);
                                if (n == null || n <= 0) return 'Debe ser > 0';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: rendSinCtrl,
                              decoration: const InputDecoration(labelText: 'Rendimiento SIN riego (kg/m²/ciclo) *', border: OutlineInputBorder()),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              onChanged: (_) => setDialogState(() {}),
                              validator: _validarNoNegativo,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: rendConCtrl,
                              decoration: const InputDecoration(labelText: 'Rendimiento CON riego (kg/m²/ciclo) *', border: OutlineInputBorder()),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              onChanged: (_) => setDialogState(() {}),
                              validator: (v) {
                                final base = _validarPositivo(v);
                                if (base != null) return base;
                                final sin = double.tryParse(rendSinCtrl.text);
                                final con = double.tryParse(v ?? '');
                                if (sin != null && con != null && con <= sin) {
                                  return 'Debe ser mayor que SIN riego';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: precioKgCtrl,
                        decoration: const InputDecoration(labelText: 'Precio por kg (\$) *', prefixText: '\$ ', border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        onChanged: (_) => setDialogState(() {}),
                        validator: _validarPositivo,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: ahorroAguaCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Ahorro de agua (m³/ciclo) *',
                                border: OutlineInputBorder(),
                                suffixIcon: AyudaConcepto(termino: 'ahorro_agua'),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              onChanged: (_) => setDialogState(() {}),
                              validator: _validarNoNegativo,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: costoAguaCtrl,
                              decoration: const InputDecoration(labelText: 'Costo del agua (\$/m³) *', prefixText: '\$ ', border: OutlineInputBorder()),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              onChanged: (_) => setDialogState(() {}),
                              validator: _validarNoNegativo,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Resumen previo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                            const SizedBox(height: 8),
                            _resumenFila('Cultivo', cultivoCtrl.text.trim().isEmpty ? '-' : cultivoCtrl.text.trim()),
                            _resumenFila('Kg incrementales por ciclo', _formatNumber(kgPorCiclo)),
                            _resumenFila('Ciclos por periodo', ciclosPorPeriodo.toStringAsFixed(4)),
                            _resumenFila('Demanda por periodo (kg)', _formatNumber(demandaPeriodo)),
                            _resumenFila('Venta por periodo', '\$${_formatCurrency(demandaPeriodo * (precioKg ?? 0))}'),
                            _resumenFila('Ahorro de agua por periodo (m³)', _formatNumber(ahorroPeriodo)),
                            _resumenFila('Ingreso por ahorro de agua', '\$${_formatCurrency(otrosIngresosPeriodo)}'),
                            const Divider(),
                            _resumenFila('Ingreso total por periodo', '\$${_formatCurrency(ingresoPeriodo)}'),
                            _resumenFila('Periodos a generar', '$totalPeriodos'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState?.validate() != true) return;
                  if (!datosValidos) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Complete todos los datos de la calculadora'), backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  for (int p = 1; p <= totalPeriodos; p++) {
                    proveedor.actualizarIngreso(IngresoPeriodo(
                      periodo: p,
                      precio: precioKg,
                      demanda: demandaPeriodo,
                      otrosIngresos: otrosIngresosPeriodo,
                    ));
                  }
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ingresos calculados para $totalPeriodos periodos'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: FilledButton.styleFrom(backgroundColor: Colors.blue.shade700),
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      ),
    );
  }

  String? _validarPositivo(String? valor) {
    if (valor == null || valor.isEmpty) return 'Requerido';
    final n = double.tryParse(valor);
    if (n == null || n <= 0) return 'Debe ser > 0';
    return null;
  }

  String? _validarNoNegativo(String? valor) {
    if (valor == null || valor.isEmpty) return 'Requerido';
    final n = double.tryParse(valor);
    if (n == null || n < 0) return 'Debe ser ≥ 0';
    return null;
  }

  Widget _resumenFila(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _showPatronDialog(ProveedorSimulador proveedor, int totalPeriodos) async {
    final precioBaseCtrl = TextEditingController();
    final demandaBaseCtrl = TextEditingController();
    final crecimientoPrecioCtrl = TextEditingController();
    final crecimientoDemandaCtrl = TextEditingController();

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
  final double otrosIngresosInicial;
  final Function(double precio, double demanda) onSave;
  final VoidCallback onDelete;

  const _IngresoRow({
    required this.periodo,
    this.precioInicial,
    this.demandaInicial,
    this.otrosIngresosInicial = 0,
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
    return precio * demanda + widget.otrosIngresosInicial;
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
            width: 120,
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
            width: 120,
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
            width: 150,
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
            width: 96,
            child: _editando
                ? Wrap(
                    spacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildActionIcon(
                        tooltip: 'Guardar',
                        icon: Icons.check,
                        color: Colors.green.shade700,
                        onPressed: _toggleEdit,
                      ),
                      _buildActionIcon(
                        tooltip: 'Cancelar',
                        icon: Icons.close,
                        color: Colors.grey.shade600,
                        onPressed: () => setState(() {
                          _editando = false;
                          _precioCtrl.text = widget.precioInicial?.toStringAsFixed(2) ?? '';
                          _demandaCtrl.text = widget.demandaInicial?.toStringAsFixed(0) ?? '';
                        }),
                      ),
                    ],
                  )
                : Wrap(
                    spacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      if (tieneDatos)
                        _buildActionIcon(
                          tooltip: 'Editar',
                          icon: Icons.edit_outlined,
                          color: Colors.teal.shade600,
                          onPressed: () => setState(() => _editando = true),
                        ),
                      if (tieneDatos)
                        _buildActionIcon(
                          tooltip: 'Eliminar',
                          icon: Icons.delete_outline,
                          color: Colors.red.shade600,
                          onPressed: () => _confirmarEliminar(context),
                        )
                      else
                        _buildActionIcon(
                          tooltip: 'Agregar',
                          icon: Icons.add_circle_outline,
                          color: Colors.teal.shade600,
                          onPressed: () => setState(() => _editando = true),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, color: color, size: 20),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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