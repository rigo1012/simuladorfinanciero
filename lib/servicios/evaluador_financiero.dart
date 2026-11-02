import 'dart:math' as math;
import 'motor_fen.dart';

/// Resultado de la evaluación financiera.
class ResultadoEvaluacion {
  final ResultadoMotorFEN motorFEN;
  final double vpn;                     // Valor Presente Neto (con TREMA)
  final double vpnOperativo;            // VPN operativo (sin financiamiento)
  final double? tir;                    // Tasa Interna de Retorno (%)
  final double? tirOperativa;           // TIR operativa (%)
  final int? paybackPeriodos;           // Payback simple (periodos)
  final int? paybackDescontado;         // Payback descontado (periodos)
  final double beneficioCosto;          // Relación Beneficio/Costo (B/C)
  final double beneficioCostoOperativo; // B/C operativo
  final bool esViable;                  // VPN > 0
  final String veredicto;               // "VIABLE" / "NO VIABLE"
  final Map<String, dynamic> kpis;      // KPIs adicionales

  ResultadoEvaluacion({
    required this.motorFEN,
    required this.vpn,
    required this.vpnOperativo,
    this.tir,
    this.tirOperativa,
    this.paybackPeriodos,
    this.paybackDescontado,
    required this.beneficioCosto,
    required this.beneficioCostoOperativo,
    required this.esViable,
    required this.veredicto,
    required this.kpis,
  });

  Map<String, dynamic> toMap() => {
    'vpn': vpn,
    'vpn_operativo': vpnOperativo,
    'tir': tir,
    'tir_operativa': tirOperativa,
    'payback_periodos': paybackPeriodos,
    'payback_descontado': paybackDescontado,
    'beneficio_costo': beneficioCosto,
    'beneficio_costo_operativo': beneficioCostoOperativo,
    'es_viable': esViable,
    'veredicto': veredicto,
    'kpis': kpis,
    'motor_fen': {
      'flujos': motorFEN.flujos.map((f) => f.toMap()).toList(),
      'config': motorFEN.config.toMap(),
      'estructura': motorFEN.estructura?.toMap(),
    },
  };
}

/// Evaluador Financiero: calcula VPN, TIR, Payback, B/C a partir del Motor FEN.
class EvaluadorFinanciero {
  /// Evalúa el proyecto usando los flujos del Motor FEN.
  static ResultadoEvaluacion evaluar(ResultadoMotorFEN motor) {
    final flujos = motor.flujosParaVPN;
    final flujosOperativos = motor.flujosOperativosParaVPN;
    // Tasa de descuento POR PERIODO derivada de la TREMA anual.
    final tasaPeriodo = motor.tasaPeriodo;
    final mesesPorPeriodo = motor.config.mesesPorPeriodo;

    // 1. VPN (con financiamiento)
    final vpn = _calcularVPN(flujos, tasaPeriodo);
    
    // 2. VPN Operativo (sin financiamiento)
    final vpnOperativo = _calcularVPN(flujosOperativos, tasaPeriodo);

    // 3. TIR por periodo (con financiamiento)
    final tirPeriodo = _calcularTIR(flujos);
    
    // 4. TIR por periodo operativa
    final tirOperativaPeriodo = _calcularTIR(flujosOperativos);

    // 5. Payback Simple (con financiamiento)
    final payback = _calcularPayback(flujos);
    
    // 6. Payback Descontado
    final paybackDesc = _calcularPaybackDescontado(flujos, tasaPeriodo);

    // 7. Beneficio/Costo (con financiamiento)
    final bc = _calcularBC(motor, tasaPeriodo, conFinanciamiento: true);
    
    // 8. Beneficio/Costo Operativo
    final bcOperativo = _calcularBC(motor, tasaPeriodo, conFinanciamiento: false);

    // 9. Veredicto
    final esViable = vpn > 0;
    final veredicto = esViable ? 'VIABLE' : 'NO VIABLE';

    // KPIs adicionales (la TIR se guarda anualizada más abajo)
    final kpis = _calcularKPIs(motor, vpn, tirPeriodo, payback?.toDouble());

    // Las TIR se calculan por periodo y se convierten a anual efectiva.
    final tirAnual = _anualizarTasa(tirPeriodo, mesesPorPeriodo);
    final tirOperativaAnual = _anualizarTasa(tirOperativaPeriodo, mesesPorPeriodo);

    return ResultadoEvaluacion(
      motorFEN: motor,
      vpn: vpn,
      vpnOperativo: vpnOperativo,
      tir: tirAnual != null ? tirAnual * 100 : null, // % anual efectiva
      tirOperativa: tirOperativaAnual != null ? tirOperativaAnual * 100 : null,
      paybackPeriodos: payback,
      paybackDescontado: paybackDesc,
      beneficioCosto: bc,
      beneficioCostoOperativo: bcOperativo,
      esViable: esViable,
      veredicto: veredicto,
      kpis: kpis,
    );
  }

  /// Convierte una tasa efectiva por periodo a tasa anual efectiva.
  /// Retorna null si no hay tasa o si la conversión no es válida.
  static double? _anualizarTasa(double? tasaPeriodo, int mesesPorPeriodo) {
    if (tasaPeriodo == null || mesesPorPeriodo <= 0) return null;
    final base = 1 + tasaPeriodo;
    if (base <= 0) return null;
    return (math.pow(base, 12 / mesesPorPeriodo) - 1).toDouble();
  }

  /// Calcula VPN = Σ Flujo[t] / (1+tasa)^t
  static double _calcularVPN(List<double> flujos, double tasa) {
    double vpn = 0.0;
    for (int t = 0; t < flujos.length; t++) {
      vpn += flujos[t] / math.pow(1 + tasa, t);
    }
    return vpn;
  }

  /// Calcula la TIR por periodo con Newton-Raphson y, si no converge,
  /// recurre a bisección en [-0.99, 10]. Solo devuelve null si no hay
  /// cambio de signo en los flujos.
  static double? _calcularTIR(List<double> flujos, {double guess = 0.1, int maxIter = 100, double tol = 1e-8}) {
    // Verificar que hay cambio de signo (necesario para TIR)
    final signos = flujos.map((f) => f > 0 ? 1 : (f < 0 ? -1 : 0)).where((s) => s != 0).toSet();
    if (signos.length < 2) return null; // No hay inversión y retorno

    // 1) Newton-Raphson
    double tasa = guess;
    for (int i = 0; i < maxIter; i++) {
      double vpn = 0, dVpn = 0;
      for (int t = 0; t < flujos.length; t++) {
        final factor = math.pow(1 + tasa, t);
        vpn += flujos[t] / factor;
        if (t > 0) {
          dVpn -= t * flujos[t] / (factor * (1 + tasa));
        }
      }

      if (vpn.abs() < tol) return tasa;
      if (dVpn == 0) break;

      final nuevaTasa = tasa - vpn / dVpn;

      // Si se sale del rango razonable, se abandona Newton y se usa bisección.
      if (!nuevaTasa.isFinite || nuevaTasa <= -0.999 || nuevaTasa > 1000) break;
      if ((nuevaTasa - tasa).abs() < tol) return nuevaTasa;

      tasa = nuevaTasa;
    }

    // 2) Bisección como respaldo
    return _tirBiseccion(flujos, -0.99, 10.0, tol);
  }

  /// Bisección para la TIR por periodo en el intervalo [lo, hi].
  static double? _tirBiseccion(List<double> flujos, double lo, double hi, double tol) {
    double vpnEn(double tasa) {
      double vpn = 0;
      for (int t = 0; t < flujos.length; t++) {
        vpn += flujos[t] / math.pow(1 + tasa, t);
      }
      return vpn;
    }

    var vLo = vpnEn(lo);
    var vHi = vpnEn(hi);
    if (vLo == 0) return lo;
    if (vHi == 0) return hi;
    if (vLo.sign == vHi.sign) return null; // No hay cambio de signo

    for (int i = 0; i < 200; i++) {
      final medio = (lo + hi) / 2;
      final vMedio = vpnEn(medio);
      if (vMedio.abs() < tol || (hi - lo).abs() < tol) return medio;

      if (vMedio.sign == vLo.sign) {
        lo = medio;
        vLo = vMedio;
      } else {
        hi = medio;
        vHi = vMedio;
      }
    }
    return (lo + hi) / 2;
  }

  /// Payback simple: primer periodo donde flujo acumulado ≥ 0
  static int? _calcularPayback(List<double> flujos) {
    double acumulado = 0;
    for (int t = 0; t < flujos.length; t++) {
      acumulado += flujos[t];
      if (acumulado >= 0 && t > 0) return t;
    }
    return null; // No recupera la inversión
  }

  /// Payback descontado: primer periodo donde VPN acumulado ≥ 0
  static int? _calcularPaybackDescontado(List<double> flujos, double tasa) {
    double vpnAcum = 0;
    for (int t = 0; t < flujos.length; t++) {
      vpnAcum += flujos[t] / math.pow(1 + tasa, t);
      if (vpnAcum >= 0 && t > 0) return t;
    }
    return null;
  }

  /// Relación Beneficio/Costo real:
  /// VP(ingresos + valor residual) /
  /// (inversión inicial + VP(costos variables + costos fijos + impuestos [+ intereses]))
  static double _calcularBC(ResultadoMotorFEN motor, double tasa, {required bool conFinanciamiento}) {
    final flujos = motor.flujos;
    double pvBeneficios = 0;
    double pvCostos = 0;

    for (int t = 1; t < flujos.length; t++) {
      final factor = math.pow(1 + tasa, t);
      final f = flujos[t];
      pvBeneficios += (f.ingreso + f.valorResidual) / factor;

      final impuesto = conFinanciamiento ? f.impuesto : f.impuestoOperativo;
      final intereses = conFinanciamiento ? f.interes : 0.0;
      pvCostos += (f.costoVariable + f.costoFijo + impuesto + intereses) / factor;
    }

    final denominador = motor.inversionRequerida + pvCostos;
    return denominador > 0 ? pvBeneficios / denominador : double.infinity;
  }

  /// Payback simple fraccionario (en periodos) con interpolación lineal
  /// dentro del periodo en que se recupera la inversión.
  static double? _calcularPaybackFraccion(List<double> flujos) {
    if (flujos.isEmpty) return null;
    double acumulado = flujos[0];
    if (acumulado >= 0) return 0;

    for (int t = 1; t < flujos.length; t++) {
      final anterior = acumulado;
      acumulado += flujos[t];
      if (acumulado >= 0) {
        final faltante = -anterior;
        final delPeriodo = flujos[t];
        if (delPeriodo <= 0) return t.toDouble();
        final fraccion = faltante / delPeriodo;
        return (t - 1) + fraccion.clamp(0.0, 1.0);
      }
    }
    return null;
  }

  /// Payback descontado fraccionario (en periodos) con interpolación lineal.
  static double? _calcularPaybackDescontadoFraccion(List<double> flujos, double tasa) {
    if (flujos.isEmpty) return null;
    double acumulado = flujos[0];
    if (acumulado >= 0) return 0;

    for (int t = 1; t < flujos.length; t++) {
      final flujoDescontado = flujos[t] / math.pow(1 + tasa, t);
      final anterior = acumulado;
      acumulado += flujoDescontado;
      if (acumulado >= 0) {
        final faltante = -anterior;
        if (flujoDescontado <= 0) return t.toDouble();
        final fraccion = faltante / flujoDescontado;
        return (t - 1) + fraccion.clamp(0.0, 1.0);
      }
    }
    return null;
  }

  /// KPIs adicionales para el reporte
  static Map<String, dynamic> _calcularKPIs(ResultadoMotorFEN motor, double vpn, double? tir, double? payback) {
    final flujos = motor.flujos;
    final inversion = motor.inversionRequerida;
    final aporte = motor.aportePropio;
    final prestamo = motor.montoPrestamo;
    final totalPeriodos = motor.horizontePeriodos;
    
    // Totales
    double totalIngresos = 0, totalCostosVar = 0, totalCostosFix = 0, totalIntereses = 0, totalAmortizacion = 0;
    double totalImpuestos = 0, totalDepreciacion = 0;
    for (int i = 1; i < flujos.length; i++) {
      totalIngresos += flujos[i].ingreso;
      totalCostosVar += flujos[i].costoVariable;
      totalCostosFix += flujos[i].costoFijo;
      totalIntereses += flujos[i].interes;
      totalAmortizacion += flujos[i].amortizacionCapital;
      totalImpuestos += flujos[i].impuesto;
      totalDepreciacion += flujos[i].depreciacion;
    }
    
    final ebitdaTotal = totalIngresos - (flujos.skip(1).fold(0.0, (s, f) => s + f.costoVariable + f.costoFijo));
    final utilidadTotal = ebitdaTotal - flujos.skip(1).fold(0.0, (s, f) => s + f.interes);
    final flujoCajaTotal = flujos.skip(1).fold(0.0, (s, f) => s + f.flujoCaja);

    // Payback fraccionario convertido a años.
    final anosPorPeriodo = motor.config.mesesPorPeriodo / 12.0;
    final paybackFraccion = _calcularPaybackFraccion(motor.flujosParaVPN);
    final paybackDescFraccion =
        _calcularPaybackDescontadoFraccion(motor.flujosParaVPN, motor.tasaPeriodo);

    return {
      'inversion_requerida': motor.inversionRequerida,
      'aporte_propio': motor.aportePropio,
      'monto_prestamo': prestamo,
      'total_ingresos': totalIngresos,
      'total_costos_variables': totalCostosVar,
      'total_costos_fijos': totalCostosFix,
      'total_intereses': totalIntereses,
      'total_amortizacion_capital': totalAmortizacion,
      'total_impuestos': totalImpuestos,
      'total_depreciacion': totalDepreciacion,
      'ebitda_total': ebitdaTotal,
      'utilidad_total': utilidadTotal,
      'flujo_caja_total': flujoCajaTotal,
      'valor_residual': flujos.last.valorResidual,
      'payback_anios': paybackFraccion == null ? null : paybackFraccion * anosPorPeriodo,
      'payback_descontado_anios':
          paybackDescFraccion == null ? null : paybackDescFraccion * anosPorPeriodo,
      'roi': inversion > 0 ? (vpn / inversion) * 100 : 0,
      'roi_aporte': aporte > 0 ? (vpn / aporte) * 100 : 0,
      'margen_ebitda': totalIngresos > 0 ? (ebitdaTotal / totalIngresos) * 100 : 0,
      'margen_neto': totalIngresos > 0 ? (utilidadTotal / totalIngresos) * 100 : 0,
      'periodos_proyecto': totalPeriodos,
      'años_proyecto': motor.config.totalPeriodos * motor.config.mesesPorPeriodo / 12,
    };
  }
}