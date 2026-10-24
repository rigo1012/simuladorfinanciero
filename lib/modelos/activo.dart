/// Modelo que representa un activo del sistema de riego.
/// 
/// El costo total (unidades × costoUnitario) se calcula internamente
/// y NO se muestra al usuario; solo se expone la suma total como
/// "Inversión Requerida".
class Activo {
  final String id;
  final String nombre;
  final int unidades;
  final double costoUnitario;

  Activo({
    required this.id,
    required this.nombre,
    required this.unidades,
    required this.costoUnitario,
  });

  /// Costo total calculado internamente (no se muestra en UI)
  double get costoTotal => unidades * costoUnitario;

  /// Crea una copia con campos opcionales actualizados
  Activo copyWith({
    String? id,
    String? nombre,
    int? unidades,
    double? costoUnitario,
  }) {
    return Activo(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      unidades: unidades ?? this.unidades,
      costoUnitario: costoUnitario ?? this.costoUnitario,
    );
  }

  /// Serialización para persistencia (JSON/BD)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'unidades': unidades,
      'costo_unitario': costoUnitario,
    };
  }

  factory Activo.fromMap(Map<String, dynamic> map) {
    return Activo(
      id: map['id'] as String,
      nombre: map['nombre'] as String,
      unidades: map['unidades'] as int,
      costoUnitario: (map['costo_unitario'] as num).toDouble(),
    );
  }

  @override
  String toString() => 'Activo(id: $id, nombre: $nombre, unidades: $unidades, costoUnitario: $costoUnitario, costoTotal: $costoTotal)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Activo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nombre == other.nombre &&
          unidades == other.unidades &&
          costoUnitario == other.costoUnitario;

  @override
  int get hashCode => id.hashCode ^ nombre.hashCode ^ unidades.hashCode ^ costoUnitario.hashCode;
}

/// Contenedor de la lista de activos y su suma total (Inversión Requerida)
class InversionRequerida {
  final List<Activo> activos;
  final double total;

  InversionRequerida({
    required this.activos,
    required this.total,
  });

  factory InversionRequerida.vacia() {
    return InversionRequerida(activos: [], total: 0.0);
  }

  factory InversionRequerida.fromActivos(List<Activo> activos) {
    final total = activos.fold<double>(0.0, (sum, a) => sum + a.costoTotal);
    return InversionRequerida(activos: activos, total: total);
  }

  InversionRequerida copyWith({
    List<Activo>? activos,
  }) {
    final newActivos = activos ?? this.activos;
    return InversionRequerida.fromActivos(newActivos);
  }
}