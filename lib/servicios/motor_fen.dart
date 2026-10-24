import 'dart:math' as math;
import '../controladores/proveedor_simulador.dart';
import '../modelos/configuracion_temporal.dart';
import '../modelos/estructura_capital.dart';

/// Resultado del Motor FEN para un periodo específico.
class FlujoPeriodo {
  final int periodo;                    // 0, 1, 2... N
  final int mesInicio;                  // Mes absoluto de inicio
  final int mesFin;                     // Mes absoluto de fin
  
  // Componentes del flujo
  final double ingreso;                 // Ingresos del periodo
  final double costoVariable;           // Costos variables (con inflación)
  final double costoFijo;               // Costos fijos (con inflación donde aplique)
  final double interes;                 // Interés del periodo (gasto financiero)
  final double amortizacionCapital;     // Amortización de capital (salida flujo)
  final double liquidacionSaldo;        // Liquidación saldo insoluto (solo último periodo productivo)
  
  // Valor residual de activos (solo último periodo del horizonte)
  final double valorResidual;
  
  // Inversión inicial (solo periodo 0)
  final double inversionInicial;

  FlujoPeriodo({
    required this.periodo,
    required this.mesInicio,
    required this.mesFin,
    required this.ingreso,
    required this.costoVariable,
    required this.costoFijo,
    required this.interes,
    required this.amortizacionCapital,
    this.liquidacionSaldo = 0,
    this.valorResidual = 0,
    this.inversionInicial = 0,
  });

  /// Flujo Operativo (EBITDA) = Ingresos - Costos Variables - Costos Fijos
  double get ebitda => ingreso - costoVariable - costoFijo;

  /// Utilidad Antes de Impuestos (UAI) = EBITDA - Intereses
  double get uai => ebitda - interes;

  /// Flujo de Caja Libre (FEN) = UAI - Amortización Capital - Liquidación + Valor Residual
  /// Para periodo 0: retorna -inversionInicial (salida inicial de caja)
  double get flujoCaja {
    if (periodo == 0) return -inversionInicial;
    return uai - amortizacionCapital - liquidacionSaldo + valorResidual;
  }

  /// Flujo de Caja Operativo (para VPN operativo) = EBITDA
  /// Para periodo 0: retorna -inversionInicial
  double get flujoOperativo {
    if (periodo == 0) return -inversionInicial;
    return ebitda;
  }

  Map<String, dynamic> toMap() => {
    'periodo': periodo,
    'mes_inicio': mesInicio,
    'mes_fin': mesFin,
    'ingreso': ingreso,
    'costo_variable': costoVariable,
    'costo_fijo': costoFijo,
    'ebitda': ebitda,
    'interes': interes,
    'uai': uai,
    'amortizacion_capital': amortizacionCapital,
    'liquidacion_saldo': liquidacionSaldo,
    'valor_residual': valorResidual,
    'inversion_inicial': inversionInicial,
    'flujo_caja': flujoCaja,
    'flujo_operativo': flujoOperativo,
  };
}

/// Resultado completo del Motor FEN.
class ResultadoMotorFEN {
  final List<FlujoPeriodo> flujos;      // Periodo 0..N
  final ConfiguracionTemporal config;
  final EstructuraCapital? estructura;
  final double inversionRequerida;
  final double aportePropio;
  final double montoPrestamo;
  final double valorResidualPct;        // % de inversión (default 10%)
  final double trema;                   // TREMA decimal (ej: 0.12)
  final int horizontePeriodos;          // Periodos a evaluar (≤ config.totalPeriodos)

  ResultadoMotorFEN({
    required this.flujos,
    required this.config,
    required this.estructura,
    required this.inversionRequerida,
    required this.aportePropio,
    required this.montoPrestamo,
    required this.valorResidualPct,
    required this.trema,
    required this.horizontePeriodos,
  });

  /// Flujo de caja completo para VPN/TIR (Periodo 0 = -aportePropio, Periodo 1..N = flujoCaja)
  List<double> get flujosParaVPN {
    final lista = <double>[];
    lista.add(-aportePropio); // Periodo 0: salida inicial
    for (int i = 1; i < flujos.length; i++) {
      lista.add(flujos[i].flujoCaja);
    }
    return lista;
  }

  /// Flujos operativos para VPN operativo (sin financiamiento)
  List<double> get flujosOperativosParaVPN {
    final lista = <double>[];
    lista.add(-inversionRequerida); // Periodo 0: inversión total
    for (int i = 1; i < flujos.length; i++) {
      lista.add(flujos[i].flujoOperativo);
    }
    return lista;
  }
}

class MotorFEN {
  /// Calcula el flujo de caja completo del proyecto.
  static ResultadoMotorFEN calcular({
    required ProveedorSimulador proveedor,
    required double tremaPct,           // TREMA en porcentaje (ej: 12.5)
    required int horizonteAnios,        // Horizonte de evaluación en años
    double valorResidualPct = 0.1,      // 10% por defecto
  }) {
    final config = proveedor.configTemporal!;
    final estructura = proveedor.estructuraCapital;
    final inversionRequerida = proveedor.inversionRequerida.total;
    final aportePropio = proveedor.aportePropio;
    final montoPrestamo = proveedor.montoPrestamo;
    final tieneDeuda = proveedor.tieneDeuda;
    final mesesPorPeriodo = config.mesesPorPeriodo;
    final totalPeriodosConfig = config.totalPeriodos;
    
    // Determinar horizonte en periodos (mínimo entre horizonte solicitado y config)
    final horizontePeriodos = (horizonteAnios * 12 / mesesPorPeriodo).floor().clamp(1, totalPeriodosConfig);
    
    // Obtener arrays de datos por periodo (1..N)
    final ingresos = proveedor.ingresosPorPeriodo;
    final costosVariables = proveedor.costosVariablesPorPeriodo;
    final inflacionGlobalFijos = proveedor.inflacionGlobalFijos;
    final costosFijos = proveedor.costosFijosPorPeriodo(inflacionGlobalFijos);

    // Valor residual = % de inversión requerida en el último periodo del horizonte
    final valorResidualMonto = inversionRequerida * valorResidualPct;

    final List<FlujoPeriodo> flujos = [];
    
    // PERIODO 0: Inversión inicial (solo aporte propio, el préstamo entra como financiación)
    flujos.add(FlujoPeriodo(
      periodo: 0,
      mesInicio: 0,
      mesFin: 0,
      ingreso: 0,
      costoVariable: 0,
      costoFijo: 0,
      interes: 0,
      amortizacionCapital: 0,
      liquidacionSaldo: 0,
      valorResidual: 0,
      inversionInicial: aportePropio, // Salida de caja inicial = aporte propio
    ));

    // PERIODOS 1..horizontePeriodos
    for (int p = 1; p <= horizontePeriodos; p++) {
      final mesInicio = (p - 1) * mesesPorPeriodo + 1;
      final mesFin = p * mesesPorPeriodo;
      
      // Ingresos del periodo (0 si no definido)
      final ingreso = (p <= ingresos.length ? ingresos[p - 1] : 0).toDouble();
      
      // Costos variables (con inflación ya aplicada)
      final costoVariable = (p <= costosVariables.length ? costosVariables[p - 1] : 0).toDouble();
      
      // Costos fijos (recalculados con inflación global actual)
      final costoFijo = proveedor.costoFijoEnPeriodo(p, inflacionGlobalFijos).toDouble();
      
      // Financiamiento
      double interes = 0;
      double amortizacionCapital = 0;
      double liquidacionSaldo = 0;
      
      if (tieneDeuda && estructura != null) {
        interes = proveedor.interesesEnPeriodo(p, mesesPorPeriodo).toDouble();
        amortizacionCapital = proveedor.amortizacionCapitalEnPeriodo(p, mesesPorPeriodo).toDouble();
        
        // Liquidación de saldo insoluto en el último periodo productivo
        final plazoCreditoPeriodos = (estructura.plazoMeses! / mesesPorPeriodo).ceil();
        if (p == horizontePeriodos && horizontePeriodos < plazoCreditoPeriodos) {
          liquidacionSaldo = proveedor.saldoInsolutoEnPeriodo(p, mesesPorPeriodo).toDouble();
        }
      }
      
      // Valor residual solo en el último periodo del horizonte
      final valorResidual = (p == horizontePeriodos) ? valorResidualMonto.toDouble() : 0.0;

      flujos.add(FlujoPeriodo(
        periodo: p,
        mesInicio: mesInicio,
        mesFin: mesFin,
        ingreso: ingreso,
        costoVariable: costoVariable,
        costoFijo: costoFijo,
        interes: interes,
        amortizacionCapital: amortizacionCapital,
        liquidacionSaldo: liquidacionSaldo,
        valorResidual: valorResidual,
      ));
    }

    return ResultadoMotorFEN(
      flujos: flujos,
      config: config,
      estructura: estructura,
      inversionRequerida: inversionRequerida,
      aportePropio: aportePropio,
      montoPrestamo: montoPrestamo,
      valorResidualPct: valorResidualPct,
      trema: tremaPct / 100.0,
      horizontePeriodos: horizontePeriodos,
    );
  }
}