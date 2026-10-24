import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'vista_formulario_inversion.dart';
import 'vista_dashboard.dart';
import 'vista_resultados.dart';
import '../controladores/proveedor_simulador.dart';

class DisenoEscritorio extends StatefulWidget {
  const DisenoEscritorio({super.key});

  @override
  State<DisenoEscritorio> createState() => _DisenoEscritorioState();
}

class _DisenoEscritorioState extends State<DisenoEscritorio> {
  int _indiceSeleccionado = 0;

  final List<Widget> _pantallas = [
    const VistaFormularioInversion(),
    const VistaDashboard(),
    const VistaResultados(),
  ];

  void _cambiarPestana(int indice) {
    if (indice == 1) {
      // Dispara la lectura a SQLite sin bloquear la animación visual de la pestaña
      context.read<ProveedorSimulador>().cargarHistorial();
    }
    if (indice == 2) {
      // Asegurar contexto para PDF en resultados
      context.read<ProveedorSimulador>().setContext(context);
    }
    
    setState(() {
      _indiceSeleccionado = indice;
    });
  }

  @override
  Widget build(BuildContext context) {
    final anchoPantalla = MediaQuery.of(context).size.width;
    final esEstrecha = anchoPantalla < 600;
    final esAncha = anchoPantalla >= 800;

    return Scaffold(
      body: Row(
        children: [
          if (!esEstrecha)
            NavigationRail(
              extended: esAncha,
              selectedIndex: _indiceSeleccionado,
              onDestinationSelected: _cambiarPestana,
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.attach_money), label: Text('Inversión')),
                NavigationRailDestination(icon: Icon(Icons.bar_chart), label: Text('Dashboard')),
                NavigationRailDestination(icon: Icon(Icons.assessment), label: Text('Resultados')),
              ],
            ),
          if (!esEstrecha) const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: _indiceSeleccionado,
              children: _pantallas,
            ),
          ),
        ],
      ),
      bottomNavigationBar: esEstrecha
          ? BottomNavigationBar(
              currentIndex: _indiceSeleccionado,
              onTap: _cambiarPestana,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: 'Inversión'),
                BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.assessment), label: 'Resultados'),
              ],
            )
          : null,
    );
  }
}