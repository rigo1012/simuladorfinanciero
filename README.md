# Simulador Financiero para Sistemas de Riego por Goteo

Aplicación de escritorio para evaluar la rentabilidad de sistemas de riego por goteo con
sensores en microparcelas de hortalizas, orientada a productores de Tlatlauquitepec, Puebla.

**Institución:** Instituto Tecnológico Superior de Teziutlán (ITST)  
**Proyecto:** Servicio Social  
**Versión:** 1.0 (noviembre 2026)

## Objetivo

Proporcionar una herramienta local y sin conexión que permita capturar todos los datos de un
proyecto de riego (activos, financiamiento, ingresos, costos y parámetros de evaluación) y obtener
indicadores financieros verificables: VPN, TIR anual efectiva, payback, relación Beneficio/Costo,
ISR, depreciación y valor residual. El simulador **no incluye valores predeterminados**: toda la
información del proyecto la captura el usuario.

## Requisitos

- Flutter SDK 3.10 o superior (Dart 3.10+)
- Windows 10/11 (soporte de escritorio), macOS o Linux
- 4 GB de RAM y 500 MB de disco
- Permisos de escritura en el directorio del usuario (base de datos y PDF)

## Instalación y ejecución

```bash
git clone https://github.com/rigo1012/simuladorfinanciero.git
cd simuladorfinanciero
flutter pub get
flutter run -d windows          # Ejecución en modo debug
flutter build windows --release # Genera el ejecutable en build/windows/x64/runner/Release/
flutter test                    # Ejecuta la suite de pruebas
flutter analyze                 # Análisis estático
```

No se requiere servidor, conexión a internet ni un instalador: la aplicación usa SQLite local y
guarda los PDF en la carpeta de Documentos del usuario.

## Estructura de carpetas

```
lib/
├── main.dart                 # Punto de entrada, tema y providers
├── controladores/            # ProveedorSimulador (estado y orquestación)
├── modelos/                  # Activo, ConfiguracionTemporal, IngresoPeriodo,
│                             # CostoVariable, CostoFijo, EstructuraCapital, Inversion
├── nucleo/                   # dbayuda.dart (SQLite, migraciones y proyectos)
├── servicios/                # motor_fen, evaluador_financiero, reporte_pdf
└── vistas/                   # DisenoEscritorio y las 3 pestañas:
                              # Inversión, Dashboard y Resultados
test/                         # Pruebas unitarias, de integración y de migración
windows/ linux/ macos/        # Proyectos nativos de plataforma
```

## Funcionalidades principales

- Tres pestañas: **Inversión**, **Dashboard** y **Resultados**.
- Pasos 0 a 6 dentro de la pestaña Inversión (configuración temporal, activos, financiamiento,
  ingresos, costos variables, costos fijos y parámetros de evaluación).
- Calculadora de beneficios agrícolas que genera los ingresos por periodo.
- Guardado y apertura de proyectos completos en SQLite.
- Exportación de PDF con autoguardado en Documentos y visor de documentos generados.
- Evaluación financiera con ISR, depreciación lineal y valor residual por tipo de activo.

El manual de usuario se entrega por separado.

## Autor(es)

- [COMPLETAR: nombre del autor o autores]
- [COMPLETAR: correo institucional]
- Instituto Tecnológico Superior de Teziutlán (ITST)

## Licencia

Todos los derechos reservados. Consulta el archivo `LICENSE`.
