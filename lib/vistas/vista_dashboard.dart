import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controladores/proveedor_simulador.dart';
import 'diseno_escritorio.dart';

class VistaDashboard extends StatelessWidget {
  const VistaDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Historial de Simulaciones', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 20),
          Expanded(
            flex: 3,
            child: Consumer<ProveedorSimulador>(
              builder: (context, proveedor, child) {
                if (proveedor.estaCargandoHistorial) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (proveedor.historialInversiones.isEmpty) {
                  return const Center(child: Text('No hay simulaciones registradas en la base de datos.'));
                }

                // Aislamiento del desplazamiento para evitar colapsos visuales
                return SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('ID')),
                          DataColumn(label: Text('Inversión Inicial')),
                          DataColumn(label: Text('Tasa (%)')),
                          DataColumn(label: Text('Años')),
                        ],
                        rows: proveedor.historialInversiones.map((fila) {
                          // Compensación visual de la tasa decimal a porcentaje
                          final tasaPorcentaje = (fila['tasa_descuento'] * 100).toStringAsFixed(2);

                          return DataRow(
                            cells: [
                              DataCell(Text(fila['id'].toString())),
                              DataCell(Text('\$${fila['monto'].toStringAsFixed(2)}')),
                              DataCell(Text('$tasaPorcentaje%')),
                              DataCell(Text(fila['horizonte_anios'].toString())),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          const Text('Proyectos guardados', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Expanded(
            flex: 2,
            child: Consumer<ProveedorSimulador>(
              builder: (context, proveedor, child) {
                final proyectos = proveedor.proyectosGuardados;
                if (proyectos.isEmpty) {
                  return const Center(child: Text('No hay proyectos guardados.'));
                }
                return ListView.separated(
                  itemCount: proyectos.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final proyecto = proyectos[index];
                    final id = (proyecto['id'] as num).toInt();
                    final nombre = (proyecto['nombre'] ?? '').toString();
                    final fecha = (proyecto['creado_en'] ?? '').toString();
                    return ListTile(
                      leading: const Icon(Icons.folder_outlined, color: Colors.blue),
                      title: Text(nombre),
                      subtitle: Text(fecha),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => _abrirProyecto(context, proveedor, id),
                            child: const Text('Abrir'),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _eliminarProyecto(context, proveedor, id, nombre),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirProyecto(
    BuildContext context,
    ProveedorSimulador proveedor,
    int id,
  ) async {
    final json = await proveedor.cargarProyectoJsonPorId(id);
    if (!context.mounted) return;
    if (json == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró el proyecto'), backgroundColor: Colors.orange),
      );
      return;
    }

    final nav = Navigator.of(context);
    await proveedor.cargarProyectoCompleto(json);
    if (!context.mounted) return;
    final error = proveedor.error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }

    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DisenoEscritorio()),
      (route) => false,
    );
  }

  Future<void> _eliminarProyecto(
    BuildContext context,
    ProveedorSimulador proveedor,
    int id,
    String nombre,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar proyecto'),
        content: Text('¿Eliminar el proyecto "$nombre"?'),
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
      await proveedor.eliminarProyectoGuardado(id);
    }
  }
}
