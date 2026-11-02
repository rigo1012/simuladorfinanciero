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
}
