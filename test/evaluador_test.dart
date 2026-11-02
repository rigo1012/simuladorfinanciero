import 'package:flutter_test/flutter_test.dart';
import 'package:simuladorfinanciero/modelos/configuracion_temporal.dart';
import 'package:simuladorfinanciero/servicios/evaluador_financiero.dart';
import 'package:simuladorfinanciero/servicios/motor_fen.dart';

/// Construye un [ResultadoMotorFEN] de prueba a partir de los flujos
/// posteriores a la inversión inicial (periodos 1..N).
ResultadoMotorFEN _motorDePrueba({
  required ConfiguracionTemporal config,
  required double trema,
  required List<double> flujosOperativos,
  double inversion = 1000000.0,
}) {
  final flujos = <FlujoPeriodo>[
    FlujoPeriodo(
      periodo: 0,
      mesInicio: 0,
      mesFin: 0,
      ingreso: 0,
      costoVariable: 0,
      costoFijo: 0,
      interes: 0,
      amortizacionCapital: 0,
      inversionInicial: inversion,
    ),
  ];

  for (var i = 0; i < flujosOperativos.length; i++) {
    final valor = flujosOperativos[i];
    flujos.add(FlujoPeriodo(
      periodo: i + 1,
      mesInicio: i * config.mesesPorPeriodo + 1,
      mesFin: (i + 1) * config.mesesPorPeriodo,
      ingreso: valor,
      costoVariable: 0,
      costoFijo: 0,
      interes: 0,
      amortizacionCapital: 0,
    ));
  }

  return ResultadoMotorFEN(
    flujos: flujos,
    config: config,
    estructura: null,
    inversionRequerida: inversion,
    aportePropio: inversion,
    montoPrestamo: 0,
    valorResidualPct: 0,
    trema: trema,
    horizontePeriodos: flujosOperativos.length,
  );
}

void main() {
  group('Conversión de TREMA anual a tasa por periodo', () {
    test('Periodos de 6 meses: VPN y TIR anual efectiva', () {
      const config = ConfiguracionTemporal(
        mesesPorPeriodo: 6,
        anosProyeccion: 3,
        cosechasPorAnio: 1,
      ); // 6 periodos

      final motor = _motorDePrueba(
        config: config,
        trema: 0.10, // 10% anual
        flujosOperativos: [350000, 350000, 350000, 350000, 350000, 450000],
      );

      // Tasa equivalente del periodo: (1.10)^(6/12) - 1
      expect(motor.tasaPeriodo, closeTo(0.0488088, 1e-6));

      final evaluacion = EvaluadorFinanciero.evaluar(motor);

      expect(evaluacion.vpn, closeTo(858411, 200));
      expect(evaluacion.tir, isNotNull);
      expect(evaluacion.tir, closeTo(62.5, 0.3)); // TIR anual efectiva en %
      expect(evaluacion.veredicto, 'VIABLE');
    });

    test('Periodos de 3 meses: VPN con TREMA anual', () {
      const config = ConfiguracionTemporal(
        mesesPorPeriodo: 3,
        anosProyeccion: 5,
        cosechasPorAnio: 1,
      ); // 20 periodos

      final motor = _motorDePrueba(
        config: config,
        trema: 0.12, // 12% anual
        flujosOperativos: List<double>.filled(20, 60000),
      );

      final evaluacion = EvaluadorFinanciero.evaluar(motor);

      expect(evaluacion.vpn, closeTo(-96841, 200));
    });
  });

  group('B/C real y payback fraccionario', () {
    ResultadoMotorFEN motorConCostos({
      required double trema,
      required List<double> ingresos,
      required double costoVariable,
      required double costoFijo,
      double interes = 0,
      double inversion = 1000,
    }) {
      final config = ConfiguracionTemporal(
        mesesPorPeriodo: 12,
        anosProyeccion: ingresos.length,
        cosechasPorAnio: 1,
      );
      final flujos = <FlujoPeriodo>[
        FlujoPeriodo(
          periodo: 0,
          mesInicio: 0,
          mesFin: 0,
          ingreso: 0,
          costoVariable: 0,
          costoFijo: 0,
          interes: 0,
          amortizacionCapital: 0,
          inversionInicial: inversion,
        ),
      ];
      for (var i = 0; i < ingresos.length; i++) {
        flujos.add(FlujoPeriodo(
          periodo: i + 1,
          mesInicio: i * 12 + 1,
          mesFin: (i + 1) * 12,
          ingreso: ingresos[i],
          costoVariable: costoVariable,
          costoFijo: costoFijo,
          interes: interes,
          amortizacionCapital: 0,
        ));
      }
      return ResultadoMotorFEN(
        flujos: flujos,
        config: config,
        estructura: null,
        inversionRequerida: inversion,
        aportePropio: inversion,
        montoPrestamo: 0,
        valorResidualPct: 0,
        trema: trema,
        horizontePeriodos: ingresos.length,
      );
    }

    test('B/C calculado a mano sin financiamiento', () {
      final motor = motorConCostos(
        trema: 0.10,
        ingresos: [600],
        costoVariable: 0,
        costoFijo: 100,
      );

      final evaluacion = EvaluadorFinanciero.evaluar(motor);

      // B/C = (600/1.1) / (1000 + 100/1.1) = 545.4545 / 1090.9091 = 0.5
      expect(evaluacion.beneficioCosto, closeTo(0.5, 1e-9));
      expect(evaluacion.beneficioCostoOperativo, closeTo(0.5, 1e-9));
    });

    test('B/C con financiamiento incluye intereses en costos', () {
      final motor = motorConCostos(
        trema: 0.10,
        ingresos: [600],
        costoVariable: 0,
        costoFijo: 100,
        interes: 100,
      );

      final evaluacion = EvaluadorFinanciero.evaluar(motor);

      // B/C con financiamiento: 545.4545 / (1000 + 200/1.1) = 0.46154
      expect(evaluacion.beneficioCosto, closeTo(0.46154, 1e-4));
      // B/C operativo excluye intereses: 0.5
      expect(evaluacion.beneficioCostoOperativo, closeTo(0.5, 1e-9));
    });

    test('Payback fraccionario en años', () {
      final motor = motorConCostos(
        trema: 0.0,
        ingresos: [600, 600],
        costoVariable: 0,
        costoFijo: 0,
      );

      final evaluacion = EvaluadorFinanciero.evaluar(motor);

      expect(evaluacion.paybackPeriodos, equals(2));
      // 1 periodo completo + 400/600 del segundo = 1.6667 años
      expect(evaluacion.kpis['payback_anios'] as double, closeTo(1.6667, 1e-4));
      expect(evaluacion.kpis['payback_descontado_anios'] as double, closeTo(1.6667, 1e-4));
    });
  });
}
