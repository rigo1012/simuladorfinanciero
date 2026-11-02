import 'package:flutter_test/flutter_test.dart';
import 'package:simuladorfinanciero/modelos/ingreso_periodo.dart';

void main() {
  group('IngresoPeriodo con otros ingresos', () {
    test('El ingreso suma precio × demanda + otros ingresos', () {
      final ingreso = IngresoPeriodo(
        periodo: 1,
        precio: 12.5,
        demanda: 800,
        otrosIngresos: 150,
      );

      expect(ingreso.ingreso, closeTo(12.5 * 800 + 150, 1e-9));
    });

    test('otrosIngresos es 0 por defecto', () {
      final ingreso = IngresoPeriodo(periodo: 1, precio: 10, demanda: 100);

      expect(ingreso.otrosIngresos, equals(0));
      expect(ingreso.ingreso, closeTo(1000, 1e-9));
    });

    test('toMap incluye otros_ingresos', () {
      final ingreso = IngresoPeriodo(
        periodo: 2,
        precio: 5,
        demanda: 200,
        otrosIngresos: 75,
      );

      final map = ingreso.toMap();
      expect(map['otros_ingresos'], equals(75));
      expect(map['ingreso'], closeTo(5 * 200 + 75, 1e-9));
    });

    test('fromMap es compatible con mapas sin otros_ingresos', () {
      final antiguo = IngresoPeriodo.fromMap({
        'periodo': 3,
        'precio': 8.0,
        'demanda': 500.0,
        'ingreso': 4000.0,
      });

      expect(antiguo.otrosIngresos, equals(0));
      expect(antiguo.ingreso, closeTo(4000, 1e-9));
    });

    test('fromMap lee otros_ingresos y usa casteo numérico seguro', () {
      final nuevo = IngresoPeriodo.fromMap({
        'periodo': 1,
        'precio': 10,
        'demanda': 100,
        'otros_ingresos': 25,
      });

      expect(nuevo.precio, equals(10.0));
      expect(nuevo.demanda, equals(100.0));
      expect(nuevo.otrosIngresos, equals(25.0));
    });
  });
}
