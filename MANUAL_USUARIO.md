# Manual de Usuario - Simulador Financiero para Sistemas de Riego

**Versión 1.0** | **Octubre 2026**

---

## Índice

1. [Introducción](#1-introducción)
2. [Requisitos del Sistema](#2-requisitos-del-sistema)
3. [Instalación y Ejecución](#3-instalación-y-ejecución)
4. [Flujo de Trabajo General](#4-flujo-de-trabajo-general)
5. [Descripción Detallada de Cada Paso](#5-descripción-detallada-de-cada-paso)
6. [Interpretación de Resultados](#6-interpretación-de-resultados)
7. [Exportación a PDF](#7-exportación-a-pdf)
8. [Preguntas Frecuentes](#8-preguntas-frecuentes)
9. [Soporte Técnico](#9-soporte-técnico)

---

## 1. Introducción

El **Simulador Financiero para Sistemas de Riego** es una aplicación de escritorio diseñada para evaluar la viabilidad económica de proyectos de inversión en infraestructura de riego agrícola. Permite al usuario:

- **Calcular la Inversión Requerida** mediante la definición de activos (bombas, tuberías, automatización, terreno, etc.)
- **Estructurar el Financiamiento** combinando capital propio y deuda bancaria
- **Proyectar Ingresos** basados en precios y demandas por periodo
- **Estimar Costos Variables** (materia prima, mano de obra, cargos indirectos) con inflación compuesta
- **Definir Costos Fijos** (sueldos, rentas, seguros) con inflación opcional
- **Evaluar Rentabilidad** mediante VPN, TIR, Payback, B/C y análisis de sensibilidad
- **Generar Reportes PDF** profesionales para presentación y registro

### Fundamento Metodológico

La evaluación se basa en **Flujo de Caja Libre (FCL)** descontado a la **TREMA** (Tasa Mínima de Rentabilidad Esperada), considerando:
- Horizonte temporal configurable (periodos de duración variable en meses)
- Inflación compuesta en costos variables y fijos (opcional)
- Amortización de deuda bajo **Sistema Francés** (cuotas fijas)
- Valor residual de activos (10% por defecto)
- Horizonte de evaluación = min(solicitado, configuración temporal)

---

## 2. Requisitos del Sistema

| Componente | Requisito Mínimo |
|------------|------------------|
| **Sistema Operativo** | Windows 10/11, macOS 12+, Ubuntu 20.04+ |
| **Memoria RAM** | 4 GB (8 GB recomendado) |
| **Espacio en Disco** | 500 MB |
| **Resolución** | 1366 × 768 mínimo (1920 × 1080 recomendado) |
| **Permisos** | Escritura en directorio de usuario (para base de datos SQLite) |

---

## 3. Instalación y Ejecución

### Opción A: Ejecutable Portable (Recomendado)
```bash
# Descargar simuladorfinanciero.exe y ejecutar directamente
# No requiere instalación adicional
```

### Opción B: Desde Código Fuente (Desarrolladores)
```bash
# Prerrequisitos: Flutter SDK 3.10+
git clone https://github.com/rigo1012/simuladorfinanciero.git
cd simuladorfinanciero
flutter pub get
flutter run -d windows    # Debug con hot reload
flutter build windows --release  # Generar .exe optimizado
```

### Verificación de Instalación
Al iniciar, la aplicación muestra el **Paso 0: Configuración Temporal**. Si ve esta pantalla, la instalación es correcta.

---

## 4. Flujo de Trabajo General

La aplicación guía al usuario a través de **7 pasos secuenciales** (pestañas laterales):

```
┌─────────────────────────────────────────────────────────────────┐
│  0. ⚙️ CONFIGURACIÓN TEMPORAL    (Obligatorio)                 │
├─────────────────────────────────────────────────────────────────┤
│  1. 🏗️ ACTIVOS E INVERSIÓN        → Inversión Requerida       │
├─────────────────────────────────────────────────────────────────┤
│  2. 💰 FINANCIAMIENTO            → % Propio / % Deuda + Cuotas │
├─────────────────────────────────────────────────────────────────┤
│  3. 📈 INGRESOS ESTIMADOS        → Precio × Demanda / Periodo  │
├─────────────────────────────────────────────────────────────────┤
│  4. 📊 COSTOS VARIABLES          → 3 Categorías + Inflación    │
├─────────────────────────────────────────────────────────────────┤
│  5. 📋 COSTOS FIJOS              → Items + Inflación Opcional  │
├─────────────────────────────────────────────────────────────────┤
│  6. 🎯 PARÁMETROS FINANCIEROS    → TREMA + Horizonte          │
├─────────────────────────────────────────────────────────────────┤
│  7. 📊 RESULTADOS                → VPN, TIR, Payback, B/C, PDF │
└─────────────────────────────────────────────────────────────────┘
```

**Regla de Oro**: No puede avanzar al siguiente paso hasta completar el actual. El botón **"Calcular Rentabilidad"** solo se habilita cuando todos los pasos 0-5 están completos.

---

## 5. Descripción Detallada de Cada Paso

### 📋 Paso 0: Configuración Temporal (Obligatorio)

Define la **granularidad temporal** y el **horizonte** del proyecto.

| Campo | Descripción | Valor Típico |
|-------|-------------|--------------|
| **Meses por Periodo** | Duración de cada periodo en meses (libre) | 3 (trimestral), 6 (semestral) |
| **Años de Proyección** | Horizonte total del proyecto en años | 5 años (estándar infraestructura) |
| **Ciclos por Año** | Número de ciclos productivos anuales | 2 (clima templado), 3 (trópico) |

**Ejemplo**: `3 meses/periodo × 5 años × 2 ciclos/año = 20 periodos totales`

> **Botón "Guardar y Continuar"** → Valida y habilita Paso 1  
> **Botón "Cambiar"** (después de guardar) → Reinicia **TODOS** los datos posteriores

---

### 🏗️ Paso 1: Activos e Inversión

Define los **componentes físicos** del sistema de riego. El sistema calcula **automáticamente** el costo total por fila (`Unidades × Costo Unitario`) y la **suma total = Inversión Requerida**.

| Columna | Descripción | Ejemplo |
|---------|-------------|---------|
| **Nombre del Activo** | Descripción libre | "Bomba centrífuga 50 HP" |
| **Unidades** | Cantidad necesaria (entero ≥ 1) | 2 |
| **Costo Unitario** | Precio por unidad | $150,000 |

**Funciones**:
- ➕ **Agregar Activo** → Diálogo con validación
- ✏️ **Editar** (icono lápiz) → Modifica valores inline
- 🗑️ **Eliminar** (icono basura) → Confirma antes de borrar
- **Chip "Inversión Requerida"** → Muestra suma total en tiempo real (ej: $1,695,000)

> **Importante**: El costo total por fila **NO se muestra al usuario** (requisito de confidencialidad), solo la suma final.

---

### 💰 Paso 2: Estructura de Financiamiento

Define cómo se financia la **Inversión Requerida** del Paso 1.

| Campo | Descripción | Validación |
|-------|-------------|------------|
| **% Capital Propio** | Porcentaje aportado por el inversionista | 0-100% |
| **% Financiamiento/Deuda** | Porcentaje financiado con deuda bancaria | 100% - % Propio |
| **Tasa Interés Anual** | Tasa nominal del crédito bancario | > 0% (solo si Deuda > 0%) |
| **Plazo del Crédito (meses)** | Duración del préstamo | 1-360 meses (solo si Deuda > 0%) |

**Cálculos Automáticos**:
- **Monto Préstamo** = Inversión × %Deuda/100
- **Aporte Propio** = Inversión × %Propio/100
- **Cuota Mensual** = Sistema Francés: `P × [i(1+i)^n]/[(1+i)^n-1]`

**Tabla de Amortización Preview**: Muestra por periodo: Cuota Total, Interés (P&G), Capital (Flujo Caja), Saldo Final.

> **Botón "Guardar y Continuar"** → Habilita Paso 3  
> **Botón "Cambiar"** → Reinicia Ingresos, Costos Variables, Costos Fijos y Resultados

---

### 📈 Paso 3: Ingresos Estimados

Proyecta los **ingresos por periodo** basados en precio y demanda.

| Columna | Fórmula | Ejemplo |
|---------|---------|---------|
| **Periodo** | 1, 2, 3... N (automático) | 1 |
| **Precio Unitario** | $/unidad de producto | $12.50 |
| **Demanda** | Unidades vendidas/periodo | 8,000 |
| **Ingreso** | = Precio × Demanda (auto) | $100,000 |

**Funciones**:
- ✏️ **Editar por fila** → Modifica Precio/Demanda, Ingreso se recalcula
- 🔄 **"Llenar con Patrón"** → Genera serie con crecimiento compuesto:
  - Precio base + % crecimiento/periodo
  - Demanda base + % crecimiento/periodo
- 🗑️ **"Limpiar Todo"** → Reinicia todos los periodos
- **Resumen**: Total Ingresos, Promedio Precio, Total Demanda

> **Validación**: Todos los periodos deben tener Precio > 0 y Demanda > 0 para habilitar cálculo.

---

### 📊 Paso 4: Costos Variables

Costos que **varían proporcionalmente** a la producción. 3 categorías con **inflación compuesta**.

#### Inflación Global
- **Inflación Anual %** → Factor por periodo: `(1 + i)^(meses/12)`
- **Preview** muestra factor por periodo: `P1: 1.0000, P2: 1.0123, P3: 1.0247...`

#### 3 Sub-categorías (pestañas)

| Categoría | Campos | Fórmula Costo |
|-----------|--------|---------------|
| **Materia Prima** | Nombre, Cant. Unitaria, Costo Unit. | `Cantidad × Costo Unit.` |
| **Mano de Obra** | Operación, Costo/Operación | `Costo/Operación` |
| **Cargos Indirectos** | Recurso, Cantidad, Costo Unit. | `Cantidad × Costo Unit.` |

**Por Periodo (ExpansionTile)**:
- Lista items de esa categoría
- **Subtotal Base** (sin inflación)
- **Subtotal c/ Inflación** = Base × Factor Inflación
- ➕ **Agregar Item** → Diálogo contextual por categoría

**Tabla Resumen** (al final):
| Periodo | Materia Prima | Mano Obra | Cargos Ind. | Total Base | Factor Inf. | Total c/Inf. |

> **Botón "Limpiar Todo"** → Elimina todos los items de todas las categorías y periodos.

---

### 📋 Paso 5: Costos Fijos

Costos **independientes del volumen** de producción (sueldos, rentas, seguros).

| Campo | Descripción |
|-------|-------------|
| **Nombre** | "Sueldo Gerente", "Renta Bodega", "Seguro" |
| **Monto/Periodo** | Valor base por periodo |
| **Aplicar Inflación** | Toggle (default: OFF) |

**Inflación Opcional**: Si toggle = ON, aplica inflación global de referencia del Paso 4.

**Por Periodo (ExpansionTile)**:
- Items con costo base y costo c/inflación
- ➕ **Agregar** → Diálogo simple (Nombre, Monto, Toggle Inflación)
- 📝 **Editar/Eliminar** → Menú contextual (⋮)

**Resumen Totales**: Total Base, Total c/Inflación, Promedio/Periodo

---

### 🎯 Paso 6: Parámetros Financieros

| Parámetro | Descripción | Validación |
|-----------|-------------|------------|
| **TREMA** | Tasa Mínima de Rentabilidad Esperada (% anual) | 0.01% - 100% |
| **Horizonte Evaluación** | Años a evaluar (≤ Años Proyección Paso 0) | 1 - Años Proyección |

> **Botón "Calcular Rentabilidad"** → Ejecuta Motor FEN + Evaluador → Abre pestaña **Resultados**

---

### 📊 Paso 7: Resultados

Dashboard completo con **4 pestañas**:

#### 1. Resumen Ejecutivo (Tarjeta Principal)
- **Veredicto**: ✅ VIABLE / ❌ NO VIABLE (basado en VPN > 0)
- **VPN**: Valor Presente Neto a TREMA
- **TIR**: Tasa Interna de Retorno (%)
- **Payback**: Periodos para recuperar inversión
- **B/C**: Relación Beneficio/Costo

#### 2. KPIs Grid (12 indicadores)
| Financieros | Operativos |
|-------------|------------|
| VPN / VPN Operativo | ROI Inversión / ROI Aporte |
| TIR / TIR Operativa | Margen EBITDA / Margen Neto |
| Payback / Payback Desc. | |
| B/C / B/C Operativo | |

#### 3. Pestañas de Detalle
| Pestaña | Contenido |
|---------|-----------|
| **Flujo de Caja** | Tabla 12 columnas: Per, Mes, Ingresos, Cost. Var., Cost. Fix, EBITDA, Intereses, UAI, Amort. Cap., Liq. Saldo, Val. Res., FLUJO CAJA |
| **Amortización** | Tabla por periodo: Cuotas, Interés (P&G), Capital (Flujo), Saldo Final |
| **KPIs Detalle** | Lista expandible de todos los KPIs calculados |
| **Sensibilidad** | VPN vs TREMA (5 puntos: 50%, 75%, 100%, 125%, 150%) |

#### 4. Acciones
| Botón | Acción |
|-------|--------|
| 📄 **Exportar PDF** | Genera reporte profesional completo |
| 🔄 **Recalcular** | Re-ejecuta simulación con parámetros guardados |

---

## 6. Interpretación de Resultados

### Veredicto Principal
| Resultado | Significado | Acción |
|-----------|-------------|--------|
| **VIABLE** (VPN > 0) | Genera valor > costo de oportunidad | Proceder / Presentar a inversionistas |
| **NO VIABLE** (VPN ≤ 0) | No cubre costo de oportunidad | Revisar supuestos / No invertir |

### Indicadores Clave
| Indicador | Fórmula | Interpretación |
|-----------|---------|----------------|
| **VPN** | Σ Flujo_t / (1+TREMA)^t | Valor absoluto creado/destruido |
| **TIR** | Tasa que hace VPN = 0 | Rentabilidad intrínseca del proyecto |
| **Payback** | Periodos para VPN acumulado ≥ 0 | Liquidez / riesgo temporal |
| **B/C** | PV(Beneficios) / PV(Costos) | > 1 = beneficios superan costos |
| **ROI Aporte** | VPN / Aporte Propio | Rentabilidad del capital propio |

### Análisis de Sensibilidad
Muestra **VPN vs TREMA** en 5 puntos (50%, 75%, 100%, 125%, 150% de TREMA base).  
**Punto de inflexión** (VPN = 0) ≈ **TIR del proyecto**.

---

## 7. Exportación a PDF

El reporte PDF incluye:

1. **Portada**: Título, proyecto, fecha, usuario
2. **Resumen Ejecutivo**: Veredicto, VPN, TIR, Payback, B/C, ROI
3. **Configuración del Proyecto**: Parámetros temporales
4. **Estructura de Capital**: Inversión, % Propio/Deuda, cuotas, intereses
5. **Indicadores Financieros**: 20+ KPIs en tabla
6. **Flujo de Caja Detallado**: Tabla 12 columnas × N periodos
7. **Tabla de Amortización**: Por periodos del proyecto
8. **Análisis de Sensibilidad**: VPN vs TREMA (gráfico tabular)

**Generación**: Botón **"Exportar PDF"** → Diálogo "Guardar como" → Abre automáticamente.

---

## 8. Preguntas Frecuentes (FAQ)

### General
| Pregunta | Respuesta |
|----------|-----------|
| **¿Se guardan los datos al cerrar?** | Sí, en base de datos SQLite local (`simulador_riego.db`) |
| **¿Puedo tener múltiples proyectos?** | Cada simulación se guarda en historial con fecha/hora |
| **¿Puedo modificar un paso anterior?** | Sí, botón "Cambiar" en resúmenes, pero borra datos posteriores |
| **¿Funciona sin internet?** | Sí, 100% offline |

### Cálculos
| Pregunta | Respuesta |
|----------|-----------|
| **¿Por qué mi TIR es "N/A"?** | El algoritmo no converge (flujos no cambian signo o proyecto no viable) |
| **¿Por qué Payback = "No recupera"?** | Flujo acumulado nunca llega a cero en el horizonte |
| **¿Inflación en costos fijos?** | Solo si activas el toggle por item (default: OFF) |
| **Valor residual** | 10% de Inversión Requerida en último periodo (configurable en código) |

### Errores Comunes
| Error | Solución |
|-------|----------|
| "Falta configuración temporal" | Completa Paso 0 primero |
| "Agregue al menos un activo" | Paso 1 requiere ≥1 activo |
| "Complete ingresos (20 periodos)" | Paso 3: todos los periodos con Precio>0 y Demanda>0 |
| "Complete costos variables" | Paso 4: ≥1 item en cada periodo |
| "Complete costos fijos" | Paso 5: ≥1 item en cada periodo |

---

## 9. Soporte Técnico

### Logs y Depuración
- **Logs**: Consola de Flutter DevTools (`http://127.0.0.1:XXXX/`)
- **Base de Datos**: `%APPDATA%/simuladorfinanciero/simulador_riego.db`
- **Errores Comunes**: Revisar consola al hacer "Calcular Rentabilidad"

### Reportar Bugs
Incluir en el reporte:
1. Pasos para reproducir
2. Datos de entrada (capturas de cada paso)
3. Mensaje de error exacto
4. Versión de la app (About → Version)

### Contacto
- **Repositorio**: https://github.com/rigo1012/simuladorfinanciero
- **Issues**: GitHub Issues para bugs y feature requests

---

## Anexo: Atajos de Teclado

| Acción | Windows/Linux | macOS |
|--------|---------------|-------|
| Guardar formulario | `Enter` (en último campo) | `Enter` |
| Cambiar pestaña | `Ctrl+1/2/3...` | `Cmd+1/2/3...` |
| Recalcular | `F5` | `Cmd+R` |
| Exportar PDF | `Ctrl+P` | `Cmd+P` |

---

**Fin del Manual**  
*Simulador Financiero v1.0 — Desarrollado para evaluación de proyectos de riego agrícola*