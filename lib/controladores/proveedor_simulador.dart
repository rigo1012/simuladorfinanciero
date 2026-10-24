import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../modelos/modelo_inversion.dart';
import '../modelos/activo.dart';
import '../modelos/configuracion_temporal.dart';
import '../modelos/ingreso_periodo.dart';
import '../modelos/costo_variable.dart';
import '../modelos/costo_fijo.dart';
import '../modelos/estructura_capital.dart';
import '../nucleo/dbayuda.dart';

/// Proveedor principal del simulador financiero para sistemas de riego.
/// Maneja: cálculo VAN/TIR/Payback/B-C, persistencia SQLite e historial.
class ProveedorSimulador extends ChangeNotifier {
  final AyudanteBD _db = AyudanteBD.instancia;

  bool _cargando = false;
  bool _cargandoHistorial = false;
  List<Map<String, dynamic>> _historial = [];
  String? _error;
  Map<String, dynamic>? _ultimoResultado;

  // --- ACTIVOS (Inversión Requerida) ---
  final List<Activo> _activos = [];
  InversionRequerida get inversionRequerida => InversionRequerida.fromActivos(_activos);

  /// Agrega un nuevo activo y notifica cambios.
  void agregarActivo(Activo activo) {
    _activos.add(activo);
    notifyListeners();
  }

  /// Actualiza un activo existente (por ID).
  void actualizarActivo(Activo actualizado) {
    final index = _activos.indexWhere((a) => a.id == actualizado.id);
    if (index != -1) {
      _activos[index] = actualizado;
      notifyListeners();
    }
  }

  /// Elimina un activo por ID.
  void eliminarActivo(String id) {
    _activos.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  /// Limpia todos los activos.
  void limpiarActivos() {
    _activos.clear();
    notifyListeners();
  }

  // --- CONFIGURACIÓN TEMPORAL (Fase 0) ---
  ConfiguracionTemporal? _configTemporal;
  ConfiguracionTemporal get configTemporal => _configTemporal!;
  bool get estaConfigurado => _configTemporal != null;

  /// Configura la base temporal del proyecto.
  /// Reinicia todos los datos dependientes (activos, ingresos, costos, financiamiento).
  void configurarTemporal(ConfiguracionTemporal config) {
    _configTemporal = config;
    _reiniciarDatosDependientes();
    notifyListeners();
  }

  /// Reinicia configuración temporal y todos los datos.
  void reiniciarConfiguracionTemporal() {
    _configTemporal = null;
    _reiniciarDatosDependientes();
    notifyListeners();
  }

  // --- INGRESOS ESTIMADOS (por periodo) ---
  final List<IngresoPeriodo> _ingresos = [];
  List<IngresoPeriodo> get ingresos => List.unmodifiable(_ingresos);

  // --- COSTOS VARIABLES (por periodo, con inflación) ---
  final List<CostoVariablePeriodo> _costosVariables = [];
  List<CostoVariablePeriodo> get costosVariables => List.unmodifiable(_costosVariables);

  // --- COSTOS FIJOS (por periodo) ---
  final List<CostoFijoPeriodo> _costosFijos = [];
  List<CostoFijoPeriodo> get costosFijos => List.unmodifiable(_costosFijos);

  // --- ESTRUCTURA DE CAPITAL / FINANCIAMIENTO ---
  EstructuraCapital? _estructuraCapital;
  EstructuraCapital? get estructuraCapital => _estructuraCapital;

  /// Configura la estructura de financiamiento (% Propio / % Deuda).
  /// Reinicia datos posteriores (ingresos, costos, resultados).
  void configurarFinanciamiento(EstructuraCapital estructura) {
    _estructuraCapital = estructura;
    _reiniciarDatosPostFinanciamiento();
    notifyListeners();
  }

  /// Reinicia solo el financiamiento y datos posteriores.
  void reiniciarFinanciamiento() {
    _estructuraCapital = null;
    _reiniciarDatosPostFinanciamiento();
    notifyListeners();
  }

  /// Limpia ingresos, costos variables, costos fijos y resultados.
  void _reiniciarDatosPostFinanciamiento() {
    _ingresos.clear();
    _costosVariables.clear();
    _costosFijos.clear();
    _ultimoResultado = null;
    _error = null;
  }

  /// Getters de conveniencia para el Motor FEN
  double get montoPrestamo => _estructuraCapital?.montoPrestamo ?? 0;
  double get aportePropio => _estructuraCapital?.aportePropio ?? 0;
  double get cuotaMensual => _estructuraCapital?.cuotaMensual ?? 0;
  bool get tieneDeuda => _estructuraCapital?.tieneDeuda ?? false;

  /// Cuotas totales en un periodo (para Flujo de Caja)
  double cuotasEnPeriodo(int periodo, int mesesPorPeriodo) {
    if (!tieneDeuda) return 0;
    final mesInicio = (periodo - 1) * mesesPorPeriodo + 1;
    final mesFin = periodo * mesesPorPeriodo;
    final tabla = _estructuraCapital!.generarTablaAmortizacion();
    if (mesInicio > tabla.length) return 0;
    final fin = mesFin.clamp(0, tabla.length);
    return tabla.sublist(mesInicio - 1, fin).fold(0.0, (s, a) => s + a.cuota);
  }

  /// Intereses en un periodo (para P&G / Estado de Resultados)
  double interesesEnPeriodo(int periodo, int mesesPorPeriodo) {
    if (!tieneDeuda) return 0;
    final mesInicio = (periodo - 1) * mesesPorPeriodo + 1;
    final mesFin = periodo * mesesPorPeriodo;
    final tabla = _estructuraCapital!.generarTablaAmortizacion();
    if (mesInicio > tabla.length) return 0;
    final fin = mesFin.clamp(0, tabla.length);
    return tabla.sublist(mesInicio - 1, fin).fold(0.0, (s, a) => s + a.interes);
  }

  /// Amortización de capital en un periodo (para Flujo de Caja)
  double amortizacionCapitalEnPeriodo(int periodo, int mesesPorPeriodo) {
    if (!tieneDeuda) return 0;
    final mesInicio = (periodo - 1) * mesesPorPeriodo + 1;
    final mesFin = periodo * mesesPorPeriodo;
    final tabla = _estructuraCapital!.generarTablaAmortizacion();
    if (mesInicio > tabla.length) return 0;
    final fin = mesFin.clamp(0, tabla.length);
    return tabla.sublist(mesInicio - 1, fin).fold(0.0, (s, a) => s + a.capital);
  }

  /// Saldo insoluto al final de un periodo (para liquidación final)
  double saldoInsolutoEnPeriodo(int periodo, int mesesPorPeriodo) {
    if (!tieneDeuda) return 0;
    return _estructuraCapital!.saldoInsolutoEnPeriodo(periodo, mesesPorPeriodo);
  }

  // --- INGRESOS ESTIMADOS (CRUD) ---
  /// Actualiza o crea un ingreso para un periodo específico.
  void actualizarIngreso(IngresoPeriodo ingreso) {
    final index = _ingresos.indexWhere((i) => i.periodo == ingreso.periodo);
    if (index != -1) {
      _ingresos[index] = ingreso;
    } else {
      _ingresos.add(ingreso);
      _ingresos.sort((a, b) => a.periodo.compareTo(b.periodo));
    }
    notifyListeners();
  }

  /// Elimina un ingreso por periodo.
  void eliminarIngreso(int periodo) {
    _ingresos.removeWhere((i) => i.periodo == periodo);
    notifyListeners();
  }

  /// Limpia todos los ingresos.
  void limpiarIngresos() {
    _ingresos.clear();
    notifyListeners();
  }

  /// Obtiene ingreso para un periodo específico (null si no existe).
  IngresoPeriodo? obtenerIngreso(int periodo) {
    try {
      return _ingresos.firstWhere((i) => i.periodo == periodo);
    } catch (_) {
      return null;
    }
  }

  /// Verifica si todos los periodos tienen ingresos definidos.
  bool get ingresosCompletos {
    if (!estaConfigurado) return false;
    final total = configTemporal.totalPeriodos;
    return _ingresos.length == total && _ingresos.every((i) => i.precio > 0 && i.demanda > 0);
  }

  /// Getter para Motor FEN: ingreso de un periodo (0 si no definido).
  double ingresoEnPeriodo(int periodo) {
    final ing = obtenerIngreso(periodo);
    return ing?.ingreso ?? 0;
  }

  /// Getter para Motor FEN: lista de ingresos ordenada por periodo (rellena con 0 si faltan).
  List<double> get ingresosPorPeriodo {
    if (!estaConfigurado) return [];
    final total = configTemporal.totalPeriodos;
    return List.generate(total, (i) => ingresoEnPeriodo(i + 1));
  }

  void _reiniciarDatosDependientes() {
    _activos.clear();
    _ingresos.clear();
    _costosVariables.clear();
    _costosFijos.clear();
    _estructuraCapital = null;
    _ultimoResultado = null;
    _error = null;
  }

  // Getters públicos
  bool get estaCargando => _cargando;
  bool get estaCargandoHistorial => _cargandoHistorial;
  List<Map<String, dynamic>> get historialInversiones => List.unmodifiable(_historial);
  String? get error => _error;
  Map<String, dynamic>? get ultimoResultado => _ultimoResultado;

  /// Calcula el VAN (Valor Actual Neto) dado una serie de flujos de caja.
  static double _calcularVAN(List<double> flujos, double tasa) {
    double van = 0.0;
    for (int t = 0; t < flujos.length; t++) {
      van += flujos[t] / math.pow(1 + tasa, t);
    }
    return van;
  }

  /// Calcula la TIR (Tasa Interna de Retorno) por aproximación (método de la secante).
  static double? _calcularTIR(List<double> flujos, {double guess = 0.1, int maxIter = 50, double tol = 1e-6}) {
    double tasa = guess;
    for (int i = 0; i < maxIter; i++) {
      double van = 0, dVan = 0;
      for (int t = 0; t < flujos.length; t++) {
        double factor = math.pow(1 + tasa, t).toDouble();
        van += flujos[t] / factor;
        if (t > 0) dVan -= t * flujos[t] / (factor * (1 + tasa));
      }
      if (van.abs() < tol) return tasa;
      if (dVan == 0) break;
      double nuevaTasa = tasa - van / dVan;
      if ((nuevaTasa - tasa).abs() < tol) return nuevaTasa;
      if (nuevaTasa <= -1) return null; // TIR no válida
      tasa = nuevaTasa;
    }
    return null;
  }

  /// Calcula el Payback (periodo de recupero) simple y descontado.
  static Map<String, dynamic> _calcularPayback(List<double> flujos, double tasa) {
    double acumSimple = 0, acumDesc = 0;
    int paybackSimple = -1, paybackDesc = -1;

    for (int t = 1; t < flujos.length; t++) { // t=0 es inversión inicial (negativa)
      acumSimple += flujos[t];
      acumDesc += flujos[t] / math.pow(1 + tasa, t);

      if (paybackSimple == -1 && acumSimple + flujos[0] >= 0) {
        paybackSimple = t;
      }
      if (paybackDesc == -1 && acumDesc + flujos[0] >= 0) {
        paybackDesc = t;
      }
    }
    return {
      'simple': paybackSimple,
      'descontado': paybackDesc,
    };
  }

  /// Calcula la relación Beneficio/Costo (B/C).
  static double _calcularBC(List<double> flujos, double tasa) {
    double pvBeneficios = 0, pvCostos = 0;
    for (int t = 1; t < flujos.length; t++) {
      double pv = flujos[t] / math.pow(1 + tasa, t);
      if (pv > 0) {
        pvBeneficios += pv;
      } else {
        pvCostos += pv.abs();
      }
    }
    // Inversión inicial también es costo
    pvCostos += flujos[0].abs();
    return pvCostos > 0 ? pvBeneficios / pvCostos : double.infinity;
  }

  /// Construye los flujos de caja del proyecto de riego.
  /// 
  /// Parámetros basados en el PDF "SISTEMA DE RIEGO":
  /// - [montoInversion]: Inversión inicial (bomba, tuberías, automatización, instalación)
  /// - [hectareas]: Superficie a regar
  /// - [rendimientoBase]: Rendimiento actual (ton/ha) sin riego
  /// - [rendimientoConRiego]: Rendimiento esperado (ton/ha) con riego
  /// - [precioTonelada]: Precio de venta del cultivo ($/ton)
  /// - [costoOperacionAnual]: Energía, mano de obra, mantenimiento ($/año)
  /// - [costoAguaAnual]: Costo de agua/concesión ($/año)
  /// - [vidaUtil]: Vida útil del sistema (años)
  /// - [valorResidual]: Valor residual al final (% de inversión inicial)
  static List<double> _construirFlujosCaja({
    required double montoInversion,
    required double hectareas,
    required double rendimientoBase,
    required double rendimientoConRiego,
    required double precioTonelada,
    required double costoOperacionAnual,
    required double costoAguaAnual,
    required int vidaUtil,
    double valorResidualPct = 0.1,
  }) {
    final incrementoRendimiento = rendimientoConRiego - rendimientoBase;
    final ingresoAnual = incrementoRendimiento * hectareas * precioTonelada;
    final costoTotalAnual = costoOperacionAnual + costoAguaAnual;
    final flujoNetoAnual = ingresoAnual - costoTotalAnual;

    List<double> flujos = [];
    flujos.add(-montoInversion); // t=0: Inversión inicial (salida)

    for (int t = 1; t <= vidaUtil; t++) {
      if (t == vidaUtil) {
        // Último año: flujo neto + valor residual
        flujos.add(flujoNetoAnual + montoInversion * valorResidualPct);
      } else {
        flujos.add(flujoNetoAnual);
      }
    }
    return flujos;
  }

  /// Procesa una simulación completa: calcula indicadores y guarda en BD.
  Future<void> procesarSimulacion({
    required double monto,
    required double tasaDescuentoPct,
    required int horizonteAnios,
    // Parámetros específicos del sistema de riego (del PDF):
    required double hectareas,
    required double rendimientoBase,
    required double rendimientoConRiego,
    required double precioTonelada,
    required double costoOperacionAnual,
    required double costoAguaAnual,
    double valorResidualPct = 0.1,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final tasa = tasaDescuentoPct / 100.0;

      // 1. Construir flujos de caja reales del proyecto de riego
      final flujos = _construirFlujosCaja(
        montoInversion: monto,
        hectareas: hectareas,
        rendimientoBase: rendimientoBase,
        rendimientoConRiego: rendimientoConRiego,
        precioTonelada: precioTonelada,
        costoOperacionAnual: costoOperacionAnual,
        costoAguaAnual: costoAguaAnual,
        vidaUtil: horizonteAnios,
        valorResidualPct: valorResidualPct,
      );

      // 2. Calcular todos los indicadores financieros
      final van = _calcularVAN(flujos, tasa);
      final tir = _calcularTIR(flujos);
      final payback = _calcularPayback(flujos, tasa);
      final bc = _calcularBC(flujos, tasa);

      // 3. Guardar en BD (usamos el modelo existente que espera VAN)
      final inversion = Inversion(
        monto: monto,
        tasaDescuento: tasa,
        horizonteAnios: horizonteAnios,
        van: van,
      );

      final db = await _db.baseDatos;
      await db.insert('inversion', inversion.aMapa());

      // 4. Preparar resultado completo para la UI
      _ultimoResultado = {
        'van': van,
        'tir': tir != null ? tir * 100 : null, // En porcentaje
        'paybackSimple': payback['simple'],
        'paybackDescontado': payback['descontado'],
        'beneficioCosto': bc,
        'flujoNetoAnual': flujos.length > 1 ? flujos[1] : 0,
        'flujosCaja': flujos,
        'parametros': {
          'monto': monto,
          'tasaDescuento': tasaDescuentoPct,
          'horizonteAnios': horizonteAnios,
          'hectareas': hectareas,
          'rendimientoBase': rendimientoBase,
          'rendimientoConRiego': rendimientoConRiego,
          'precioTonelada': precioTonelada,
          'costoOperacionAnual': costoOperacionAnual,
          'costoAguaAnual': costoAguaAnual,
          'valorResidualPct': valorResidualPct * 100,
        },
      };

      // 5. Recargar historial
      await cargarHistorial();
    } catch (e, stack) {
      _error = 'Error en simulación: $e';
      debugPrint('ProveedorSimulador error: $e\n$stack');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Versión simplificada para compatibilidad con el formulario actual
  /// (usa la Inversión Requerida calculada desde los Activos).
  Future<void> procesarSimulacionSimple(double tasaPct, int anios) async {
    final monto = inversionRequerida.total;
    if (monto <= 0) {
      _error = 'Debe agregar al menos un activo para calcular la Inversión Requerida';
      notifyListeners();
      return;
    }
    await procesarSimulacion(
      monto: monto,
      tasaDescuentoPct: tasaPct,
      horizonteAnios: anios,
      // Valores por defecto razonables (ajustar según PDF)
      hectareas: 50,
      rendimientoBase: 4.0,
      rendimientoConRiego: 8.5,
      precioTonelada: 3500,
      costoOperacionAnual: 120000,
      costoAguaAnual: 30000,
      valorResidualPct: 0.1,
    );
  }

  /// Carga el historial de simulaciones desde SQLite.
  Future<void> cargarHistorial() async {
    _cargandoHistorial = true;
    notifyListeners();

    try {
      final db = await _db.baseDatos;
      _historial = await db.query('inversion', orderBy: 'id DESC');
    } catch (e) {
      _error = 'Error cargando historial: $e';
      _historial = [];
    } finally {
      _cargandoHistorial = false;
      notifyListeners();
    }
  }

  /// Elimina una simulación del historial por ID.
  Future<void> eliminarSimulacion(int id) async {
    try {
      final db = await _db.baseDatos;
      await db.delete('inversion', where: 'id = ?', whereArgs: [id]);
      await cargarHistorial();
    } catch (e) {
      _error = 'Error eliminando: $e';
      notifyListeners();
    }
  }

  /// Limpia el último resultado calculado.
  void limpiarUltimoResultado() {
    _ultimoResultado = null;
    notifyListeners();
  }
}