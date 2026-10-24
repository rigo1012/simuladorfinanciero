/// Configuración temporal base del proyecto.
/// 
/// Define la granularidad del horizonte de evaluación (meses por periodo)
/// y la proyección total en años fiscales con rotación de cultivos.
class ConfiguracionTemporal {
  /// Duración de cada periodo en meses (ej: 1, 3, 4, 6, 8, 12...).
  /// Libre según ciclo del cultivo (rábano ~2-3 meses, cilantro ~1-2 meses).
  final int mesesPorPeriodo;

  /// Años de proyección fiscal (horizonte de evaluación del proyecto).
  /// Estándar: 3-5 años para infraestructura de riego.
  final int anosProyeccion;

  /// Número de cosechas/ciclos por año fiscal.
  /// Permite modelar rotación: ej. 2 ciclos/año en clima templado.
  final int cosechasPorAnio;

  const ConfiguracionTemporal({
    required this.mesesPorPeriodo,
    required this.anosProyeccion,
    required this.cosechasPorAnio,
  });

  /// Total de periodos en el horizonte de evaluación.
  int get totalPeriodos => (anosProyeccion * 12) ~/ mesesPorPeriodo;

  /// Total de meses en el horizonte.
  int get totalMeses => anosProyeccion * 12;

  /// Meses productivos totales (considerando rotación).
  /// Si mesesPorPeriodo=3 y cosechasPorAnio=2 → 6 meses productivos/año.
  int get mesesProductivosTotales => anosProyeccion * cosechasPorAnio * (12 / cosechasPorAnio).round();

  /// Valida que la configuración sea coherente.
  String? validar() {
    if (mesesPorPeriodo < 1) return 'Meses por periodo debe ser ≥ 1';
    if (mesesPorPeriodo > 60) return 'Meses por periodo irreal (> 5 años)';
    if (anosProyeccion < 1) return 'Años de proyección debe ser ≥ 1';
    if (anosProyeccion > 20) return 'Años de proyección irreal (> 20)';
    if (cosechasPorAnio < 1) return 'Cosechas por año debe ser ≥ 1';
    if (cosechasPorAnio > 12) return 'Cosechas por año irreal (> 12)';
    if (totalPeriodos < 1) return 'Configuración genera 0 periodos';
    if (totalPeriodos > 120) return 'Demasiados periodos (> 120), reduce horizonte o aumenta meses/periodo';
    return null;
  }

  Map<String, dynamic> toMap() => {
    'meses_por_periodo': mesesPorPeriodo,
    'anos_proyeccion': anosProyeccion,
    'cosechas_por_anio': cosechasPorAnio,
    'total_periodos': totalPeriodos,
    'total_meses': totalMeses,
  };

  factory ConfiguracionTemporal.fromMap(Map<String, dynamic> map) {
    return ConfiguracionTemporal(
      mesesPorPeriodo: map['meses_por_periodo'] as int,
      anosProyeccion: map['anos_proyeccion'] as int,
      cosechasPorAnio: map['cosechas_por_anio'] as int,
    );
  }

  @override
  String toString() => 'ConfiguracionTemporal(meses/periodo: $mesesPorPeriodo, años: $anosProyeccion, cosechas/año: $cosechasPorAnio, totalPeriodos: $totalPeriodos)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfiguracionTemporal &&
          mesesPorPeriodo == other.mesesPorPeriodo &&
          anosProyeccion == other.anosProyeccion &&
          cosechasPorAnio == other.cosechasPorAnio;

  @override
  int get hashCode => mesesPorPeriodo.hashCode ^ anosProyeccion.hashCode ^ cosechasPorAnio.hashCode;
}

/// Configuraciones predefinidas típicas para referencia rápida.
class ConfiguracionesPredefinidas {
  static final List<ConfiguracionTemporal> comunes = [
    ConfiguracionTemporal(mesesPorPeriodo: 1, anosProyeccion: 5, cosechasPorAnio: 1),  // Mensual, 5 años
    ConfiguracionTemporal(mesesPorPeriodo: 3, anosProyeccion: 5, cosechasPorAnio: 2),  // Trimestral, 2 ciclos/año
    ConfiguracionTemporal(mesesPorPeriodo: 4, anosProyeccion: 5, cosechasPorAnio: 3),  // Cuatrimestral, 3 ciclos
    ConfiguracionTemporal(mesesPorPeriodo: 6, anosProyeccion: 5, cosechasPorAnio: 2),  // Semestral, 2 ciclos
    ConfiguracionTemporal(mesesPorPeriodo: 12, anosProyeccion: 5, cosechasPorAnio: 1), // Anual, 1 ciclo
  ];

  static ConfiguracionTemporal get recomendada => comunes[1]; // Trimestral 5 años
}