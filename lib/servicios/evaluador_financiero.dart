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
    final tasa = motor.trema;

    // 1. VPN (con financiamiento)
    final vpn = _calcularVPN(flujos, tasa);
    
    // 2. VPN Operativo (sin financiamiento)
    final vpnOperativo = _calcularVPN(flujosOperativos, tasa);

    // 3. TIR (con financiamiento)
    final tir = _calcularTIR(flujos);
    
    // 4. TIR Operativa
    final tirOperativa = _calcularTIR(flujosOperativos);

    // 5. Payback Simple (con financiamiento)
    final payback = _calcularPayback(flujos);
    
    // 6. Payback Descontado
    final paybackDesc = _calcularPaybackDescontado(flujos, tasa);

    // 7. Beneficio/Costo (con financiamiento)
    final bc = _calcularBC(flujos, tasa);
    
    // 8. Beneficio/Costo Operativo
    final bcOperativo = _calcularBC(flujosOperativos, tasa);

    // 9. Veredicto
    final esViable = vpn > 0;
    final veredicto = esViable ? 'VIABLE' : 'NO VIABLE';

    // KPIs adicionales
    final kpis = _calcularKPIs(motor, vpn, tir, payback?.toDouble());

    return ResultadoEvaluacion(
      motorFEN: motor,
      vpn: vpn,
      vpnOperativo: vpnOperativo,
      tir: tir != null ? tir * 100 : null, // Convertir a %
      tirOperativa: tirOperativa != null ? tirOperativa * 100 : null,
      paybackPeriodos: payback,
      paybackDescontado: paybackDesc,
      beneficioCosto: bc,
      beneficioCostoOperativo: bcOperativo,
      esViable: esViable,
      veredicto: veredicto,
      kpis: kpis,
    );
  }

  /// Calcula VPN = Σ Flujo[t] / (1+tasa)^t
  static double _calcularVPN(List<double> flujos, double tasa) {
    double vpn = 0.0;
    for (int t = 0; t < flujos.length; t++) {
      vpn += flujos[t] / math.pow(1 + tasa, t);
    }
    return vpn;
  }

  /// Calcula TIR por método de la secante (Newton-Raphson simplificado).
  static double? _calcularTIR(List<double> flujos, {double guess = 0.1, int maxIter = 100, double tol = 1e-8}) {
    double tasa = guess;
    
    // Verificar que hay cambio de signo (necesario para TIR)
    final signos = flujos.map((f) => f > 0 ? 1 : (f < 0 ? -1 : 0)).where((s) => s != 0).toSet();
    if (signos.length < 2) return null; // No hay inversión y retorno

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
      
      double nuevaTasa = tasa - vpn / dVpn;
      
      // Validar que la nueva tasa sea razonable
      if (nuevaTasa <= -0.99 || nuevaTasa > 10) return null;
      if ((nuevaTasa - tasa).abs() < tol) return nuevaTasa;
      
      tasa = nuevaTasa;
    }
    return null;
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

  /// Relación Beneficio/Costo = PV(Beneficios) / PV(Costos)
  static double _calcularBC(List<double> flujos, double tasa) {
    double pvBeneficios = 0, pvCostos = 0;
    for (int t = 1; t < flujos.length; t++) { // t=0 es inversión
      final pv = flujos[t] / math.pow(1 + tasa, t);
      if (pv > 0) pvBeneficios += pv;
      else pvCostos += pv.abs();
    }
    // Inversión inicial también es costo
    pvCostos += flujos[0].abs();
    return pvCostos > 0 ? pvBeneficios / pvCostos : double.infinity;
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
    for (int i = 1; i < flujos.length; i++) {
      totalIngresos += flujos[i].ingreso;
      totalCostosVar += flujos[i].costoVariable;
      totalCostosFix += flujos[i].costoFijo;
      totalIntereses += flujos[i].interes;
      totalAmortizacion += flujos[i].amortizacionCapital;
    }
    
    final ebitdaTotal = totalIngresos - (flujos.skip(1).fold(0.0, (s, f) => s + f.costoVariable + f.costoFijo));
    final utilidadTotal = ebitdaTotal - flujos.skip(1).fold(0.0, (s, f) => s + f.interes);
    final flujoCajaTotal = flujos.skip(1).fold(0.0, (s, f) => s + f.flujoCaja);
    
    return {
      'inversion_requerida': motor.inversionRequerida,
      'aporte_propio': motor.aportePropio,
      'monto_prestamo': motor.montoPrestamo,
      'total_ingresos': totalIngresos,
      'total_costos_variables': totalCostosVar,
      'total_costos_fijos': flujos.skip(1).fold(0.0, (s, f) => s + f.costoFijo),
      'total_intereses': totalIntereses,
      'total_amortizacion_capital': totalAmortizacion,
      'ebitda_total': ebitdaTotal,
      'utilidad_total': utilidadTotal,
      'flujo_caja_total': flujoCajaTotal,
      'valor_residual': flujos.last.valorResidual,
      'roi': inversion > 0 ? (vpn / inversion) * 100 : 0,
      'roi_aporte': aporte > 0 ? (vpn / aporte) * 100 : 0,
      'margen_ebitda': totalIngresos > 0 ? (ebitdaTotal / totalIngresos) * 100 : 0,
      'margen_neto': totalIngresos > 0 ? (utilidadTotal / totalIngresos) * 100 : 0,
      'periodos_proyecto': totalPeriodos,
      'años_proyecto': motor.config.totalPeriodos * motor.config.mesesPorPeriodo / 12,
    };
  }
}