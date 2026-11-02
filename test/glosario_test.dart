import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simuladorfinanciero/nucleo/glosario.dart';
import 'package:simuladorfinanciero/vistas/ayuda_concepto.dart';

void main() {
  test('Todos los términos del glosario tienen definición y uso', () {
    expect(Glosario.terminos, isNotEmpty);

    const clavesRequeridas = [
      'trema', 'vpn', 'tir', 'beneficio_costo', 'payback_simple',
      'payback_descontado', 'ebitda', 'uai', 'isr', 'depreciacion',
      'vida_util', 'valor_residual', 'sistema_frances', 'amortizacion_capital',
      'interes', 'saldo_insoluto', 'inflacion', 'costos_variables',
      'costos_fijos', 'materia_prima', 'mano_obra', 'cargos_indirectos',
      'periodo', 'ciclos_por_anio', 'horizonte', 'tasa_periodo',
      'ahorro_agua', 'otros_ingresos', 'capital_propio', 'deuda',
    ];

    for (final clave in clavesRequeridas) {
      expect(Glosario.terminos.containsKey(clave), isTrue, reason: 'Falta el término $clave');
    }

    for (final entry in Glosario.terminos.entries) {
      final termino = entry.value;
      expect(termino.nombre.trim(), isNotEmpty, reason: '${entry.key}: nombre vacío');
      expect(termino.definicion.trim(), isNotEmpty, reason: '${entry.key}: definición vacía');
      expect(termino.comoSeUsa.trim(), isNotEmpty, reason: '${entry.key}: uso vacío');
      final formula = termino.formula;
      if (formula != null) {
        expect(formula.trim(), isNotEmpty, reason: '${entry.key}: fórmula vacía');
      }
    }
  });

  testWidgets('AyudaConcepto abre el diálogo con el contenido correcto', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: AyudaConcepto(termino: 'vpn')),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    expect(find.text('Valor Presente Neto (VPN)'), findsOneWidget);
    expect(find.text('Definición'), findsOneWidget);
    expect(find.text('Cómo se usa aquí'), findsOneWidget);
    expect(find.text('Fórmula'), findsOneWidget);
    expect(find.textContaining('Diferencia entre el valor presente'), findsOneWidget);

    await tester.tap(find.text('Cerrar').last);
    await tester.pumpAndSettle();
    expect(find.text('Definición'), findsNothing);
  });
}
