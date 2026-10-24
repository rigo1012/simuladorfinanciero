import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../modelos/modelo_inversion.dart';
import '../modelos/activo.dart';
import '../modelos/configuracion_temporal.dart';
import '../modelos/ingreso_periodo.dart';
import '../modelos/costo_variable.dart';
import '../modelos/costo_fijo.dart';
import '../modelos/estructura_capital.dart';
import '../servicios/motor_fen.dart';
import '../servicios/evaluador_financiero.dart';
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

  // Contexto para operaciones que lo requieren (PDF, dialogs)
  BuildContext? _context;
  BuildContext? get context => _context;
  void setContext(BuildContext ctx) => _context = ctx;

  // Últimos parámetros usados en simulación
  double _ultimaTREMA = 0;
  int _ultimoHorizonte = 0;
  double _inflacionGlobalFijos = 0; // Guardada desde la UI de Costos Fijos
  double get ultimaTREMA => _ultimaTREMA;
  int get ultimoHorizonte => _ultimoHorizonte;
  double get inflacionGlobalFijos => _inflacionGlobalFijos;
  void setInflacionGlobalFijos(double v) { _inflacionGlobalFijos = v; notifyListeners(); }

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

  /// Verifica si todos los periodos tienen al menos un costo variable definido.
  bool get costosVariablesCompletos {
    if (!estaConfigurado) return false;
    final total = configTemporal.totalPeriodos;
    // Consideramos "completo" si hay al menos un item en cada periodo
    // Opcionalmente se podría requerir items en las 3 categorías
    return _costosVariables.length >= total && 
           _costosVariables.every((c) => c.items.isNotEmpty);
  }

  /// Verifica si todos los periodos tienen al menos un costo fijo definido.
  bool get costosFijosCompletos {
    if (!estaConfigurado) return false;
    final total = configTemporal.totalPeriodos;
    return _costosFijos.length >= total && 
           _costosFijos.every((c) => c.items.isNotEmpty);
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

  // --- COSTOS VARIABLES (CRUD por periodo) ---
  /// Agrega un item a un periodo específico (crea el periodo si no existe).
  void agregarItemCostoVariable(int periodo, ItemCostoVariable item, int mesesPorPeriodo, double inflacionAnualPct) {
    final index = _costosVariables.indexWhere((c) => c.periodo == periodo);
    if (index != -1) {
      // Agregar item al periodo existente
      final itemsActualizados = [..._costosVariables[index].items, item];
      _costosVariables[index] = _costosVariables[index].copyWith(items: itemsActualizados);
    } else {
      // Crear nuevo periodo
      final nuevo = CostoVariablePeriodo(
        periodo: periodo,
        items: [item],
        inflacionAnualPct: inflacionAnualPct,
        mesesPorPeriodo: mesesPorPeriodo,
      );
      _costosVariables.add(nuevo);
      _costosVariables.sort((a, b) => a.periodo.compareTo(b.periodo));
    }
    notifyListeners();
  }

  /// Actualiza un item existente en un periodo.
  void actualizarItemCostoVariable(int periodo, ItemCostoVariable itemActualizado) {
    final periodoIndex = _costosVariables.indexWhere((c) => c.periodo == periodo);
    if (periodoIndex != -1) {
      final items = _costosVariables[periodoIndex].items;
      final itemIndex = items.indexWhere((i) => i.id == itemActualizado.id);
      if (itemIndex != -1) {
        items[itemIndex] = itemActualizado;
        _costosVariables[periodoIndex] = _costosVariables[periodoIndex].copyWith(items: items);
        notifyListeners();
      }
    }
  }

  /// Elimina un item de un periodo.
  void eliminarItemCostoVariable(int periodo, String itemId) {
    final periodoIndex = _costosVariables.indexWhere((c) => c.periodo == periodo);
    if (periodoIndex != -1) {
      final items = _costosVariables[periodoIndex].items.where((i) => i.id != itemId).toList();
      if (items.isEmpty) {
        _costosVariables.removeAt(periodoIndex);
      } else {
        _costosVariables[periodoIndex] = _costosVariables[periodoIndex].copyWith(items: items);
      }
      notifyListeners();
    }
  }

  /// Limpia todos los costos variables.
  void limpiarCostosVariables() {
    _costosVariables.clear();
    notifyListeners();
  }

  /// Obtiene el CostoVariablePeriodo para un periodo (null si no existe).
  CostoVariablePeriodo? obtenerCostosVariables(int periodo) {
    try {
      return _costosVariables.firstWhere((c) => c.periodo == periodo);
    } catch (_) {
      return null;
    }
  }

  /// Getter para Motor FEN: costo variable total (con inflación) de un periodo.
  double costoVariableEnPeriodo(int periodo) {
    final cp = obtenerCostosVariables(periodo);
    return cp?.costoConInflacion ?? 0;
  }

  /// Getter para Motor FEN: lista de costos variables por periodo (con inflación).
  List<double> get costosVariablesPorPeriodo {
    if (!estaConfigurado) return [];
    final total = configTemporal.totalPeriodos;
    return List.generate(total, (i) => costoVariableEnPeriodo(i + 1));
  }

  /// Getter para Motor FEN: desglose por categoría en un periodo.
  Map<String, double> desgloseCostosVariablesEnPeriodo(int periodo) {
    final cp = obtenerCostosVariables(periodo);
    if (cp == null) return {'materiaPrima': 0, 'manoObra': 0, 'cargosIndirectos': 0, 'total': 0};
    return {
      'materiaPrima': cp.subtotalMateriaPrima * cp.factorInflacion,
      'manoObra': cp.subtotalManoObra * cp.factorInflacion,
      'cargosIndirectos': cp.subtotalCargosIndirectos * cp.factorInflacion,
      'total': cp.costoConInflacion,
    };
  }

  // --- COSTOS FIJOS (CRUD por periodo) ---
  /// Agrega un item a un periodo específico (crea el periodo si no existe).
  void agregarItemCostoFijo(int periodo, ItemCostoFijo item) {
    final index = _costosFijos.indexWhere((c) => c.periodo == periodo);
    if (index != -1) {
      final itemsActualizados = [..._costosFijos[index].items, item];
      _costosFijos[index] = _costosFijos[index].copyWith(items: itemsActualizados);
    } else {
      final nuevo = CostoFijoPeriodo(
        periodo: periodo,
        items: [item],
        inflacionAnualPct: 0, // Se usa la global de la UI
        mesesPorPeriodo: configTemporal?.mesesPorPeriodo ?? 1,
      );
      _costosFijos.add(nuevo);
      _costosFijos.sort((a, b) => a.periodo.compareTo(b.periodo));
    }
    notifyListeners();
  }

  /// Actualiza un item existente (elimina y agrega el actualizado).
  void actualizarItemCostoFijo(int periodo, ItemCostoFijo itemActualizado) {
    // Como ItemCostoFijo es inmutable, eliminamos y agregamos
    eliminarItemCostoFijo(periodo, itemActualizado.id);
    agregarItemCostoFijo(periodo, itemActualizado);
  }

  /// Elimina un item de un periodo.
  void eliminarItemCostoFijo(int periodo, String itemId) {
    final periodoIndex = _costosFijos.indexWhere((c) => c.periodo == periodo);
    if (periodoIndex != -1) {
      final items = _costosFijos[periodoIndex].items.where((i) => i.id != itemId).toList();
      if (items.isEmpty) {
        _costosFijos.removeAt(periodoIndex);
      } else {
        _costosFijos[periodoIndex] = _costosFijos[periodoIndex].copyWith(items: items);
      }
      notifyListeners();
    }
  }

  /// Limpia todos los costos fijos.
  void limpiarCostosFijos() {
    _costosFijos.clear();
    notifyListeners();
  }

  /// Obtiene el CostoFijoPeriodo para un periodo (null si no existe).
  CostoFijoPeriodo? obtenerCostosFijos(int periodo) {
    try {
      return _costosFijos.firstWhere((c) => c.periodo == periodo);
    } catch (_) {
      return null;
    }
  }

  /// Getter para Motor FEN: costo fijo total (con inflación donde aplique) de un periodo.
  double costoFijoEnPeriodo(int periodo, double inflacionGlobal) {
    final cp = obtenerCostosFijos(periodo);
    if (cp == null) return 0;
    // Recalcular con inflación global actual
    double total = 0;
    for (final item in cp.items) {
      total += item.costoConInflacion(periodo, configTemporal?.mesesPorPeriodo ?? 1, inflacionGlobal);
    }
    return total;
  }

  /// Getter para Motor FEN: lista de costos fijos por periodo.
  List<double> costosFijosPorPeriodo(double inflacionGlobal) {
    if (!estaConfigurado) return [];
    final total = configTemporal!.totalPeriodos;
    return List.generate(total, (i) => costoFijoEnPeriodo(i + 1, inflacionGlobal));
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

  /// Ejecuta la simulación completa: Motor FEN + Evaluador Financiero.
  /// Guarda el resultado completo en _ultimoResultado para la vista de resultados y PDF.
  Future<void> procesarSimulacionSimple(double tasaPct, int anios) async {
    // Guardar parámetros para recálculo y PDF
    _ultimaTREMA = tasaPct;
    _ultimoHorizonte = anios;

    // Validaciones previas
    if (!estaConfigurado) {
      _error = 'Falta configuración temporal (Paso 0)';
      notifyListeners();
      return;
    }
    if (inversionRequerida.activos.isEmpty) {
      _error = 'Debe agregar al menos un activo (Paso 1)';
      notifyListeners();
      return;
    }
    if (estructuraCapital == null) {
      _error = 'Falta estructura de financiamiento (Paso 2)';
      notifyListeners();
      return;
    }
    if (!ingresosCompletos) {
      _error = 'Faltan ingresos estimados (Paso 3)';
      notifyListeners();
      return;
    }
    if (!costosVariablesCompletos) {
      _error = 'Faltan costos variables (Paso 4)';
      notifyListeners();
      return;
    }
    if (!costosFijosCompletos) {
      _error = 'Faltan costos fijos (Paso 5)';
      notifyListeners();
      return;
    }

    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Motor FEN: construye flujos de caja completos
      final motor = MotorFEN.calcular(
        proveedor: this,
        tremaPct: tasaPct,
        horizonteAnios: anios,
        valorResidualPct: 0.1, // 10% por defecto
      );

      // 2. Evaluador Financiero: calcula VPN, TIR, Payback, B/C, etc.
      final evaluacion = EvaluadorFinanciero.evaluar(motor);

      // 3. Guardar en BD (registro simple para historial)
      final inversion = Inversion(
        monto: motor.inversionRequerida,
        tasaDescuento: motor.trema,
        horizonteAnios: motor.horizontePeriodos,
        van: evaluacion.vpn,
      );
      final db = await _db.baseDatos;
      await db.insert('inversion', inversion.aMapa());

      // 4. Preparar resultado COMPLETO para Vista Resultados y PDF
      _ultimoResultado = evaluacion.toMap();
      
      // 5. Recargar historial
      await cargarHistorial();
      
    } catch (e, stack) {
      _error = 'Error en simulación completa: $e';
      debugPrint('ProveedorSimulador error: $e\n$stack');
    } finally {
      _cargando = false;
      notifyListeners();
    }
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