import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:simuladorfinanciero/main.dart';
import 'package:simuladorfinanciero/controladores/proveedor_simulador.dart';
import 'package:simuladorfinanciero/modelos/configuracion_temporal.dart';

ProveedorSimulador _proveedor = ProveedorSimulador();

void main() {
  // Inicializar sqflite_common_ffi para tests
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    // Configurar temporal antes de cada test para evitar null check error
    final config = ConfiguracionTemporal(
      mesesPorPeriodo: 3,
      anosProyeccion: 5,
      cosechasPorAnio: 2,
    );
    _proveedor.configurarTemporal(config);
  });

  testWidgets('SimuladorApp builds and shows temporal config first',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => _proveedor),
        ],
        child: const SimuladorApp(),
      ),
    );

    // Con la configuración ya establecida, el encabezado cambia de título.
    expect(find.text('Reconfigurar Horizonte Temporal'), findsOneWidget);

    // Verificar que los campos de configuración temporal existen por su etiqueta.
    expect(find.text('Duración del Periodo (meses) *'), findsOneWidget);
    expect(find.text('Años de Proyección Fiscal *'), findsOneWidget);
    expect(find.text('Cosechas / Ciclos por Año *'), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);

    // Verificar botón de guardado en estado ya configurado.
    expect(find.text('Actualizar Configuración'), findsOneWidget);
  });
}