import 'dart:math' as math;

/// Item individual de costo variable (Materia Prima, Mano de Obra, Cargos Indirectos).
class ItemCostoVariable {
  final String id;
  final TipoCostoVariable tipo;
  final String nombre;
  final double cantidadUnitaria;    // Para Materia Prima y Cargos Indirectos
  final double costoUnitario;       // Costo por unidad
  final double costoPorOperacion;   // Para Mano de Obra

  ItemCostoVariable({
    required this.id,
    required this.tipo,
    required this.nombre,
    this.cantidadUnitaria = 0,
    this.costoUnitario = 0,
    this.costoPorOperacion = 0,
  });

  /// Costo total del item (se usa para sumar en el periodo)
  double get costoTotal {
    switch (tipo) {
      case TipoCostoVariable.materiaPrima:
      case TipoCostoVariable.cargosIndirectos:
        return cantidadUnitaria * costoUnitario;
      case TipoCostoVariable.manoObra:
        return costoPorOperacion;
    }
  }

  ItemCostoVariable copyWith({
    String? id,
    TipoCostoVariable? tipo,
    String? nombre,
    double? cantidadUnitaria,
    double? costoUnitario,
    double? costoPorOperacion,
  }) {
    return ItemCostoVariable(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      nombre: nombre ?? this.nombre,
      cantidadUnitaria: cantidadUnitaria ?? this.cantidadUnitaria,
      costoUnitario: costoUnitario ?? this.costoUnitario,
      costoPorOperacion: costoPorOperacion ?? this.costoPorOperacion,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'tipo': tipo.index,
    'nombre': nombre,
    'cantidad_unitaria': cantidadUnitaria,
    'costo_unitario': costoUnitario,
    'costo_por_operacion': costoPorOperacion,
  };

  factory ItemCostoVariable.fromMap(Map<String, dynamic> map) {
    return ItemCostoVariable(
      id: map['id'] as String,
      tipo: TipoCostoVariable.values[map['tipo'] as int],
      nombre: map['nombre'] as String,
      cantidadUnitaria: (map['cantidad_unitaria'] as num).toDouble(),
      costoUnitario: (map['costo_unitario'] as num).toDouble(),
      costoPorOperacion: (map['costo_por_operacion'] as num).toDouble(),
    );
  }
}

enum TipoCostoVariable {
  materiaPrima,
  manoObra,
  cargosIndirectos,
}

/// Costos variables agregados para un periodo específico.
/// 
/// Incluye cálculo con inflación compuesta:
/// costoPeriodoN = costoBase × (1 + inflacion)^(mesesPeriodo/12 × (N-1))
class CostoVariablePeriodo {
  final int periodo;                    // 1, 2, 3... N
  final List<ItemCostoVariable> items;  // Items de las 3 categorías
  final double inflacionAnualPct;       // Ej: 5.0 para 5%
  final int mesesPorPeriodo;            // Del ConfiguracionTemporal
  
  CostoVariablePeriodo({
    required this.periodo,
    required this.items,
    required this.inflacionAnualPct,
    required this.mesesPorPeriodo,
  });

  /// Suma de costos base (sin inflación) de todos los items
  double get costoBase => items.fold(0.0, (sum, item) => sum + item.costoTotal);

  /// Factor de inflación compuesta para este periodo
  /// Periodo 1: factor = 1.0
  /// Periodo 2: factor = (1 + i)^(meses/12)
  /// Periodo N: factor = (1 + i)^(meses/12 × (N-1))
  double get factorInflacion {
    if (periodo <= 1) return 1.0;
    final i = inflacionAnualPct / 100.0;
    final exponente = (mesesPorPeriodo / 12) * (periodo - 1);
    return math.pow(1 + i, exponente).toDouble();
  }

  /// Costo unitario del periodo CON inflación aplicada
  double get costoConInflacion => costoBase * factorInflacion;

  /// Desglose por categoría (sin inflación)
  double get subtotalMateriaPrima => items
      .where((i) => i.tipo == TipoCostoVariable.materiaPrima)
      .fold(0.0, (sum, item) => sum + item.costoTotal);
  
  double get subtotalManoObra => items
      .where((i) => i.tipo == TipoCostoVariable.manoObra)
      .fold(0.0, (sum, item) => sum + item.costoTotal);
  
  double get subtotalCargosIndirectos => items
      .where((i) => i.tipo == TipoCostoVariable.cargosIndirectos)
      .fold(0.0, (sum, item) => sum + item.costoTotal);

  CostoVariablePeriodo copyWith({
    int? periodo,
    List<ItemCostoVariable>? items,
    double? inflacionAnualPct,
    int? mesesPorPeriodo,
  }) {
    return CostoVariablePeriodo(
      periodo: periodo ?? this.periodo,
      items: items ?? this.items,
      inflacionAnualPct: inflacionAnualPct ?? this.inflacionAnualPct,
      mesesPorPeriodo: mesesPorPeriodo ?? this.mesesPorPeriodo,
    );
  }

  Map<String, dynamic> toMap() => {
    'periodo': periodo,
    'items': items.map((e) => e.toMap()).toList(),
    'inflacion_anual_pct': inflacionAnualPct,
    'meses_por_periodo': mesesPorPeriodo,
    'costo_base': costoBase,
    'factor_inflacion': factorInflacion,
    'costo_con_inflacion': costoConInflacion,
  };
}