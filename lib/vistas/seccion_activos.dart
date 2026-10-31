import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controladores/proveedor_simulador.dart';
import '../modelos/activo.dart';

/// Widget para la sección de **Activos** (Inversión Requerida).
/// 
/// Permite al usuario agregar/eliminar activos dinámicamente.
/// Cada activo tiene: Nombre, Unidades necesarias, Costo unitario.
/// El costo total por fila NO se muestra; solo se muestra la sumatoria
/// final como "Inversión Requerida".
class SeccionActivos extends StatefulWidget {
  const SeccionActivos({super.key});

  @override
  State<SeccionActivos> createState() => _SeccionActivosState();
}

class _SeccionActivosState extends State<SeccionActivos> {
  // Generador de IDs únicos simples
  int _nextId = 1;

  @override
  Widget build(BuildContext context) {
    return Consumer<ProveedorSimulador>(
      builder: (context, proveedor, _) {
        final inversion = proveedor.inversionRequerida;
        final activos = inversion.activos;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado con total - responsive
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 500) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Activos del Sistema de Riego',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _buildTotalChip(inversion.total),
                    ],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Activos del Sistema de Riego',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    _buildTotalChip(inversion.total),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Lista de activos
            if (activos.isEmpty)
              _buildEmptyState(context, proveedor)
            else
              _buildActivosList(context, proveedor, activos),

            const SizedBox(height: 16),

            // Botón agregar activo
            _buildAddButton(context, proveedor),
          ],
        );
      },
    );
  }

  /// Chip que muestra la Inversión Requerida (suma oculta de costos totales)
  Widget _buildTotalChip(double total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_money, color: Colors.green.shade700, size: 20),
          const SizedBox(width: 8),
          Text(
            'Inversión Requerida: ${_formatCurrency(total)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
        ],
      ),
    );
  }

  /// Estado vacío cuando no hay activos
  Widget _buildEmptyState(BuildContext context, ProveedorSimulador proveedor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No hay activos registrados',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Agregue los componentes del sistema de riego\n(bomba, tuberías, automatización, terreno, etc.)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  /// Lista de activos con tarjetas editables
  Widget _buildActivosList(BuildContext context, ProveedorSimulador proveedor, List<Activo> activos) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activos.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final activo = activos[index];
        return _ActivoCard(
          key: ValueKey(activo.id),
          activo: activo,
          index: index + 1,
          onUpdate: (updated) => proveedor.actualizarActivo(updated),
          onDelete: () => proveedor.eliminarActivo(activo.id),
        );
      },
    );
  }

  /// Botón flotante para agregar nuevo activo
  Widget _buildAddButton(BuildContext context, ProveedorSimulador proveedor) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.add, size: 22),
        label: const Text('Agregar Activo', style: TextStyle(fontSize: 16)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: Colors.green.shade400, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          foregroundColor: Colors.green.shade700,
        ),
        onPressed: () => _showAddActivoDialog(context, proveedor),
      ),
    );
  }

  /// Diálogo para agregar nuevo activo
  Future<void> _showAddActivoDialog(BuildContext context, ProveedorSimulador proveedor) async {
    final nombreCtrl = TextEditingController();
    final unidadesCtrl = TextEditingController(text: '1');
    final costoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo Activo'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Activo *',
                    hintText: 'Ej: Bomba centrífuga, Tubería PVC, Terreno',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: unidadesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Unidades Necesarias *',
                    hintText: 'Ej: 1, 2, 500',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[\d,]+$'))],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    final n = int.tryParse(v.replaceAll(',', ''));
                    if (n == null || n < 1) return 'Mínimo 1';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: costoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Costo Unitario *',
                    hintText: 'Ej: 800,000',
                    border: OutlineInputBorder(),
                    prefixText: '\$ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[\d,.]+$'))],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    final n = double.tryParse(v.replaceAll(',', ''));
                    if (n == null || n <= 0) return 'Debe ser > 0';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              final nuevo = Activo(
                id: 'act_${DateTime.now().millisecondsSinceEpoch}_$_nextId',
                nombre: nombreCtrl.text.trim(),
                unidades: int.parse(unidadesCtrl.text.replaceAll(',', '')),
                costoUnitario: double.parse(costoCtrl.text.replaceAll(',', '')),
              );
              _nextId++;
              proveedor.agregarActivo(nuevo);
              Navigator.pop(ctx);
            },
            child: const Text('Agregar'),
          ),
        ],
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

/// Tarjeta individual de un activo (editable inline)
class _ActivoCard extends StatefulWidget {
  final Activo activo;
  final int index;
  final ValueChanged<Activo> onUpdate;
  final VoidCallback onDelete;

  const _ActivoCard({
    super.key,
    required this.activo,
    required this.index,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_ActivoCard> createState() => _ActivoCardState();
}

class _ActivoCardState extends State<_ActivoCard> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _unidadesCtrl;
  late final TextEditingController _costoCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _editando = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.activo.nombre);
    _unidadesCtrl = TextEditingController(text: widget.activo.unidades.toString());
    _costoCtrl = TextEditingController(text: widget.activo.costoUnitario.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _unidadesCtrl.dispose();
    _costoCtrl.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() => _editando = !_editando);
    if (!_editando) _guardar();
  }

  void _guardar() {
    if (_formKey.currentState?.validate() != true) {
      setState(() => _editando = true);
      return;
    }
    final updated = widget.activo.copyWith(
      nombre: _nombreCtrl.text.trim(),
      unidades: int.parse(_unidadesCtrl.text.replaceAll(',', '')),
      costoUnitario: double.parse(_costoCtrl.text.replaceAll(',', '')),
    );
    widget.onUpdate(updated);
  }

  @override
  Widget build(BuildContext context) {
    final activo = widget.activo;
    final costoTotal = activo.costoTotal;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila superior: # + Nombre + Acciones
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.green.shade100,
                  child: Text(
                    '${widget.index}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _editando
                      ? TextFormField(
                          controller: _nombreCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                        )
                      : Text(
                          activo.nombre,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                const SizedBox(width: 8),
                // Botones de acción
                if (_editando) ...[
                  IconButton(
                    tooltip: 'Guardar',
                    icon: Icon(Icons.check, color: Colors.green.shade700),
                    onPressed: _toggleEdit,
                  ),
                  IconButton(
                    tooltip: 'Cancelar',
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                    onPressed: () {
                      setState(() {
                        _editando = false;
                        _nombreCtrl.text = activo.nombre;
                        _unidadesCtrl.text = activo.unidades.toString();
                        _costoCtrl.text = activo.costoUnitario.toStringAsFixed(2);
                      });
                    },
                  ),
                ] else ...[
                  IconButton(
                    tooltip: 'Editar',
                    icon: Icon(Icons.edit_outlined, color: Colors.blue.shade600),
                    onPressed: () => setState(() => _editando = true),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    icon: Icon(Icons.delete_outline, color: Colors.red.shade600),
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // Campos: Unidades | Costo Unitario (en modo edición)
            // En modo vista: muestra solo labels discretos
            if (_editando) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _unidadesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Unidades',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[\d,]+$'))],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Req.';
                        final n = int.tryParse(v.replaceAll(',', ''));
                        if (n == null || n < 1) return '≥1';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Costo Unitario',
                        isDense: true,
                        border: OutlineInputBorder(),
                        prefixText: '\$ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[\d,.]+$'))],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Req.';
                        final n = double.tryParse(v.replaceAll(',', ''));
                        if (n == null || n <= 0) return '>0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Modo vista: muestra resumen discreto (SIN costo total)
              Row(
                children: [
                  _InfoChip(
                    label: 'Unidades',
                    value: '${activo.unidades}',
                    icon: Icons.format_list_numbered,
                  ),
                  const SizedBox(width: 12),
                  _InfoChip(
                    label: 'Costo Unit.',
                    value: _formatCurrency(activo.costoUnitario),
                    icon: Icons.attach_money,
                  ),
                  const Spacer(),
                  // Indicador sutil de que hay costo total calculado internamente
                  Tooltip(
                    message: 'Costo total calculado internamente: ${_formatCurrency(costoTotal)}',
                    child: Icon(
                      Icons.visibility_off_outlined,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Activo'),
        content: Text('¿Eliminar "${widget.activo.nombre}"?'),
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
}

/// Chip informativo compacto para modo vista
class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoChip({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}