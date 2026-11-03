# Documentación Técnica del Software

## Simulador Financiero para Sistemas de Riego por Goteo

**Versión del software:** 1.0.0+1  
**Fecha del documento:** noviembre de 2026  
**Autor:** Rodrigo Domingo Hernandez  
**Titular de los derechos patrimoniales:** Instituto Tecnológico Superior de Teziutlán (ITST)  
**Institución:** Instituto Tecnológico Superior de Teziutlán (ITST)  
**Proyecto:** Servicio Social, Tlatlauquitepec, Puebla  
**Contacto:** l22te0414@teziutlan.tecnm.mx

---

## Índice

1. [Introducción](#1-introducción)
2. [Alcance funcional](#2-alcance-funcional)
3. [Requisitos e instalación](#3-requisitos-e-instalación)
4. [Arquitectura del software](#4-arquitectura-del-software)
5. [Estructura del repositorio](#5-estructura-del-repositorio)
6. [Modelo de datos](#6-modelo-de-datos)
7. [Controlador de estado](#7-controlador-de-estado)
8. [Servicios de cálculo y reportes](#8-servicios-de-cálculo-y-reportes)
9. [Fórmulas y reglas de cálculo](#9-fórmulas-y-reglas-de-cálculo)
10. [Persistencia y proyectos](#10-persistencia-y-proyectos)
11. [Vistas y navegación](#11-vistas-y-navegación)
12. [Validaciones y reglas de negocio](#12-validaciones-y-reglas-de-negocio)
13. [Construcción y distribución](#13-construcción-y-distribución)
14. [Pruebas automatizadas](#14-pruebas-automatizadas)
15. [Glosario](#15-glosario)
16. [Limitaciones conocidas](#16-limitaciones-conocidas)
17. [Mantenimiento y extensión](#17-mantenimiento-y-extensión)
18. [Licencia y autoría](#18-licencia-y-autoría)

---

## 1. Introducción

El **Simulador Financiero para Sistemas de Riego por Goteo** es una aplicación de escritorio
desarrollada en Dart/Flutter para evaluar la rentabilidad de proyectos de riego con sensores en
microparcelas de hortalizas. El software captura los datos del proyecto, construye el flujo de
caja por periodo, calcula indicadores financieros y genera un reporte PDF.

El diseño sigue una regla central: **el simulador no incluye valores predeterminados**. Todos los
datos financieros, agronómicos y de configuración los captura el usuario; el código solo contiene
valores por defecto para compatibilidad de deserialización, nunca como valores iniciales visibles.

El software no sustituye un estudio financiero profesional: los resultados dependen directamente
de la información capturada.

## 2. Alcance funcional

Incluye:

- Configuración temporal del proyecto (meses por periodo, años de proyección y ciclos por año).
- Registro de activos e inversión requerida, con decisión explícita de depreciación y vida útil.
- Estructura de financiamiento (capital propio/deuda, tasa y plazo; sistema francés).
- Ingresos estimados por periodo, con calculadora de beneficios agrícolas y ahorro de agua.
- Costos variables en tres categorías e inflación compuesta.
- Costos fijos por periodo con inflación opcional por ítem.
- Parámetros de evaluación: TREMA, horizonte, ISR y valor residual.
- VPN, VPN operativo, TIR anual efectiva, payback simple/descontado, B/C y KPIs.
- ISR y depreciación lineal.
- Guardado, listado, apertura y eliminación de proyectos completos.
- Reporte PDF con autoguardado y visor de documentos generados.
- Glosario y ayuda contextual integrados.

No incluye importación/exportación de proyectos a archivos externos ni conexión a servicios en la
nube.

## 3. Requisitos e instalación

### Requisitos

| Componente | Requisito |
|---|---|
| Sistema operativo | Windows 10/11; macOS o Linux de escritorio si se compila desde código |
| Flutter SDK | 3.10 o superior |
| Dart | 3.10 o superior |
| Memoria RAM | 4 GB (8 GB recomendado) |
| Espacio en disco | 500 MB |
| Resolución mínima | 1366 × 768 |
| Permisos | Escritura en la carpeta del usuario (SQLite y PDF) |

### Ejecución desde código fuente

```bash
git clone https://github.com/rigo1012/simuladorfinanciero.git
cd simuladorfinanciero
flutter pub get
flutter run -d windows
```

### Compilación de la versión Windows

```bash
flutter build windows --release
```

Salida: `build/windows/x64/runner/Release/simuladorfinanciero.exe`.

La aplicación se distribuye como **carpeta completa** con el ejecutable y sus archivos de apoyo;
el `.exe` no funciona de forma aislada.

## 4. Arquitectura del software

La aplicación usa una arquitectura en capas dentro de un único proyecto Flutter:

```
┌──────────────────────────────────────────────┐
│ Vistas (lib/vistas)                          │
│  DisenoEscritorio, formulario, dashboard,    │
│  resultados, widgets de ayuda y glosario     │
└──────────────────────┬───────────────────────┘
                       │ provider / notifyListeners
┌──────────────────────▼───────────────────────┐
│ Controlador (lib/controladores)              │
│  ProveedorSimulador (ChangeNotifier)         │
│  Estado, validaciones y orquestación         │
└───────────────┬──────────────────┬───────────┘
                │                  │
┌───────────────▼──────────┐  ┌────▼────────────────┐
│ Servicios (lib/servicios)│  │ Núcleo (lib/nucleo) │
│  motor_fen               │  │  dbayuda (SQLite)   │
│  evaluador_financiero    │  │  glosario           │
│  reporte_pdf             │  └─────────────────────┘
└───────────────┬──────────┘
                │
┌───────────────▼──────────────────────────────┐
│ Modelos (lib/modelos)                        │
│  Entidades serializables del dominio         │
└──────────────────────────────────────────────┘
```

- **Estado:** un único `ProveedorSimulador` se crea arriba de `MaterialApp` y se comparte con
  `provider`.
- **Navegación:** `DisenoEscritorio` contiene tres pestañas en un `IndexedStack`; los pasos 0 a 6
  son secciones internas de la pestaña Inversión.
- **Cálculo:** el motor FEN produce los flujos; el evaluador calcula indicadores; el reporte PDF
  consume el resultado.
- **Persistencia:** SQLite local mediante `sqflite_common_ffi`.

## 5. Estructura del repositorio

```
lib/
├── main.dart                  # main() async, tema, provider, ruta de BD
├── controladores/
│   └── proveedor_simulador.dart
├── modelos/
│   ├── activo.dart
│   ├── configuracion_temporal.dart
│   ├── ingreso_periodo.dart
│   ├── costo_variable.dart
│   ├── costo_fijo.dart
│   ├── estructura_capital.dart
│   └── modelo_inversion.dart
├── nucleo/
│   ├── dbayuda.dart           # SQLite, migraciones y proyectos
│   └── glosario.dart          # Términos y definiciones
├── servicios/
│   ├── motor_fen.dart
│   ├── evaluador_financiero.dart
│   └── reporte_pdf.dart
└── vistas/
    ├── diseno_escritorio.dart
    ├── vista_formulario_inversion.dart
    ├── vista_config_temporal.dart
    ├── seccion_activos.dart
    ├── vista_financiamiento.dart
    ├── seccion_ingresos.dart
    ├── seccion_costos_variables.dart
    ├── seccion_costos_fijos.dart
    ├── vista_resultados.dart
    ├── vista_dashboard.dart
    ├── ayuda_concepto.dart
    └── pantalla_glosario.dart
test/                          # Pruebas automatizadas
windows/ linux/ macos/         # Proyectos nativos
```

## 6. Modelo de datos

Todos los modelos usan nombres en español y serialización con `toMap()`/`fromMap()`. Los `fromMap`
aplican casteo numérico seguro (`as num`, `as num?`) para tolerar enteros o decimales provenientes
de JSON o SQLite.

### 6.1 `Activo`

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | `String` | Identificador |
| `nombre` | `String` | Nombre libre |
| `unidades` | `int` | Cantidad |
| `costoUnitario` | `double` | Costo por unidad |
| `depreciable` | `bool?` | `null` si no se ha definido |
| `vidaUtilAnios` | `int?` | Obligatoria solo si es depreciable |

Derivado: `costoTotal = unidades × costoUnitario`.

### 6.2 `ConfiguracionTemporal`

| Campo | Tipo |
|---|---|
| `mesesPorPeriodo` | `int` |
| `anosProyeccion` | `int` |
| `cosechasPorAnio` | `int` |

Derivados: `totalPeriodos = (anosProyeccion × 12) ~/ mesesPorPeriodo`, `totalMeses`.
`validar()` comprueba rangos y coherencia.

### 6.3 `IngresoPeriodo`

| Campo | Tipo |
|---|---|
| `periodo` | `int` |
| `precio` | `double` |
| `demanda` | `double` |
| `otrosIngresos` | `double` (opcional, default 0) |

Derivado: `ingreso = precio × demanda + otrosIngresos`.

### 6.4 Costos variables

`ItemCostoVariable`: `id`, `tipo` (`materiaPrima`, `manoObra`, `cargosIndirectos`), `nombre`,
`cantidadUnitaria`, `costoUnitario`, `costoPorOperacion`.

`CostoVariablePeriodo`: `periodo`, `items`, `inflacionAnualPct`, `mesesPorPeriodo`.
Derivados: `costoBase`, `factorInflacion`, `costoConInflacion` y subtotales por categoría.

### 6.5 Costos fijos

`ItemCostoFijo`: `id`, `nombre`, `monto`, `aplicarInflacion`.

`CostoFijoPeriodo`: `periodo`, `items`, `inflacionAnualPct`, `mesesPorPeriodo`.
Derivados: `totalBase`, `totalConInflacion`.

### 6.6 `EstructuraCapital`

| Campo | Tipo |
|---|---|
| `pctPropio` | `double` |
| `pctDeuda` | `double` |
| `tasaInteresAnual` | `double?` |
| `plazoMeses` | `int?` |
| `inversionRequerida` | `double` |

Derivados: `montoPrestamo`, `aportePropio`, `tasaMensual`, `cuotaMensual`, `tieneDeuda`,
`generarTablaAmortizacion()`, `resumenPorPeriodos()` y `saldoInsolutoEnPeriodo()`.

### 6.7 `Inversion` (historial)

Registro simple para la tabla `inversion`: `id?`, `monto`, `tasaDescuento`, `horizonteAnios`, `van`.

## 7. Controlador de estado

`ProveedorSimulador` extiende `ChangeNotifier` y concentra el estado del proyecto. Métodos
principales:

| Método | Función |
|---|---|
| `configurarTemporal(config)` | Fija la configuración y reinicia datos dependientes |
| `configurarFinanciamiento(estructura)` | Fija el financiamiento y reinicia datos posteriores |
| `agregarActivo` / `actualizarActivo` / `eliminarActivo` | CRUD de activos |
| `actualizarIngreso` / `eliminarIngreso` / `limpiarIngresos` | CRUD de ingresos |
| `agregarItemCostoVariable` / `actualizarItemCostoVariable` / `eliminarItemCostoVariable` | CRUD de costos variables |
| `agregarItemCostoFijo` / `actualizarItemCostoFijo` / `eliminarItemCostoFijo` | CRUD de costos fijos |
| `setInflacionGlobalFijos` | Inflación de referencia de costos fijos |
| `setTasaImpuestoPct` / `setValorResidualPct` | Parámetros del Paso 6 |
| `procesarSimulacionSimple(tasaPct, anios)` | Valida, calcula y guarda el historial |
| `exportarSesion()` | Serializa todo el proyecto |
| `cargarProyectoCompleto(json)` | Carga atómica y validada de un proyecto |
| `guardarProyectoActual(nombre)` | Guarda el proyecto en SQLite |
| `cargarProyectosGuardados()` | Lista metadatos de proyectos |
| `cargarProyectoJsonPorId(id)` | Obtiene el JSON de un proyecto |
| `eliminarProyectoGuardado(id)` | Elimina un proyecto |
| `cargarHistorial()` / `eliminarSimulacion(id)` | Historial de simulaciones |

Propiedades de solo lectura: `configTemporal`, `inversionRequerida`, `estructuraCapital`,
`ingresos`, `costosVariables`, `costosFijos`, `inflacionGlobalFijos`, `ultimaTREMA`,
`ultimoHorizonte`, `tasaImpuestoPct`, `valorResidualPct`, `ultimoResultado`, `error`,
`estaCargando`, `puedeDescargarPDF`, `historialInversiones`, `proyectosGuardados`.

La carga de proyecto **no** usa `configurarTemporal` ni `configurarFinanciamiento`, porque esos
métodos reinician datos. `cargarProyectoCompleto` asigna directamente los campos privados después
de validar todo en variables locales, ordena las listas por periodo y notifica una sola vez.

## 8. Servicios de cálculo y reportes

### `motor_fen.dart`

Construye `FlujoPeriodo` para el periodo 0 y 1..N. Cada flujo contiene: ingreso, costo variable,
costo fijo, interés, amortización de capital, liquidación de saldo, depreciación, ISR, ISR
operativo, valor residual e inversión inicial.

`FlujoPeriodo` expone getters: `ebitda`, `uai`, `flujoCaja`, `flujoOperativo` y `toMap()`.

`MotorFEN.calcular(...)` recibe el proveedor, TREMA anual, horizonte, fracción de valor residual y
tasa de ISR. Calcula depreciación, impuestos, valor residual y flujos.

### `evaluador_financiero.dart`

`EvaluadorFinanciero.evaluar(motor)` devuelve `ResultadoEvaluacion` con:

- VPN y VPN operativo.
- TIR y TIR operativa (anual efectiva).
- Payback simple y descontado (periodos).
- B/C y B/C operativo.
- Veredicto y KPIs.

La TIR se resuelve por periodo con Newton-Raphson y, si no converge, bisección en `[-0.99, 10]`.
Se anualiza con `(1 + TIRperiodo)^(12/m) − 1`.

### `reporte_pdf.dart`

- `generar(...)`: construye el PDF.
- `guardarEnDocumentos(...)`: guarda una copia y devuelve la ruta absoluta.
- `guardarEImprimir(...)`: guarda y abre el diálogo de impresión.
- `imprimir(...)`: abre el diálogo con bytes ya generados.
- `documentosGenerados()`: lista los PDF `Evaluacion_*.pdf`.
- `abrirRuta(...)` / `abrirCarpetaDocumentos()`: abren archivos o la carpeta.

El PDF incluye: resumen ejecutivo, configuración, estructura de capital, indicadores, flujo de caja
con depreciación e impuestos, amortización, sensibilidad y apéndice de glosario.

## 9. Fórmulas y reglas de cálculo

Con `m` = meses por periodo, `N` = periodos del horizonte y TREMA anual en decimal:

**Tasa por periodo**

```
r = (1 + TREMA)^(m / 12) − 1
```

**VPN**

```
VPN = Σ F_t / (1 + r)^t,  t = 0..N
F_0 = −aporte propio
```

**TIR**

```
TIR anual = (1 + TIR_periodo)^(12 / m) − 1
```

**Depreciación**

```
depreciación = costo del activo / (vida útil años × 12 / m)
```

Se aplica mientras el periodo esté dentro de la vida útil.

**ISR**

```
UAI = EBITDA − intereses
ISR = max(0, UAI − depreciación) × tasa ISR
```

**Flujo de caja**

```
F_t = UAI − ISR − amortización de capital − liquidación de saldo + valor residual
```

**Flujo operativo**

```
F_t operativo = EBITDA − ISR operativo
ISR operativo = max(0, EBITDA − depreciación) × tasa ISR
```

**Valor residual** (solo último periodo del horizonte)

```
VR = Σ costo(activos depreciables) × %residual
   + Σ costo(activos no depreciables) × 100 %
```

**B/C**

```
B/C = VP(ingresos + valor residual) /
      (inversión inicial + VP(costos variables + costos fijos + impuestos [+ intereses]))
```

La versión operativa excluye intereses y usa el ISR operativo.

**Payback**

- Simple: primer periodo con flujo acumulado ≥ 0.
- Descontado: primer periodo con VPN acumulado ≥ 0.
- Se reporta en periodos y años con interpolación lineal: `años = periodos × m / 12`.

**Sensibilidad**

El PDF recalcula el VPN con TREMA al 50 %, 75 %, 100 %, 125 % y 150 %, convirtiendo cada tasa anual
a la tasa equivalente del periodo.

## 10. Persistencia y proyectos

### 10.1 Ruta de la base de datos

`main()` obtiene la carpeta de soporte con `getApplicationSupportDirectory()` y ejecuta
`databaseFactory.setDatabasesPath(...)`. `dbayuda.dart` usa `getDatabasesPath()` y forma
`simulador_riego.db`.

En Windows:

```
%APPDATA%\ITST\Simulador Financiero para Sistemas de Riego\simulador_riego.db
```

La carpeta se deriva de `CompanyName` y `ProductName` en `windows/runner/Runner.rc`.

### 10.2 Esquema SQLite (versión 4)

`inversion`

| Columna | Tipo |
|---|---|
| id | INTEGER PK AUTOINCREMENT |
| monto | REAL NOT NULL |
| tasa_descuento | REAL NOT NULL |
| horizonte_anios | INTEGER NOT NULL |
| van | REAL NOT NULL |

`sesion_borrador`

| Columna | Tipo |
|---|---|
| id | INTEGER PK AUTOINCREMENT |
| nombre | TEXT NOT NULL |
| configuracion_texto | TEXT NOT NULL |
| activos_texto | TEXT NOT NULL |
| estructura_texto | TEXT NOT NULL |
| proyecto_json | TEXT |
| creado_en | TIMESTAMP DEFAULT CURRENT_TIMESTAMP |

La migración a la versión 4 es no destructiva: usa `CREATE TABLE IF NOT EXISTS` y
`ALTER TABLE ... ADD COLUMN proyecto_json`; conserva la tabla `inversion` y los borradores.

### 10.3 Formato del proyecto (`proyecto_json`)

```json
{
  "version": 1,
  "configuracion": { "meses_por_periodo": 3, "anos_proyeccion": 2, "cosechas_por_anio": 2 },
  "activos": [
    {
      "id": "a1",
      "nombre": "Bomba centrífuga",
      "unidades": 1,
      "costo_unitario": 45000,
      "depreciable": true,
      "vida_util_anios": 10
    }
  ],
  "estructura": {
    "pct_propio": 60,
    "pct_deuda": 40,
    "tasa_interes_anual": 14,
    "plazo_meses": 24,
    "inversion_requerida": 147000
  },
  "ingresos": [
    { "periodo": 1, "precio": 30, "demanda": 1400, "otros_ingresos": 500, "ingreso": 42500 }
  ],
  "costos_variables": [
    {
      "periodo": 1,
      "items": [
        {
          "id": "mp_1",
          "tipo": 0,
          "nombre": "Insumos",
          "cantidad_unitaria": 200,
          "costo_unitario": 15,
          "costo_por_operacion": 0
        }
      ],
      "inflacion_anual_pct": 4,
      "meses_por_periodo": 3
    }
  ],
  "costos_fijos": [
    {
      "periodo": 1,
      "items": [
        { "id": "cf_1", "nombre": "Servicios", "monto": 5000, "aplicar_inflacion": true }
      ],
      "inflacion_anual_pct": 4,
      "meses_por_periodo": 3
    }
  ],
  "inflacion_global_fijos": 4,
  "trema": 12,
  "horizonte": 2,
  "tasa_impuesto_pct": 30,
  "valor_residual_pct": 10
}
```

Los campos `tasa_impuesto_pct` y `valor_residual_pct` pueden ser `null`; en ese caso la simulación
no se ejecuta y se solicita capturarlos.

## 11. Vistas y navegación

### `DisenoEscritorio`

Contiene un `NavigationRail` (o `BottomNavigationBar` en ventanas angostas) y un `IndexedStack` con:

1. **Inversión** — `VistaFormularioInversion`.
2. **Dashboard** — `VistaDashboard`.
3. **Resultados** — `VistaResultados`.

### Pestaña Inversión

`VistaFormularioInversion` es un `Form` con un `ListView` que contiene, en orden:

- Cabecera con **Guardar proyecto**.
- Paso 0: `VistaConfigTemporal`.
- Paso 1: `SeccionActivos`.
- Paso 2: `VistaFinanciamiento`.
- Paso 3: `SeccionIngresos`.
- Paso 4: `SeccionCostosVariables`.
- Paso 5: `SeccionCostosFijos`.
- Paso 6: parámetros de evaluación y botón **Calcular Rentabilidad**.

Todas las secciones están siempre visibles; los mensajes de datos faltantes aparecen al intentar
calcular.

### Pestaña Dashboard

- Historial de simulaciones (`inversion`).
- Proyectos guardados (`sesion_borrador`), con Abrir y Eliminar.
- Botón Glosario.

### Pestaña Resultados

- Resumen y tarjetas KPI.
- Pestañas: Flujo de Caja, Amortización, KPIs Detalle y Sensibilidad. Flujo de Caja y KPIs Detalle
  muestran datos en pantalla; Amortización y Sensibilidad son informativas y su detalle completo se
  incluye en el PDF.
- Botones: Documentos, Exportar PDF y Recalcular.

### Ayuda contextual

`AyudaConcepto(termino: ...)` muestra un `IconButton` con tooltip; al pulsarlo abre un diálogo con
definición, uso y fórmula. Se usa en etiquetas, encabezados y KPIs. El glosario completo está en
`lib/nucleo/glosario.dart` y en `PantallaGlosario`.

## 12. Validaciones y reglas de negocio

Antes de calcular, `procesarSimulacionSimple` exige:

1. Configuración temporal definida.
2. Al menos un activo.
3. Estructura de financiamiento.
4. Ingresos completos en todos los periodos (precio y demanda > 0).
5. Al menos un ítem de costo variable por periodo.
6. Al menos un ítem de costo fijo por periodo.
7. TREMA y horizonte mayores que cero.
8. Tasa de ISR y valor residual capturados (no `null`).
9. Cada activo con `depreciable` definido; si es `true`, con `vidaUtilAnios > 0`.

Si falla una validación, se asigna un mensaje a `error` y no se calcula. Ejemplos:
`Capture la tasa de impuesto en el Paso 6`, `Defina si el activo "..." es depreciable (Paso 1)`.

Reglas adicionales:

- No se usan valores iniciales visibles; los campos inician vacíos.
- Un `0` es válido solo si el usuario lo escribe.
- `cargarProyectoCompleto` valida y reconstruye en variables locales; si algo falla, el estado
  anterior permanece intacto y se informa el error.
- La apertura de un proyecto remonta `DisenoEscritorio` para que todas las vistas lean el estado
  cargado.

## 13. Construcción y distribución

### Dependencias (`pubspec.yaml`)

| Dependencia | Uso |
|---|---|
| `provider` | Estado global |
| `sqflite_common_ffi` | SQLite en escritorio |
| `path` | Rutas |
| `path_provider` | Carpeta de soporte y documentos |
| `pdf` | Generación de PDF |
| `printing` | Impresión/compartición |
| `fl_chart` | Gráficas (declarada) |
| `cupertino_icons` | Iconografía |
| `image: 4.10.0` | Override de compatibilidad |

### Comandos

```bash
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

### Distribución

Copiar la carpeta completa `build/windows/x64/runner/Release/` (ejecutable, DLLs y carpeta
`data/`). No separar el `.exe` de sus archivos de apoyo.

### Metadatos del ejecutable

`windows/runner/Runner.rc`:

- `CompanyName`: ITST.
- `ProductName`: Simulador Financiero para Sistemas de Riego.
- `FileDescription`: Simulador Financiero para Sistemas de Riego.
- `OriginalFilename` e `InternalName` sin cambios.

El título de la ventana se define en `windows/runner/main.cpp`.

## 14. Pruebas automatizadas

| Archivo | Cobertura |
|---|---|
| `test/evaluador_test.dart` | VPN/TIR con TREMA convertida, B/C real, payback fraccionario |
| `test/impuestos_depreciacion_test.dart` | ISR y depreciación verificados a mano, valor residual, validaciones |
| `test/proyecto_test.dart` | Roundtrip exportar/cargar, enteros en JSON, notificación única, JSON inválido |
| `test/migracion_test.dart` | Migración v3→v4 conservando `inversion` y agregando `proyecto_json` |
| `test/glosario_test.dart` | Diálogo de ayuda y definiciones no vacías |
| `test/ingreso_periodo_test.dart` | `otrosIngresos` y compatibilidad de `fromMap` |
| `test/simulacion_completa_test.dart` | Pipeline completo y Motor FEN directo |
| `test/widget_test.dart` | Arranque de la app y campos de configuración |

Comandos:

```bash
flutter test
```

## 15. Glosario

El glosario completo está en `lib/nucleo/glosario.dart` y en la sección 14 del manual de usuario.
Incluye, entre otros: TREMA, tasa por periodo, VPN, TIR, B/C, payback simple/descontado, EBITDA,
UAI, ISR, depreciación, vida útil, valor residual, sistema francés, amortización de capital,
interés, saldo insoluto, inflación, costos variables/fijos, materia prima, mano de obra, cargos
indirectos, periodo, ciclos por año, horizonte, ahorro de agua, otros ingresos, capital propio,
deuda y ROI.

## 16. Limitaciones conocidas

- Solo se modela el ISR; no IVA ni otras contribuciones.
- No se modela capital de trabajo (inventarios, cuentas por cobrar/pagar, efectivo mínimo).
- Depreciación lineal sobre costo original, sin aceleración, prorrateo ni revaluación.
- Si la vida útil en periodos no es entera, queda un remanente sin depreciar.
- No hay traslado de pérdidas fiscales entre periodos.
- El valor residual es un porcentaje capturado para depreciables y el 100 % del costo para no
  depreciables; no es avalúo de mercado.
- Solo sistema francés; tasa mensual nominal (anual/12); sin periodos de gracia, comisiones ni
  seguros.
- Si el plazo del crédito excede el horizonte, el saldo insoluto se liquida en el último periodo,
  sin penalización ni intereses adicionales.
- Inflación solo en costos; los ingresos no se indexan automáticamente (pueden capturarse con
  crecimiento en “Llenar con Patrón”).
- Si se inflan costos, la TREMA debe ser nominal; no hay conversión real/nominal.
- Sensibilidad solo respecto a la TREMA.
- Sin modelo agronómico; los beneficios dependen de los datos capturados.
- Una sola moneda, sin tipo de cambio.
- Periodos en meses enteros y horizonte truncado hacia abajo.
- Proyectos solo en SQLite local; sin importación/exportación a archivos externos.
- Sin atajos de teclado ni menú “Acerca de”.
- Los resultados son estimaciones, no asesoría financiera profesional.

## 17. Mantenimiento y extensión

### Puntos de extensión

- **Nuevos indicadores:** añadir en `evaluador_financiero.dart` y exponerlos en
  `ResultadoEvaluacion.toMap()` y en las vistas.
- **Nuevos costos o activos:** ampliar los modelos y los formularios; actualizar `fromMap` y
  `toMap` con casteo seguro.
- **Nuevas reglas fiscales:** modificar `MotorFEN.calcular` y documentar la limitación.
- **Nuevos reportes:** extender `reporte_pdf.dart`; el apéndice del glosario se genera desde
  `Glosario`.
- **Nuevas vistas:** registrar la pestaña en `DisenoEscritorio` y ajustar la navegación.

### Convenciones

- Nombres de dominio en español.
- Modelos serializables con `toMap`/`fromMap`.
- Estado centralizado en `ProveedorSimulador`.
- Sin valores predeterminados visibles.
- Cambios de esquema con migraciones no destructivas y nueva versión de BD.
- Pruebas para cada regla de cálculo o migración.

### Actualización de versión

1. Cambiar `version` en `pubspec.yaml`.
2. Actualizar metadatos en `Runner.rc` si cambia la compañía o el producto.
3. Ejecutar `flutter analyze`, `flutter test` y `flutter build windows --release`.
4. Verificar la ruta de la base y la generación/autoguardado del PDF.
5. Actualizar esta documentación y el manual de usuario.

## 18. Licencia y autoría

**Copyright (c) 2026 Rodrigo Domingo Hernandez / Instituto Tecnológico Superior de Teziutlán (ITST).**
Todos los derechos reservados. Consulta el archivo `LICENSE`.

El manual de usuario se entrega por separado. Esta documentación técnica describe la
implementación del software y no sustituye al manual de operación.
