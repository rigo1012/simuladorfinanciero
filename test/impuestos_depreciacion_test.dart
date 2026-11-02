import 'package:flutter_test/flutter_test.dart';
import 'package:simuladorfinanciero/controladores/proveedor_simulador.dart';
import 'package:simuladorfinanciero/modelos/activo.dart';
import 'package:simuladorfinanciero/modelos/configuracion_temporal.dart';
import 'package:simuladorfinanciero/modelos/costo_fijo.dart';
import 'package:simuladorfinanciero/modelos/costo_variable.dart';
import 'package:simuladorfinanciero/modelos/estructura_capital.dart';
import 'package:simuladorfinanciero/modelos/ingreso_periodo.dart';
import 'package:simuladorfinanciero/servicios/evaluador_financiero.dart';
import 'package:simuladorfinanciero/servicios/motor_fen.dart';

/// Construye un proveedor con datos completos para probar el motor.
ProveedorSimulador _proveedorBase({
  required int mesesPorPeriodo,
  required int anosProyeccion,
  required double ingresoPorPeriodo,
  required double costoVariablePorPeriodo,
  required double costoFijoPorPeriodo,
  required List<Activo> activos,
}) {
  final proveedor = ProveedorSimulador();
  final config = ConfiguracionTemporal(
    mesesPorPeriodo: mesesPorPeriodo,
    anosProyeccion: anosProyeccion,
    cosechasPorAnio: 1,
  );
  proveedor.configurarTemporal(config);
  for (final activo in activos) {
    proveedor.agregarActivo(activo);
  }
  proveedor.configurarFinanciamiento(EstructuraCapital(
    pctPropio: 100,
    pctDeuda: 0,
    inversionRequerida: proveedor.inversionRequerida.total,
  ));
  for (var p = 1; p <= config.totalPeriodos; p++) {
    proveedor.actualizarIngreso(IngresoPeriodo(
      periodo: p,
      precio: ingresoPorPeriodo,
      demanda: 1,
    ));
    proveedor.agregarItemCostoVariable(
      p,
      ItemCostoVariable(
        id: 'cv_$p',
        tipo: TipoCostoVariable.materiaPrima,
        nombre: 'Insumo',
        cantidadUnitaria: costoVariablePorPeriodo,
        costoUnitario: 1,
      ),
      mesesPorPeriodo,
      0,
    );
    proveedor.agregarItemCostoFijo(
      p,
      ItemCostoFijo(id: 'cf_$p', nombre: 'Fijo', monto: costoFijoPorPeriodo),
    );
  }
  return proveedor;
}

void main() {
  group('ISR, depreciación y valor residual', () {
    test('ISR y depreciación lineal verificados a mano', () {
      final proveedor = _proveedorBase(
        mesesPorPeriodo: 6,
        anosProyeccion: 3,
        ingresoPorPeriodo: 500000,
        costoVariablePorPeriodo: 50000,
        costoFijoPorPeriodo: 100000,
        activos: [
          Activo(
            id: 'a1',
            nombre: 'Equipo',
            unidades: 1,
            costoUnitario: 1000000,
            depreciable: true,
            vidaUtilAnios: 2, // 2 años = 4 periodos de 6 meses
          ),
        ],
      );

      final motor = MotorFEN.calcular(
        proveedor: proveedor,
        tremaPct: 12,
        horizonteAnios: 3,
        valorResidualPct: 0,
        tasaImpuestoPct: 30,
      );

      // Depreciación = 1,000,000 / 4 periodos = 250,000 (solo P1..P4)
      // EBITDA = 500,000 - 50,000 - 100,000 = 350,000
      // ISR = (350,000 - 250,000) * 30% = 30,000
      // Flujo = 350,000 - 30,000 = 320,000
      for (var p = 1; p <= 4; p++) {
        expect(motor.flujos[p].depreciacion, closeTo(250000, 1), reason: 'Depreciación P$p');
        expect(motor.flujos[p].impuesto, closeTo(30000, 1), reason: 'ISR P$p');
        expect(motor.flujos[p].flujoCaja, closeTo(320000, 1), reason: 'Flujo P$p');
      }

      // Después de la vida útil no hay depreciación: ISR = 350,000 * 30% = 105,000
      for (var p = 5; p <= 6; p++) {
        expect(motor.flujos[p].depreciacion, equals(0), reason: 'Depreciación P$p');
        expect(motor.flujos[p].impuesto, closeTo(105000, 1), reason: 'ISR P$p');
        expect(motor.flujos[p].flujoCaja, closeTo(245000, 1), reason: 'Flujo P$p');
      }

      final evaluacion = EvaluadorFinanciero.evaluar(motor);
      expect(evaluacion.kpis['total_depreciacion'], closeTo(1000000, 1));
      expect(evaluacion.kpis['total_impuestos'], closeTo(330000, 1));
    });

    test('Valor residual: depreciables al % y no depreciables al 100%', () {
      final proveedor = _proveedorBase(
        mesesPorPeriodo: 6,
        anosProyeccion: 1, // 2 periodos
        ingresoPorPeriodo: 500000,
        costoVariablePorPeriodo: 50000,
        costoFijoPorPeriodo: 100000,
        activos: [
          Activo(
            id: 'equipo',
            nombre: 'Equipo',
            unidades: 1,
            costoUnitario: 1000000,
            depreciable: true,
            vidaUtilAnios: 10,
          ),
          Activo(
            id: 'terreno',
            nombre: 'Terreno',
            unidades: 1,
            costoUnitario: 500000,
            depreciable: false,
          ),
        ],
      );

      final motor = MotorFEN.calcular(
        proveedor: proveedor,
        tremaPct: 12,
        horizonteAnios: 1,
        valorResidualPct: 0.10,
        tasaImpuestoPct: 0,
      );

      // 1,000,000 * 10% + 500,000 * 100% = 600,000
      expect(motor.flujos.last.valorResidual, closeTo(600000, 1));
    });
  });

  group('Validación de parámetros obligatorios', () {
    ProveedorSimulador base({bool? depreciable = true, int? vida = 10}) {
      return _proveedorBase(
        mesesPorPeriodo: 6,
        anosProyeccion: 1,
        ingresoPorPeriodo: 500000,
        costoVariablePorPeriodo: 50000,
        costoFijoPorPeriodo: 100000,
        activos: [
          Activo(
            id: 'a1',
            nombre: 'Equipo',
            unidades: 1,
            costoUnitario: 1000000,
            depreciable: depreciable,
            vidaUtilAnios: vida,
          ),
        ],
      );
    }

    test('Falta tasa de impuesto: error y no calcula', () async {
      final proveedor = base();
      proveedor.setValorResidualPct(10);

      await proveedor.procesarSimulacionSimple(12, 1);

      expect(proveedor.ultimoResultado, isNull);
      expect(proveedor.error, contains('tasa de impuesto'));
    });

    test('Falta valor residual: error y no calcula', () async {
      final proveedor = base();
      proveedor.setTasaImpuestoPct(30);

      await proveedor.procesarSimulacionSimple(12, 1);

      expect(proveedor.ultimoResultado, isNull);
      expect(proveedor.error, contains('valor residual'));
    });

    test('Activo sin definir depreciación: error y no calcula', () async {
      final proveedor = base(depreciable: null);
      proveedor.setTasaImpuestoPct(30);
      proveedor.setValorResidualPct(10);

      await proveedor.procesarSimulacionSimple(12, 1);

      expect(proveedor.ultimoResultado, isNull);
      expect(proveedor.error, contains('depreciable'));
    });

    test('Activo depreciable sin vida útil: error y no calcula', () async {
      final proveedor = base(depreciable: true, vida: null);
      proveedor.setTasaImpuestoPct(30);
      proveedor.setValorResidualPct(10);

      await proveedor.procesarSimulacionSimple(12, 1);

      expect(proveedor.ultimoResultado, isNull);
      expect(proveedor.error, contains('vida útil'));
    });
  });
}
