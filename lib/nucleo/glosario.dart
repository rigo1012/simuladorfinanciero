/// Término del glosario financiero/agrícola del simulador.
class TerminoGlosario {
  final String nombre;
  final String? abreviatura;
  final String definicion;
  final String comoSeUsa;
  final String? formula;

  const TerminoGlosario({
    required this.nombre,
    this.abreviatura,
    required this.definicion,
    required this.comoSeUsa,
    this.formula,
  });
}

/// Glosario centralizado de términos usados en la aplicación y el reporte.
class Glosario {
  const Glosario._();

  static const Map<String, TerminoGlosario> terminos = {
    'trema': TerminoGlosario(
      nombre: 'Tasa Mínima de Rentabilidad Esperada',
      abreviatura: 'TREMA',
      definicion:
          'Rentabilidad mínima que el inversionista exige al proyecto, expresada como tasa anual.',
      comoSeUsa:
          'Se captura en el Paso 6 y sirve para descontar los flujos de caja al valuar el proyecto.',
    ),
    'vpn': TerminoGlosario(
      nombre: 'Valor Presente Neto',
      abreviatura: 'VPN',
      definicion:
          'Diferencia entre el valor presente de los flujos de caja y la inversión inicial.',
      comoSeUsa:
          'Se calcula en Resultados; un VPN positivo indica que el proyecto crea valor a la TREMA exigida.',
      formula: 'VPN = Σ F_t / (1 + r)^t',
    ),
    'tir': TerminoGlosario(
      nombre: 'Tasa Interna de Retorno',
      abreviatura: 'TIR',
      definicion:
          'Tasa de descuento que hace que el Valor Presente Neto del proyecto sea igual a cero.',
      comoSeUsa:
          'Se calcula por periodo y se muestra anual efectiva para compararla con la TREMA anual.',
      formula: 'TIR anual = (1 + TIR del periodo)^(12 / meses por periodo) − 1',
    ),
    'beneficio_costo': TerminoGlosario(
      nombre: 'Relación Beneficio/Costo',
      abreviatura: 'B/C',
      definicion:
          'Cociente entre el valor presente de los beneficios y el valor presente de los costos.',
      comoSeUsa:
          'Se muestra en Resultados; un valor mayor que uno indica que los beneficios descontados superan a los costos.',
      formula: 'B/C = VP(beneficios) / VP(costos)',
    ),
    'payback_simple': TerminoGlosario(
      nombre: 'Payback simple',
      definicion:
          'Número de periodos necesarios para que la suma de los flujos de caja iguale la inversión inicial.',
      comoSeUsa:
          'Se reporta en periodos y en años; no considera el valor del dinero en el tiempo.',
    ),
    'payback_descontado': TerminoGlosario(
      nombre: 'Payback descontado',
      definicion:
          'Número de periodos necesarios para que el valor presente acumulado de los flujos iguale la inversión inicial.',
      comoSeUsa:
          'Se reporta en periodos y en años; considera la tasa de descuento del proyecto.',
    ),
    'ebitda': TerminoGlosario(
      nombre: 'Utilidad antes de intereses, impuestos, depreciación y amortización',
      abreviatura: 'EBITDA',
      definicion:
          'Resultado operativo que resta a los ingresos los costos variables y fijos, sin considerar intereses ni impuestos.',
      comoSeUsa:
          'Aparece en la tabla de flujo de caja y en los indicadores operativos.',
      formula: 'EBITDA = Ingresos − Costos variables − Costos fijos',
    ),
    'uai': TerminoGlosario(
      nombre: 'Utilidad antes de impuestos',
      abreviatura: 'UAI',
      definicion:
          'Resultado que se obtiene después de restar los intereses al EBITDA.',
      comoSeUsa:
          'Es la base para calcular el ISR del periodo en la tabla de flujo de caja.',
      formula: 'UAI = EBITDA − Intereses',
    ),
    'isr': TerminoGlosario(
      nombre: 'Impuesto sobre la Renta',
      abreviatura: 'ISR',
      definicion:
          'Impuesto que se aplica a la utilidad fiscal del periodo después de considerar la depreciación.',
      comoSeUsa:
          'El usuario captura la tasa en el Paso 6; el simulador calcula el impuesto de cada periodo.',
      formula: 'ISR = máx(0, UAI − Depreciación) × tasa de ISR',
    ),
    'depreciacion': TerminoGlosario(
      nombre: 'Depreciación',
      definicion:
          'Asignación del costo de un activo depreciable a lo largo de su vida útil.',
      comoSeUsa:
          'Se calcula de forma lineal por periodo y reduce la base del ISR; no es una salida de efectivo.',
      formula: 'Depreciación = costo total / (vida útil en años × 12 / meses por periodo)',
    ),
    'vida_util': TerminoGlosario(
      nombre: 'Vida útil',
      definicion:
          'Número de años durante los cuales se espera utilizar un activo depreciable.',
      comoSeUsa:
          'Se captura en el Paso 1 para cada activo marcado como depreciable.',
    ),
    'valor_residual': TerminoGlosario(
      nombre: 'Valor residual',
      definicion:
          'Valor que se recupera de los activos al final del horizonte de evaluación.',
      comoSeUsa:
          'Se suma al flujo del último periodo. El usuario define el porcentaje para activos depreciables.',
      formula: 'Valor residual = activos depreciables × % capturado + activos no depreciables × 100 %',
    ),
    'sistema_frances': TerminoGlosario(
      nombre: 'Sistema francés',
      definicion:
          'Forma de amortizar un crédito con cuotas periódicas fijas que incluyen interés y capital.',
      comoSeUsa:
          'Se usa en el Paso 2 para calcular la cuota mensual del financiamiento.',
      formula: 'Cuota = P × [i(1+i)^n] / [(1+i)^n − 1]',
    ),
    'amortizacion_capital': TerminoGlosario(
      nombre: 'Amortización de capital',
      definicion:
          'Parte de la cuota del crédito que reduce el saldo del principal.',
      comoSeUsa:
          'Se registra como salida en el flujo de caja del periodo.',
    ),
    'interes': TerminoGlosario(
      nombre: 'Interés',
      definicion:
          'Costo financiero que se paga por el uso del crédito durante un periodo.',
      comoSeUsa:
          'Se resta en la UAI y se incluye en la relación Beneficio/Costo con financiamiento.',
    ),
    'saldo_insoluto': TerminoGlosario(
      nombre: 'Saldo insoluto',
      definicion:
          'Monto del capital del crédito que aún queda por pagar en un momento dado.',
      comoSeUsa:
          'Se muestra en la tabla de amortización y puede liquidarse en el último periodo del horizonte.',
    ),
    'inflacion': TerminoGlosario(
      nombre: 'Inflación',
      definicion:
          'Aumento general de precios que reduce el poder adquisitivo del dinero con el tiempo.',
      comoSeUsa:
          'El usuario captura una tasa anual para actualizar costos variables y fijos cuando corresponda.',
      formula: 'Costo del periodo = costo base × (1 + i)^(meses por periodo / 12 × (periodo − 1))',
    ),
    'costos_variables': TerminoGlosario(
      nombre: 'Costos variables',
      definicion:
          'Costos que cambian en proporción al nivel de producción o de actividad.',
      comoSeUsa:
          'Se capturan por periodo en el Paso 4, separados en tres categorías.',
    ),
    'costos_fijos': TerminoGlosario(
      nombre: 'Costos fijos',
      definicion:
          'Costos que no dependen del volumen de producción dentro del horizonte evaluado.',
      comoSeUsa:
          'Se capturan por periodo en el Paso 5 y pueden llevar inflación por ítem.',
    ),
    'materia_prima': TerminoGlosario(
      nombre: 'Materia prima',
      definicion:
          'Insumos físicos que se consumen en el proceso productivo.',
      comoSeUsa:
          'Es una de las tres categorías de costos variables del Paso 4.',
    ),
    'mano_obra': TerminoGlosario(
      nombre: 'Mano de obra',
      definicion:
          'Costo del trabajo humano necesario para realizar las operaciones productivas.',
      comoSeUsa:
          'Es una de las tres categorías de costos variables del Paso 4.',
    ),
    'cargos_indirectos': TerminoGlosario(
      nombre: 'Cargos indirectos',
      definicion:
          'Costos de producción que no se identifican directamente con un producto o insumo específico.',
      comoSeUsa:
          'Es una de las tres categorías de costos variables del Paso 4.',
    ),
    'periodo': TerminoGlosario(
      nombre: 'Periodo',
      definicion:
          'Intervalo de tiempo en el que se agrupan ingresos, costos y flujos de caja.',
      comoSeUsa:
          'Su duración en meses se define en el Paso 0 y determina el número total de periodos.',
    ),
    'ciclos_por_anio': TerminoGlosario(
      nombre: 'Ciclos por año',
      definicion:
          'Cantidad de ciclos productivos que se realizan en un año.',
      comoSeUsa:
          'Se captura en el Paso 0 y se usa para distribuir las cosechas entre periodos.',
    ),
    'horizonte': TerminoGlosario(
      nombre: 'Horizonte de evaluación',
      definicion:
          'Número de años que abarca la evaluación financiera del proyecto.',
      comoSeUsa:
          'Se captura en el Paso 6 y no puede exceder los años de proyección configurados.',
    ),
    'tasa_periodo': TerminoGlosario(
      nombre: 'Tasa por periodo',
      definicion:
          'Tasa de descuento equivalente a la TREMA anual para la duración de un periodo.',
      comoSeUsa:
          'Se usa internamente para descontar flujos cuando los periodos no son anuales.',
      formula: 'r = (1 + TREMA anual)^(meses por periodo / 12) − 1',
    ),
    'ahorro_agua': TerminoGlosario(
      nombre: 'Ahorro de agua',
      definicion:
          'Volumen de agua que se deja de consumir por ciclo gracias al sistema de riego.',
      comoSeUsa:
          'Se captura en la calculadora de beneficios y se convierte en un ingreso adicional.',
      formula: 'Ingreso por agua = ahorro de agua del periodo × costo del agua',
    ),
    'otros_ingresos': TerminoGlosario(
      nombre: 'Otros ingresos',
      definicion:
          'Ingresos distintos de la venta del producto principal.',
      comoSeUsa:
          'Se suman al ingreso del periodo; por ejemplo, el ahorro de agua valorizado.',
      formula: 'Ingreso del periodo = Precio × Demanda + Otros ingresos',
    ),
    'capital_propio': TerminoGlosario(
      nombre: 'Capital propio',
      definicion:
          'Parte de la inversión que aporta el inversionista con recursos propios.',
      comoSeUsa:
          'Se define como porcentaje en el Paso 2 y determina el aporte inicial del flujo de caja.',
    ),
    'deuda': TerminoGlosario(
      nombre: 'Deuda',
      definicion:
          'Parte de la inversión que se financia con un crédito y debe devolverse con intereses.',
      comoSeUsa:
          'Se define como porcentaje en el Paso 2; si es mayor que cero, se solicitan tasa y plazo.',
    ),
    'roi': TerminoGlosario(
      nombre: 'Retorno sobre la inversión',
      abreviatura: 'ROI',
      definicion:
          'Relación entre el valor generado por el proyecto y el monto invertido.',
      comoSeUsa:
          'Se muestra en los indicadores de Resultados, calculado sobre la inversión y sobre el aporte propio.',
      formula: 'ROI = VPN / inversión × 100',
    ),
    'calculadora_beneficios': TerminoGlosario(
      nombre: 'Calculadora de beneficios',
      definicion:
          'Herramienta que estima los ingresos por periodo a partir de datos agronómicos y de precio.',
      comoSeUsa:
          'Se abre desde el Paso 3; genera los ingresos de todos los periodos y el resultado queda editable.',
    ),
  };

  static TerminoGlosario? buscar(String clave) => terminos[clave];

  static List<TerminoGlosario> get lista => terminos.values.toList();
}
