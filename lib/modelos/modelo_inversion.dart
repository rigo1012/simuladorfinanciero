class Inversion {
  final int? id;
  final double monto;
  final double tasaDescuento;
  final int horizonteAnios;
  final double van; // Nueva propiedad matemática

  Inversion({
    this.id, 
    required this.monto, 
    required this.tasaDescuento, 
    required this.horizonteAnios,
    required this.van, // Propiedad obligatoria
  });

  Map<String, dynamic> aMapa() {
    return {
      'id': id,
      'monto': monto,
      'tasa_descuento': tasaDescuento,
      'horizonte_anios': horizonteAnios,
      'van': van, // Empaquetado para SQLite
    };
  }
}