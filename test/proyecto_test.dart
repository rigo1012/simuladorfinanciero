import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:simuladorfinanciero/controladores/proveedor_simulador.dart';
import 'package:simuladorfinanciero/modelos/activo.dart';
import 'package:simuladorfinanciero/modelos/configuracion_temporal.dart';
import 'package:simuladorfinanciero/modelos/costo_fijo.dart';
import 'package:simuladorfinanciero/modelos/costo_variable.dart';
import 'package:simuladorfinanciero/modelos/estructura_capital.dart';
import 'package:simuladorfinanciero/modelos/ingreso_periodo.dart';

ProveedorSimulador _proyectoCompleto() {
  final proveedor = ProveedorSimulador();
  final config = ConfiguracionTemporal(
    mesesPorPeriodo: 6,
    anosProyeccion: 3,
    cosechasPorAnio: 2,
  );
  proveedor.configurarTemporal(config);
  proveedor.agregarActivo(Activo(
    id: 'a1',
    nombre: 'Equipo',
    unidades: 1,
    costoUnitario: 1000000,
    depreciable: true,
    vidaUtilAnios: 10,
  ));
  proveedor.agregarActivo(Activo(
    id: 'a2',
    nombre: 'Terreno',
    unidades: 1,
    costoUnitario: 500000,
    depreciable: false,
  ));
  proveedor.configurarFinanciamiento(EstructuraCapital(
    pctPropio: 100,
    pctDeuda: 0,
    tasaInteresAnual: null,
    plazoMeses: null,
    inversionRequerida: proveedor.inversionRequerida.total,
  ));

  for (var p = 1; p <= 6; p++) {
    proveedor.actualizarIngreso(IngresoPeriodo(
      periodo: p,
      precio: 12.5,
      demanda: 800,
      otrosIngresos: 150.5,
    ));
    proveedor.agregarItemCostoVariable(
      p,
      ItemCostoVariable(
        id: 'cv_$p',
        tipo: TipoCostoVariable.materiaPrima,
        nombre: 'Insumo',
        cantidadUnitaria: 100,
        costoUnitario: 2.5,
      ),
      6,
      4.5,
    );
    proveedor.agregarItemCostoFijo(
      p,
      ItemCostoFijo(
        id: 'cf_$p',
        nombre: 'Renta',
        monto: 15000,
        aplicarInflacion: true,
      ),
    );
  }

  proveedor.setInflacionGlobalFijos(4.5);
  proveedor.setTasaImpuestoPct(null);
  proveedor.setValorResidualPct(null);
  return proveedor;
}

void main() {
  group('Guardar y cargar proyecto completo', () {
    test('Roundtrip conserva todos los datos, incluidos los nulos', () async {
      final original = _proyectoCompleto();
      final json = jsonDecode(jsonEncode(original.exportarSesion())) as Map<String, dynamic>;

      final nuevo = ProveedorSimulador();
      await nuevo.cargarProyectoCompleto(json);

      expect(nuevo.error, isNull);
      expect(nuevo.configTemporal, equals(original.configTemporal));

      expect(nuevo.inversionRequerida.activos.length, original.inversionRequerida.activos.length);
      for (var i = 0; i < original.inversionRequerida.activos.length; i++) {
        expect(nuevo.inversionRequerida.activos[i], equals(original.inversionRequerida.activos[i]));
      }

      final e = nuevo.estructuraCapital;
      expect(e, isNotNull);
      expect(e?.pctPropio, equals(100.0));
      expect(e?.pctDeuda, equals(0.0));
      expect(e?.tasaInteresAnual, isNull);
      expect(e?.plazoMeses, isNull);
      expect(e?.inversionRequerida, equals(1500000.0));

      expect(nuevo.ingresos.length, equals(6));
      expect(nuevo.ingresos.first, equals(original.ingresos.first));
      expect(nuevo.ingresos.first.otrosIngresos, equals(150.5));

      expect(nuevo.costosVariables.length, equals(6));
      final cv = nuevo.costosVariables.first;
      expect(cv.periodo, equals(1));
      expect(cv.inflacionAnualPct, equals(4.5));
      expect(cv.mesesPorPeriodo, equals(6));
      expect(cv.items.length, equals(1));
      expect(cv.items.first.nombre, equals('Insumo'));
      expect(cv.items.first.cantidadUnitaria, equals(100.0));

      expect(nuevo.costosFijos.length, equals(6));
      final cf = nuevo.costosFijos.first;
      expect(cf.items.length, equals(1));
      expect(cf.items.first.monto, equals(15000.0));
      expect(cf.items.first.aplicarInflacion, isTrue);

      expect(nuevo.inflacionGlobalFijos, equals(4.5));
      expect(nuevo.ultimaTREMA, equals(0.0));
      expect(nuevo.ultimoHorizonte, equals(0));
      expect(nuevo.tasaImpuestoPct, isNull);
      expect(nuevo.valorResidualPct, isNull);

      expect(nuevo.ultimoResultado, isNull);
      expect(nuevo.puedeDescargarPDF, isFalse);
    });

    test('Acepta enteros en pct_propio, inversion_requerida y plazo_meses', () async {
      final json = <String, dynamic>{
        'version': 1,
        'configuracion': {
          'meses_por_periodo': 6,
          'anos_proyeccion': 3,
          'cosechas_por_anio': 2,
        },
        'activos': [
          {
            'id': 'a1',
            'nombre': 'Equipo',
            'unidades': 1,
            'costo_unitario': 1000000,
          }
        ],
        'estructura': {
          'pct_propio': 100,
          'pct_deuda': 0,
          'tasa_interes_anual': null,
          'plazo_meses': 36,
          'inversion_requerida': 1000000,
        },
        'ingresos': <dynamic>[],
        'costos_variables': <dynamic>[],
        'costos_fijos': <dynamic>[],
        'inflacion_global_fijos': 0,
        'trema': 12,
        'horizonte': 3,
        'tasa_impuesto_pct': 30,
        'valor_residual_pct': 10,
      };

      final proveedor = ProveedorSimulador();
      await proveedor.cargarProyectoCompleto(json);

      expect(proveedor.error, isNull);
      expect(proveedor.estructuraCapital?.pctPropio, equals(100.0));
      expect(proveedor.estructuraCapital?.inversionRequerida, equals(1000000.0));
      expect(proveedor.estructuraCapital?.plazoMeses, equals(36));
    });

    test('Notifica exactamente una vez al cargar', () async {
      final original = _proyectoCompleto();
      final json = jsonDecode(jsonEncode(original.exportarSesion())) as Map<String, dynamic>;

      final proveedor = ProveedorSimulador();
      var notificaciones = 0;
      proveedor.addListener(() => notificaciones++);

      await proveedor.cargarProyectoCompleto(json);

      expect(notificaciones, equals(1));
    });

    test('JSON inválido deja intacto el estado previo', () async {
      final proveedor = _proyectoCompleto();
      final activosAntes = proveedor.inversionRequerida.activos.length;
      final configAntes = proveedor.configTemporal;

      await proveedor.cargarProyectoCompleto({'foo': 'bar'});

      expect(proveedor.error, isNotNull);
      expect(proveedor.inversionRequerida.activos.length, equals(activosAntes));
      expect(proveedor.configTemporal, equals(configAntes));
      expect(proveedor.ingresos.length, equals(6));
    });
  });
}
