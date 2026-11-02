/// Ingreso estimado para un periodo específico.
/// 
/// Ingreso = Precio × Demanda (calculado automáticamente).
class IngresoPeriodo {
  final int periodo;        // 1, 2, 3... N (índice del periodo)
  final double precio;      // Precio unitario del producto
  final double demanda;     // Cantidad demandada (unidades)

  /// Ingresos adicionales del periodo (ej. ahorro de agua). Opcional.
  final double otrosIngresos;

  IngresoPeriodo({
    required this.periodo,
    required this.precio,
    required this.demanda,
    this.otrosIngresos = 0,
  });

  /// Ingreso total del periodo = Precio × Demanda + otros ingresos
  double get ingreso => precio * demanda + otrosIngresos;

  IngresoPeriodo copyWith({
    int? periodo,
    double? precio,
    double? demanda,
    double? otrosIngresos,
  }) {
    return IngresoPeriodo(
      periodo: periodo ?? this.periodo,
      precio: precio ?? this.precio,
      demanda: demanda ?? this.demanda,
      otrosIngresos: otrosIngresos ?? this.otrosIngresos,
    );
  }

  Map<String, dynamic> toMap() => {
    'periodo': periodo,
    'precio': precio,
    'demanda': demanda,
    'otros_ingresos': otrosIngresos,
    'ingreso': ingreso,
  };

  factory IngresoPeriodo.fromMap(Map<String, dynamic> map) {
    return IngresoPeriodo(
      periodo: (map['periodo'] as num).toInt(),
      precio: (map['precio'] as num).toDouble(),
      demanda: (map['demanda'] as num).toDouble(),
      otrosIngresos: (map['otros_ingresos'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  String toString() => 'IngresoPeriodo(p$periodo: \$${precio.toStringAsFixed(2)} × ${demanda.toStringAsFixed(0)} + \$${otrosIngresos.toStringAsFixed(2)} = \$${ingreso.toStringAsFixed(2)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngresoPeriodo &&
          periodo == other.periodo &&
          precio == other.precio &&
          demanda == other.demanda &&
          otrosIngresos == other.otrosIngresos;

  @override
  int get hashCode => periodo.hashCode ^ precio.hashCode ^ demanda.hashCode ^ otrosIngresos.hashCode;
}