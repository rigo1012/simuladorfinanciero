/// Ingreso estimado para un periodo específico.
/// 
/// Ingreso = Precio × Demanda (calculado automáticamente).
class IngresoPeriodo {
  final int periodo;        // 1, 2, 3... N (índice del periodo)
  final double precio;      // Precio unitario del producto
  final double demanda;     // Cantidad demandada (unidades)
  
  IngresoPeriodo({
    required this.periodo,
    required this.precio,
    required this.demanda,
  });

  /// Ingreso total del periodo = Precio × Demanda
  double get ingreso => precio * demanda;

  IngresoPeriodo copyWith({
    int? periodo,
    double? precio,
    double? demanda,
  }) {
    return IngresoPeriodo(
      periodo: periodo ?? this.periodo,
      precio: precio ?? this.precio,
      demanda: demanda ?? this.demanda,
    );
  }

  Map<String, dynamic> toMap() => {
    'periodo': periodo,
    'precio': precio,
    'demanda': demanda,
    'ingreso': ingreso,
  };

  factory IngresoPeriodo.fromMap(Map<String, dynamic> map) {
    return IngresoPeriodo(
      periodo: map['periodo'] as int,
      precio: (map['precio'] as num).toDouble(),
      demanda: (map['demanda'] as num).toDouble(),
    );
  }

  @override
  String toString() => 'IngresoPeriodo(p$periodo: \$${precio.toStringAsFixed(2)} × ${demanda.toStringAsFixed(0)} = \$${ingreso.toStringAsFixed(2)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngresoPeriodo &&
          periodo == other.periodo &&
          precio == other.precio &&
          demanda == other.demanda;

  @override
  int get hashCode => periodo.hashCode ^ precio.hashCode ^ demanda.hashCode;
}