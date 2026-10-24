import 'dart:math' as math;

/// Costo fijo para un periodo específico.
/// 
/// A diferencia de los variables, son montos planos por periodo
/// (sueldos admin, rentas, seguros). Opcionalmente con inflación.
class CostoFijoPeriodo {
  final int periodo;              // 1, 2, 3... N
  final List<ItemCostoFijo> items;
  final double inflacionAnualPct; // Se aplica si items tienen aplicarInflacion=true
  final int mesesPorPeriodo;

  CostoFijoPeriodo({
    required this.periodo,
    required this.items,
    this.inflacionAnualPct = 0,
    required this.mesesPorPeriodo,
  });

  /// Total del periodo (con inflación donde aplique)
  double get totalConInflacion {
    double total = 0;
    for (final item in items) {
      total += item.costoConInflacion(periodo, mesesPorPeriodo, inflacionAnualPct);
    }
    return total;
  }

  /// Total base (sin inflación)
  double get totalBase => items.fold(0.0, (sum, item) => sum + item.monto);

  CostoFijoPeriodo copyWith({
    int? periodo,
    List<ItemCostoFijo>? items,
    double? inflacionAnualPct,
    int? mesesPorPeriodo,
  }) {
    return CostoFijoPeriodo(
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
    'total_base': totalBase,
    'total_con_inflacion': totalConInflacion,
  };
}

/// Item individual de costo fijo.
class ItemCostoFijo {
  final String id;
  final String nombre;
  final double monto;              // Monto por periodo (base)
  final bool aplicarInflacion;     // Si true, se infla con la tasa global

  ItemCostoFijo({
    required this.id,
    required this.nombre,
    required this.monto,
    this.aplicarInflacion = false,
  });

  /// Costo del item para un periodo específico con inflación opcional
  double costoConInflacion(int periodo, int mesesPorPeriodo, double inflacionAnualPct) {
    if (!aplicarInflacion || periodo <= 1 || inflacionAnualPct <= 0) return monto;
    final i = inflacionAnualPct / 100.0;
    final exponente = (mesesPorPeriodo / 12) * (periodo - 1);
    return monto * math.pow(1 + i, exponente);
  }

  ItemCostoFijo copyWith({
    String? id,
    String? nombre,
    double? monto,
    bool? aplicarInflacion,
  }) {
    return ItemCostoFijo(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      monto: monto ?? this.monto,
      aplicarInflacion: aplicarInflacion ?? this.aplicarInflacion,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'monto': monto,
    'aplicar_inflacion': aplicarInflacion,
  };

  factory ItemCostoFijo.fromMap(Map<String, dynamic> map) {
    return ItemCostoFijo(
      id: map['id'] as String,
      nombre: map['nombre'] as String,
      monto: (map['monto'] as num).toDouble(),
      aplicarInflacion: map['aplicar_inflacion'] as bool? ?? false,
    );
  }
}