import 'dart:math' as math;

/// Estructura de financiamiento del proyecto.
/// 
/// Define % Capital Propio vs % Deuda, y si hay deuda:
/// tasa de interés y plazo. Calcula cuota francesa y tabla de amortización.
class EstructuraCapital {
  final double pctPropio;           // 0-100
  final double pctDeuda;            // 100 - pctPropio
  final double? tasaInteresAnual;   // % anual (ej: 12.5)
  final int? plazoMeses;            // Meses del crédito
  final double inversionRequerida;  // Total de Activos

  EstructuraCapital({
    required this.pctPropio,
    required this.pctDeuda,
    this.tasaInteresAnual,
    this.plazoMeses,
    required this.inversionRequerida,
  });

  /// Monto del préstamo
  double get montoPrestamo => inversionRequerida * (pctDeuda / 100);

  /// Aporte de capital propio (flujo negativo en Periodo 0)
  double get aportePropio => inversionRequerida * (pctPropio / 100);

  /// Tasa mensual efectiva
  double get tasaMensual => (tasaInteresAnual ?? 0) / 100 / 12;

  /// Cuota mensual fija (Sistema Francés)
  /// Cuota = P * [i(1+i)^n] / [(1+i)^n - 1]
  double get cuotaMensual {
    if (montoPrestamo <= 0 || tasaMensual <= 0 || (plazoMeses ?? 0) <= 0) return 0;
    final i = tasaMensual;
    final n = plazoMeses!;
    final factor = math.pow(1 + i, n);
    return montoPrestamo * (i * factor) / (factor - 1);
  }

  /// Total de cuotas en un periodo (mesesPorPeriodo cuotas)
  double cuotasEnPeriodo(int mesesPorPeriodo) => cuotaMensual * mesesPorPeriodo;

  /// Genera tabla de amortización completa (mensual)
  List<AmortizacionMensual> generarTablaAmortizacion() {
    if (montoPrestamo <= 0 || tasaMensual <= 0 || (plazoMeses ?? 0) <= 0) return [];
    
    final List<AmortizacionMensual> tabla = [];
    double saldo = montoPrestamo;
    final cuota = cuotaMensual;
    final i = tasaMensual;
    final n = plazoMeses!;

    for (int mes = 1; mes <= n; mes++) {
      final interes = saldo * i;
      final capital = cuota - interes;
      saldo -= capital;
      if (saldo < 0.01) saldo = 0; // Ajuste por redondeo
      
      tabla.add(AmortizacionMensual(
        mes: mes,
        cuota: cuota,
        interes: interes,
        capital: capital,
        saldoInsoluto: saldo,
      ));
    }
    return tabla;
  }

  /// Resumen de amortización agrupado por periodos del proyecto
  List<AmortizacionPeriodo> resumenPorPeriodos(int mesesPorPeriodo, int totalPeriodos) {
    final tablaMensual = generarTablaAmortizacion();
    final List<AmortizacionPeriodo> resumen = [];
    
    for (int p = 1; p <= totalPeriodos; p++) {
      final mesInicio = (p - 1) * mesesPorPeriodo + 1;
      final mesFin = p * mesesPorPeriodo;
      
      // Filtrar cuotas de este periodo
      final cuotasPeriodo = tablaMensual.where((a) => a.mes >= mesInicio && a.mes <= mesFin).toList();
      
      if (cuotasPeriodo.isEmpty) {
        resumen.add(AmortizacionPeriodo(
          periodo: p,
          totalCuotas: 0,
          totalInteres: 0,
          totalCapital: 0,
          saldoFinal: tablaMensual.isNotEmpty ? tablaMensual.last.saldoInsoluto : montoPrestamo,
        ));
      } else {
        final totalCuotas = cuotasPeriodo.fold(0.0, (s, a) => s + a.cuota);
        final totalInteres = cuotasPeriodo.fold(0.0, (s, a) => s + a.interes);
        final totalCapital = cuotasPeriodo.fold(0.0, (s, a) => s + a.capital);
        final saldoFinal = cuotasPeriodo.last.saldoInsoluto;
        
        resumen.add(AmortizacionPeriodo(
          periodo: p,
          totalCuotas: totalCuotas,
          totalInteres: totalInteres,
          totalCapital: totalCapital,
          saldoFinal: saldoFinal,
        ));
      }
    }
    return resumen;
  }

  /// Saldo insoluto al final del horizonte productivo
  /// Se usa para liquidación en el Motor FEN
  double saldoInsolutoEnPeriodo(int periodo, int mesesPorPeriodo) {
    final tabla = generarTablaAmortizacion();
    final mesObjetivo = periodo * mesesPorPeriodo;
    if (mesObjetivo >= tabla.length) return 0;
    return tabla[mesObjetivo - 1].saldoInsoluto;
  }

  bool get tieneDeuda => pctDeuda > 0 && montoPrestamo > 0;

  Map<String, dynamic> toMap() => {
    'pct_propio': pctPropio,
    'pct_deuda': pctDeuda,
    'tasa_interes_anual': tasaInteresAnual,
    'plazo_meses': plazoMeses,
    'inversion_requerida': inversionRequerida,
    'monto_prestamo': montoPrestamo,
    'aporte_propio': aportePropio,
    'cuota_mensual': cuotaMensual,
  };
}

/// Una fila de la tabla de amortización mensual (Sistema Francés).
class AmortizacionMensual {
  final int mes;
  final double cuota;
  final double interes;
  final double capital;
  final double saldoInsoluto;

  AmortizacionMensual({
    required this.mes,
    required this.cuota,
    required this.interes,
    required this.capital,
    required this.saldoInsoluto,
  });

  Map<String, dynamic> toMap() => {
    'mes': mes,
    'cuota': cuota,
    'interes': interes,
    'capital': capital,
    'saldo_insoluto': saldoInsoluto,
  };
}

/// Resumen de amortización agrupado por periodo del proyecto.
class AmortizacionPeriodo {
  final int periodo;
  final double totalCuotas;      // Suma de cuotas en el periodo (flujo salida)
  final double totalInteres;     // Gasto financiero (P&G, no cash)
  final double totalCapital;     // Amortización de principal (flujo salida)
  final double saldoFinal;       // Saldo insoluto al cierre del periodo

  AmortizacionPeriodo({
    required this.periodo,
    required this.totalCuotas,
    required this.totalInteres,
    required this.totalCapital,
    required this.saldoFinal,
  });

  /// Flujo de caja real del periodo = -totalCuotas (salida)
  /// Interés va en P&G, Capital va en Flujo Caja
  double get flujoCaja => -totalCuotas;

  Map<String, dynamic> toMap() => {
    'periodo': periodo,
    'total_cuotas': totalCuotas,
    'total_interes': totalInteres,
    'total_capital': totalCapital,
    'saldo_final': saldoFinal,
    'flujo_caja': flujoCaja,
  };
}