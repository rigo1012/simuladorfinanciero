// This is a basic Flutter widget test for SimuladorFinanciero.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:simuladorfinanciero/main.dart';
import 'package:simuladorfinanciero/controladores/proveedor_simulador.dart';

void main() {
  testWidgets('SimuladorApp builds and shows form', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ProveedorSimulador()),
        ],
        child: const SimuladorApp(),
      ),
    );

    // Verify the app title appears
    expect(find.text('Configuración del Sistema de Riego'), findsOneWidget);

    // Verify assets section exists
    expect(find.text('Activos del Sistema de Riego'), findsOneWidget);
    expect(find.text('Agregar Activo'), findsOneWidget);
  });
}