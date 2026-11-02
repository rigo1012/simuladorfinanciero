# Manual de Usuario — Simulador Financiero para Sistemas de Riego por Goteo

**Versión:** 1.0  
**Fecha:** noviembre de 2026  
**Autor(es):** [COMPLETAR: nombre del autor o autores]  
**Institución:** Instituto Tecnológico Superior de Teziutlán (ITST)  
**Proyecto:** Servicio Social — Tlatlauquitepec, Puebla

---

## Descripción técnica

- **Lenguaje y framework:** Dart 3.10+ y Flutter (Material 3), aplicación de escritorio.
- **Arquitectura:** separación en `modelos`, `controladores`, `servicios` y `vistas`.
  - `modelos/`: entidades serializables (activos, configuración temporal, ingresos, costos,
    estructura de capital).
  - `controladores/proveedor_simulador.dart`: estado global con `provider` y `ChangeNotifier`.
  - `servicios/`: `motor_fen` (flujos de caja), `evaluador_financiero` (VPN, TIR, payback, B/C)
    y `reporte_pdf` (reporte y autoguardado).
  - `vistas/`: `DisenoEscritorio` con tres pestañas y las secciones de Inversión.
- **Persistencia:** SQLite local mediante `sqflite_common_ffi` (versión de esquema 4). Guarda el
  historial de simulaciones y los proyectos completos en formato JSON dentro de la base.
- **Dependencias principales:** `provider`, `sqflite_common_ffi`, `path`, `pdf`, `printing`,
  `path_provider`. No se requieren servicios en la nube.
- **Reportes:** PDF generado en el dispositivo y guardado automáticamente en la carpeta de
  Documentos del usuario.
- **Operación:** 100 % local y sin conexión a internet.

---

## Índice

1. [Introducción](#1-introducción)
2. [Requisitos](#2-requisitos)
3. [Instalación y ejecución](#3-instalación-y-ejecución)
4. [Interfaz general](#4-interfaz-general)
5. [Sin valores predeterminados](#5-sin-valores-predeterminados)
6. [Pasos de la pestaña Inversión](#6-pasos-de-la-pestaña-inversión)
7. [Fórmulas financieras](#7-fórmulas-financieras)
8. [Interpretación de resultados](#8-interpretación-de-resultados)
9. [Exportación de PDF y documentos](#9-exportación-de-pdf-y-documentos)
10. [Guardar y abrir proyectos](#10-guardar-y-abrir-proyectos)
11. [Preguntas frecuentes](#11-preguntas-frecuentes)
12. [Limitaciones conocidas](#12-limitaciones-conocidas)
13. [Soporte](#13-soporte)
14. [Glosario de términos](#14-glosario-de-términos)

---

## 1. Introducción

El **Simulador Financiero para Sistemas de Riego por Goteo** evalúa la viabilidad económica de
proyectos de riego con sensores en microparcelas de hortalizas. Permite capturar los datos del
proyecto, calcular sus flujos de caja y obtener indicadores financieros, así como guardar proyectos
y generar reportes PDF.

El simulador **no sustituye** un estudio financiero profesional: sus resultados dependen
directamente de los datos que capture el usuario.

---

## 2. Requisitos

| Componente | Requisito |
|---|---|
| Sistema operativo | Windows 10/11, macOS 12+ o Linux de escritorio |
| Flutter SDK | 3.10 o superior |
| Memoria RAM | 4 GB (8 GB recomendado) |
| Espacio en disco | 500 MB |
| Resolución | 1366 × 768 mínimo |
| Permisos | Escritura en la carpeta del usuario (SQLite y PDF) |

---

## 3. Instalación y ejecución

### Desde código fuente

```bash
git clone https://github.com/rigo1012/simuladorfinanciero.git
cd simuladorfinanciero
flutter pub get
flutter run -d windows
```

Para generar la versión de escritorio:

```bash
flutter build windows --release
```

El ejecutable queda en `build/windows/x64/runner/Release/`. No se distribuye un ejecutable portable
en este repositorio; debe generarse con el comando anterior.

### Verificación

Al iniciar se muestra la pestaña **Inversión** con la sección **Configuración Temporal Inicial**.
Si los campos aparecen vacíos, la instalación es correcta (el simulador no precarga datos).

---

## 4. Interfaz general

La aplicación tiene **tres pestañas** en la barra lateral (o inferior en ventanas angostas):

1. **Inversión**: contiene los pasos 0 a 6 del proyecto.
2. **Dashboard**: historial de simulaciones y proyectos guardados.
3. **Resultados**: indicadores, tablas detalladas y exportación a PDF.

Los pasos **0 a 6 no son pestañas**: son secciones consecutivas dentro de la pestaña Inversión.

```
Inversión (pestaña)
├── Paso 0. Configuración Temporal
├── Paso 1. Activos e Inversión
├── Paso 2. Estructura de Financiamiento
├── Paso 3. Ingresos Estimados
├── Paso 4. Costos Variables
├── Paso 5. Costos Fijos
└── Paso 6. Parámetros de Evaluación

Dashboard (pestaña)
├── Historial de Simulaciones
└── Proyectos guardados

Resultados (pestaña)
├── Resumen ejecutivo y KPIs
├── Flujo de caja, amortización, KPIs y sensibilidad
└── Documentos y exportación
```

Las secciones son visibles siempre. Si falta un dato de un paso anterior, el cálculo muestra un
mensaje de error al intentar simular; no se bloquea la navegación.

---

## 5. Sin valores predeterminados

Por indicación del asesor del proyecto, **ningún dato financiero, agronómico o de configuración
viene precargado**. Todos los campos inician vacíos y el usuario debe capturarlos.

Antes de calcular, son obligatorios:

- **Paso 0:** meses por periodo, años de proyección y ciclos por año.
- **Paso 1:** al menos un activo, con la decisión explícita de si es **depreciable**; si lo es,
  su **vida útil en años** (> 0).
- **Paso 2:** porcentaje de capital propio y de deuda que sumen 100 %. Si hay deuda, tasa de
  interés anual y plazo en meses.
- **Paso 3:** todos los periodos con precio > 0 y demanda > 0.
- **Paso 4:** al menos un ítem de costo variable en cada periodo.
- **Paso 5:** al menos un ítem de costo fijo en cada periodo.
- **Paso 6:** TREMA, horizonte de evaluación, **tasa de impuesto (ISR)** y **valor residual (%)**.

Un valor `0` solo es válido si el usuario lo escribe expresamente (por ejemplo, ISR 0 % o valor
residual 0 %).

---

## 6. Pasos de la pestaña Inversión

### Paso 0 — Configuración Temporal

Define la duración de cada periodo y el horizonte del proyecto.

| Campo | Descripción |
|---|---|
| Duración del Periodo (meses) | Meses que abarca cada periodo (1 a 60) |
| Años de Proyección Fiscal | Horizonte total del proyecto (1 a 20 años) |
| Cosechas / Ciclos por Año | Número de ciclos productivos anuales (1 a 12) |

- **Total de periodos** = `(años × 12) ÷ meses por periodo`.
- El resumen del horizonte aparece solo cuando los tres campos tienen datos válidos.
- No existen configuraciones rápidas ni valores sugeridos.

### Paso 1 — Activos e Inversión

Cada activo se captura con:

| Campo | Descripción |
|---|---|
| Nombre | Texto libre (sin catálogo) |
| Unidades | Entero ≥ 1 |
| Costo Unitario | Importe por unidad |
| ¿Depreciable? | Elección explícita Sí / No (sin preselección) |
| Vida útil (años) | Obligatoria solo si es depreciable; > 0 |

- **Inversión Requerida** = suma de `unidades × costo unitario` de todos los activos.
- El costo total por activo no se muestra; solo la inversión requerida.
- Los activos no depreciables (por ejemplo, terreno) conservan el 100 % de su costo como valor
  residual.
- El cálculo exige que cada activo tenga definida la condición de depreciable.

### Paso 2 — Estructura de Financiamiento

| Campo | Descripción |
|---|---|
| Capital Propio (%) | 0 a 100 |
| Financiamiento / Deuda (%) | 0 a 100; debe sumar 100 % con el capital propio |
| Tasa de Interés Anual (%) | Obligatoria solo si hay deuda |
| Plazo del Crédito (meses) | Obligatorio solo si hay deuda; 1 a 360 |

- **Monto del préstamo** = inversión requerida × % deuda.
- **Aporte propio** = inversión requerida × % capital propio.
- **Cuota mensual** por Sistema Francés.
- Si el proyecto es 100 % capital propio, los campos de tasa y plazo no bloquean el guardado.
- La previsualización del crédito se actualiza en tiempo real al escribir la tasa y el plazo.

### Paso 3 — Ingresos Estimados

Cada periodo requiere precio unitario y demanda. El ingreso se calcula automáticamente:

```
Ingreso del periodo = Precio × Demanda + Otros ingresos
```

Herramientas disponibles:

1. **Calculadora de Beneficios** (recomendada para el proyecto agrícola). Solicita, sin valores
   precargados:
   - Superficie (m²)
   - Cultivo (texto libre)
   - Rendimiento SIN riego y CON riego (kg/m² por ciclo)
   - Precio por kg
   - Ciclos por año
   - Ahorro de agua (m³ por ciclo)
   - Costo del agua ($/m³)

   Calcula:
   - kg incrementales por ciclo = `(rendimiento con riego − rendimiento sin riego) × superficie`
   - ciclos por periodo = `ciclos por año × meses por periodo ÷ 12`
   - demanda del periodo = kg incrementales × ciclos por periodo
   - otros ingresos = ahorro de agua del periodo × costo del agua

   Muestra un resumen antes de aplicar y llena todos los periodos. Después, cada fila puede
   editarse manualmente.

2. **Llenar con Patrón**: genera una serie con crecimiento compuesto. Sus campos también inician
   vacíos y son obligatorios.

3. **Limpiar Todo**: elimina los ingresos capturados.

- Los periodos se muestran de forma progresiva con el botón **“Agregar Periodo X”**.
- El resumen (total de ingresos, precio promedio y demanda total) considera los periodos capturados.

### Paso 4 — Costos Variables

Tres categorías: **Materia Prima**, **Mano de Obra** y **Cargos Indirectos**.

| Categoría | Campos |
|---|---|
| Materia Prima | Nombre, cantidad unitaria, costo unitario |
| Mano de Obra | Nombre de la operación, costo por operación |
| Cargos Indirectos | Recurso, cantidad, costo unitario |

- La inflación anual inicia **vacía** y es capturada por el usuario; se aplica de forma compuesta:
  `costo × (1 + i)^(meses/12 × (periodo − 1))`.
- Los periodos se revelan con **“Agregar Periodo X”**.
- Cada periodo requiere al menos un ítem para poder calcular.

### Paso 5 — Costos Fijos

| Campo | Descripción |
|---|---|
| Nombre | Texto libre |
| Monto por periodo | Importe base |
| Aplicar inflación | Sí / No por ítem |

- La inflación de referencia inicia **vacía** y se captura en la sección.
- Los periodos se revelan con **“Agregar Periodo X”**.
- Cada periodo requiere al menos un ítem.

### Paso 6 — Parámetros de Evaluación

| Campo | Descripción |
|---|---|
| Tasa de Descuento — TREMA (%) | Rentabilidad mínima esperada, anual |
| Horizonte de Evaluación (años) | Debe ser ≤ años de proyección |
| Tasa de Impuesto — ISR (%) | Impuesto sobre la renta aplicable |
| Valor Residual de Activos Depreciables (%) | Porcentaje recuperado al final |

Todos los campos inician vacíos y son obligatorios.

El botón **“Calcular Rentabilidad”** ejecuta la simulación y muestra los resultados en la pestaña
Resultados. El botón **“Guardar proyecto”** (cabecera de Inversión) guarda todo el proyecto.

---

## 7. Fórmulas financieras

Sea `m` = meses por periodo, `N` = periodos del horizonte y `TREMA` la tasa anual en decimal.

### Tasa de descuento del periodo

```
r = (1 + TREMA)^(m / 12) − 1
```

### VPN

```
VPN = Σ (F_t / (1 + r)^t),  t = 0..N
```

donde `F_0 = −aporte propio` y `F_t` es el flujo de caja libre del periodo `t`.

### TIR

Se resuelve `VPN = 0` para la tasa por periodo con Newton-Raphson y, si no converge, con bisección
en `[−0.99, 10]`. La TIR que se muestra es **anual efectiva**:

```
TIR_anual = (1 + TIR_periodo)^(12 / m) − 1
```

### Depreciación e ISR

Para cada activo depreciable, durante su vida útil:

```
depreciación_periodo = costo_total / (vida_útil_años × 12 / m)
UAI = EBITDA − intereses
ISR = max(0, UAI − depreciación) × tasa_ISR
```

### Flujo de caja libre

```
Flujo de caja = UAI − ISR − amortización de capital − liquidación de saldo + valor residual
```

El flujo operativo (sin financiamiento) es:

```
Flujo operativo = EBITDA − ISR_operativo
ISR_operativo = max(0, EBITDA − depreciación) × tasa_ISR
```

### Valor residual

Solo en el último periodo del horizonte:

```
Valor residual = Σ(costo de activos depreciables) × %valor_residual
               + Σ(costo de activos no depreciables) × 100 %
```

### Relación Beneficio/Costo

```
B/C = VP(ingresos + valor residual) /
      (inversión inicial + VP(costos variables + costos fijos + impuestos [+ intereses]))
```

La versión operativa excluye los intereses y usa el ISR operativo.

### Payback

- **Payback simple**: primer periodo en que el flujo acumulado ≥ 0.
- **Payback descontado**: primer periodo en que el VPN acumulado ≥ 0.
- Ambos se reportan en periodos y en **años**, con interpolación lineal dentro del periodo de
  recuperación: `años = periodos × m / 12`.

### Análisis de sensibilidad

El reporte PDF compara el VPN con variaciones de la TREMA anual (50 %, 75 %, 100 %, 125 % y 150 %),
convirtiendo cada tasa anual a su equivalente por periodo.

---

## 8. Interpretación de resultados

| Indicador | Lectura |
|---|---|
| VPN > 0 | El proyecto crea valor a la TREMA exigida (VIABLE) |
| VPN ≤ 0 | No cubre la TREMA exigida (NO VIABLE) |
| TIR anual efectiva | Rentabilidad anual del proyecto comparable con la TREMA |
| B/C > 1 | Los beneficios descontados superan los costos descontados |
| Payback | Tiempo necesario para recuperar la inversión |

El veredicto se basa en el VPN. Los demás indicadores contextualizan el resultado.

---

## 9. Exportación de PDF y documentos

### Autoguardado

Al calcular una simulación, el PDF se genera y se guarda **automáticamente** en la carpeta de
Documentos del usuario, sin intervención adicional:

```
Documentos/Evaluacion_Sistema_de_Riego_AAAA-MM-DD_HHMMSS.pdf
```

Se muestra un aviso con la ruta absoluta del archivo guardado.

### Botón “Exportar PDF”

Vuelve a generar el PDF, lo guarda y abre el diálogo de impresión o compartición del sistema.

### Botón “Documentos”

En la cabecera de Resultados abre la lista de PDF generados, con opciones para abrir cada archivo
o la carpeta de Documentos.

El PDF incluye: resumen ejecutivo, configuración del proyecto, estructura de capital, indicadores,
flujo de caja detallado (con depreciación e impuestos), tabla de amortización y análisis de
sensibilidad.

---

## 10. Guardar y abrir proyectos

### Guardar

En la cabecera de la pestaña Inversión, el botón **“Guardar proyecto”** solicita un nombre y
guarda el estado completo: configuración temporal, activos, financiamiento, ingresos, costos
variables, costos fijos, inflación, TREMA, horizonte, ISR y valor residual.

### Abrir

En la pestaña **Dashboard**, la sección **“Proyectos guardados”** lista los proyectos con nombre y
fecha:

- **Abrir**: carga el proyecto y reconstruye la aplicación.
- **Eliminar**: solicita confirmación antes de borrar.

Los proyectos se almacenan en la base de datos SQLite local. No existe importación ni exportación a
archivos `.json` externos en esta versión.

### Historial

El Dashboard también muestra el historial de simulaciones ejecutadas (inversión, tasa y años).

---

## 11. Preguntas frecuentes

| Pregunta | Respuesta |
|---|---|
| ¿Los datos se guardan solos? | Solo al usar “Guardar proyecto”. El historial de simulaciones sí se registra al calcular. |
| ¿Puedo tener varios proyectos? | Sí, en “Proyectos guardados”. |
| ¿Puedo modificar un paso anterior? | Sí; si cambias la configuración temporal o el financiamiento, se reinician los datos dependientes. |
| ¿Funciona sin internet? | Sí, es 100 % local. |
| ¿Por qué la TIR es “N/A”? | El proyecto no tiene cambio de signo en sus flujos o no hay solución en el rango evaluado. |
| ¿Por qué el payback dice “No recupera”? | El flujo acumulado no alcanza cero dentro del horizonte. |
| ¿Cómo se calcula el valor residual? | El usuario define el porcentaje para activos depreciables; los no depreciables valen 100 %. |
| ¿Puedo poner ISR 0 %? | Sí, si el usuario lo escribe expresamente. |
| ¿El PDF se guarda solo? | Sí, al calcular la simulación; también puede regenerarse con “Exportar PDF”. |

---

## 12. Limitaciones conocidas

- Solo se modela el **ISR**; no se incluyen otros impuestos, contribuciones ni retenciones.
- La depreciación es **lineal** por activo y no contempla depreciación acelerada ni fracciones de
  año distintas a la vida útil capturada.
- El financiamiento usa únicamente el **Sistema Francés** (cuota fija); no modela periodos de
  gracia, comisiones ni seguros de crédito.
- El valor residual es un **porcentaje definido por el usuario** sobre activos depreciables; no es
  un avalúo de mercado.
- La inflación se aplica a costos variables y fijos según lo capturado; no se aplica a ingresos ni
  al financiamiento.
- Solo se maneja una moneda; no hay tipo de cambio ni conversión.
- Los periodos se expresan en meses enteros; el horizonte se redondea hacia abajo al número de
  periodos completos.
- No existe importación/exportación de proyectos a archivo `.json`; el almacenamiento es la base
  SQLite local.
- No hay atajos de teclado ni menú “Acerca de” implementados en esta versión.
- Los resultados son estimaciones basadas en los datos capturados y no constituyen asesoría
  financiera profesional.

---

## 13. Soporte

- **Repositorio:** https://github.com/rigo1012/simuladorfinanciero
- **Incidencias:** sección de Issues del repositorio
- **Base de datos local:** `simulador_riego.db` en el directorio de bases de datos de la aplicación
- **Reportes PDF:** carpeta de Documentos del usuario

Al reportar un problema incluye: pasos para reproducirlo, datos capturados (capturas de pantalla),
mensaje de error exacto y versión de la aplicación.

---

## 14. Glosario de términos

La aplicación incluye este glosario en contexto: junto a los campos y encabezados hay un icono de
información, y en la pestaña Dashboard está el botón **“Glosario”** con búsqueda.

| Término | Definición |
|---|---|
| TREMA | Rentabilidad mínima que el inversionista exige al proyecto, expresada como tasa anual. |
| Tasa por periodo | Tasa equivalente a la TREMA anual para la duración de un periodo. |
| VPN | Diferencia entre el valor presente de los flujos de caja y la inversión inicial. |
| TIR | Tasa de descuento que hace que el VPN sea cero; se muestra anual efectiva. |
| Beneficio/Costo (B/C) | Cociente entre el valor presente de los beneficios y el de los costos. |
| Payback simple | Periodos necesarios para que los flujos acumulados igualen la inversión inicial. |
| Payback descontado | Periodos necesarios para que el VPN acumulado iguale la inversión inicial. |
| EBITDA | Ingresos menos costos variables y fijos, antes de intereses e impuestos. |
| UAI | Utilidad antes de impuestos: EBITDA menos intereses. |
| ISR | Impuesto sobre la renta aplicado a la utilidad fiscal después de la depreciación. |
| Depreciación | Asignación lineal del costo de un activo depreciable durante su vida útil. |
| Vida útil | Años durante los cuales se espera utilizar un activo depreciable. |
| Valor residual | Valor recuperado de los activos al final del horizonte de evaluación. |
| Sistema francés | Amortización de un crédito con cuotas periódicas fijas. |
| Amortización de capital | Parte de la cuota que reduce el principal del crédito. |
| Interés | Costo financiero por el uso del crédito. |
| Saldo insoluto | Capital del crédito que aún queda por pagar. |
| Inflación | Aumento general de precios que reduce el poder adquisitivo. |
| Costos variables | Costos que cambian en proporción a la producción. |
| Costos fijos | Costos que no dependen del volumen de producción. |
| Materia prima | Insumos físicos consumidos en el proceso productivo. |
| Mano de obra | Costo del trabajo humano requerido para las operaciones. |
| Cargos indirectos | Costos de producción no identificables con un insumo específico. |
| Periodo | Intervalo de tiempo en el que se agrupan ingresos, costos y flujos. |
| Ciclos por año | Número de ciclos productivos realizados en un año. |
| Horizonte | Años que abarca la evaluación financiera. |
| Ahorro de agua | Volumen de agua que se deja de consumir por ciclo. |
| Otros ingresos | Ingresos distintos de la venta del producto principal. |
| Capital propio | Parte de la inversión aportada con recursos del inversionista. |
| Deuda | Parte de la inversión financiada con crédito. |
| ROI | Relación entre el valor generado y el monto invertido. |

---

*Simulador Financiero para Sistemas de Riego por Goteo — ITST, 2026. Todos los derechos reservados.*
