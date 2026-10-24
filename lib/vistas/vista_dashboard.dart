import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controladores/proveedor_simulador.dart';

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
        ],
      ),
    );
  }
}