// This is a basic Flutter widget test for SimuladorFinanciero.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:simuladorfinanciero/main.dart';
import 'package:simuladorfinanciero/controladores/proveedor_simulador.dart';

void main() {
  testWidgets('SimuladorApp builds and shows temporal config first', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ProveedorSimulador()),
        ],
        child: const SimuladorApp(),
      ),
    );

    // Verify the temporal config title appears (Paso 0)
    expect(find.text('Configuración Temporal Inicial'), findsOneWidget);
    
    // Verify form fields exist (meses, años, ciclos)
    expect(find.byType(TextFormField), findsNWidgets(3));
    
    // Verify save button exists
    expect(find.text('Guardar y Continuar'), findsOneWidget);
  });
}