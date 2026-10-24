import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:simuladorfinanciero/main.dart';
import 'package:simuladorfinanciero/controladores/proveedor_simulador.dart';
import 'package:simuladorfinanciero/modelos/activo.dart';
import 'package:simuladorfinanciero/modelos/configuracion_temporal.dart';
import 'package:simuladorfinanciero/modelos/ingreso_periodo.dart';
import 'package:simuladorfinanciero/modelos/costo_variable.dart';
import 'package:simuladorfinanciero/modelos/costo_fijo.dart';
import 'package:simuladorfinanciero/modelos/estructura_capital.dart';
import 'package:simuladorfinanciero/servicios/motor_fen.dart';
import 'package:simuladorfinanciero/servicios/evaluador_financiero.dart';
import 'dart:math' as math;

void main() {
  // Inicializar sqflite_common_ffi para tests
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Prueba de Funcionamiento Completa con Datos Aleatorios', () {
    late ProveedorSimulador proveedor;

    setUp(() {
      proveedor = ProveedorSimulador();
    });

    test('Pipeline completo: Configuración → Activos → Financiamiento → Ingresos → Costos Variables → Costos Fijos → Simulación', () async {
      // ========== PASO 0: CONFIGURACIÓN TEMPORAL ==========
      final config = ConfiguracionTemporal(
        mesesPorPeriodo: 3,      // Trimestral
        anosProyeccion: 5,       // 5 años
        cosechasPorAnio: 2,      // 2 ciclos/año
      );
      expect(config.totalPeriodos, equals(20)); // (5*12)/3 = 20
      expect(config.totalMeses, equals(60));
      
      proveedor.configurarTemporal(config);
      expect(proveedor.estaConfigurado, isTrue);
      expect(proveedor.configTemporal.totalPeriodos, equals(20));

      // ========== PASO 1: ACTIVOS (Inversión Requerida) ==========
      final random = math.Random(42); // Seed fijo para reproducibilidad
      
      final activos = [
        Activo(id: 'a1', nombre: 'Bomba Centrífuga', unidades: 2, costoUnitario: 150000),
        Activo(id: 'a2', nombre: 'Tubería PVC 6"', unidades: 500, costoUnitario: 850),
        Activo(id: 'a3', nombre: 'Sistema Automatización', unidades: 1, costoUnitario: 280000),
        Activo(id: 'a4', nombre: 'Tanque Almacenamiento', unidades: 2, costoUnitario: 95000),
        Activo(id: 'a5', nombre: 'Terreno', unidades: 1, costoUnitario: 500000),
      ];
      
      for (final a in activos) {
        proveedor.agregarActivo(a);
      }
      
      final inversionRequerida = proveedor.inversionRequerida.total;
      // 2*150000 + 500*850 + 1*280000 + 2*95000 + 1*500000 = 300000 + 425000 + 280000 + 190000 + 500000 = 1,695,000
      expect(inversionRequerida, equals(1695000.0));
      expect(proveedor.inversionRequerida.activos.length, equals(5));

      // ========== PASO 2: FINANCIAMIENTO ==========
      final estructura = EstructuraCapital(
        pctPropio: 60.0,
        pctDeuda: 40.0,
        tasaInteresAnual: 12.0,
        plazoMeses: 36,
        inversionRequerida: inversionRequerida,
      );
      
      expect(estructura.pctPropio + estructura.pctDeuda, equals(100.0));
      expect(estructura.montoPrestamo, equals(678000.0)); // 40% de 1,695,000
      expect(estructura.aportePropio, equals(1017000.0)); // 60%
      expect(estructura.tieneDeuda, isTrue);
      expect(estructura.cuotaMensual, greaterThan(0));
      
      proveedor.configurarFinanciamiento(estructura);
      expect(proveedor.estructuraCapital, isNotNull);
      expect(proveedor.tieneDeuda, isTrue);
      expect(proveedor.montoPrestamo, equals(678000.0));
      expect(proveedor.aportePropio, equals(1017000.0));

      // ========== PASO 3: INGRESOS ESTIMADOS ==========
      // Generar ingresos con crecimiento compuesto
      double precioBase = 12.50;
      double demandaBase = 8000;
      double crecPrecio = 0.03; // 3% por periodo
      double crecDemanda = 0.02; // 2% por periodo
      
      for (int p = 1; p <= config.totalPeriodos; p++) {
        final precio = precioBase * math.pow(1 + crecPrecio, p - 1);
        final demanda = demandaBase * math.pow(1 + crecDemanda, p - 1);
        proveedor.actualizarIngreso(IngresoPeriodo(
          periodo: p,
          precio: precio.toDouble(),
          demanda: demanda.toDouble(),
        ));
      }
      
      expect(proveedor.ingresosCompletos, isTrue);
      expect(proveedor.ingresos.length, equals(20));
      
      // Verificar crecimiento
      final ing1 = proveedor.obtenerIngreso(1)!;
      final ing20 = proveedor.obtenerIngreso(20)!;
      expect(ing20.ingreso, greaterThan(ing1.ingreso));

      // ========== PASO 4: COSTOS VARIABLES ==========
      final inflacionAnual = 5.0; // 5% anual
      
      for (int p = 1; p <= config.totalPeriodos; p++) {
        // Materia Prima
        proveedor.agregarItemCostoVariable(p, ItemCostoVariable(
          id: 'cv_mp_${p}_1',
          tipo: TipoCostoVariable.materiaPrima,
          nombre: 'Fertilizantes',
          cantidadUnitaria: 150 + random.nextDouble() * 50,
          costoUnitario: 8.50 + random.nextDouble() * 2,
        ), config.mesesPorPeriodo, inflacionAnual);
        
        proveedor.agregarItemCostoVariable(p, ItemCostoVariable(
          id: 'cv_mp_${p}_2',
          tipo: TipoCostoVariable.materiaPrima,
          nombre: 'Semillas',
          cantidadUnitaria: 80 + random.nextDouble() * 20,
          costoUnitario: 12.00 + random.nextDouble() * 3,
        ), config.mesesPorPeriodo, inflacionAnual);
        
        // Mano de Obra
        proveedor.agregarItemCostoVariable(p, ItemCostoVariable(
          id: 'cv_mo_${p}_1',
          tipo: TipoCostoVariable.manoObra,
          nombre: 'Cosecha',
          costoPorOperacion: 25000 + random.nextDouble() * 5000,
        ), config.mesesPorPeriodo, inflacionAnual);
        
        // Cargos Indirectos
        proveedor.agregarItemCostoVariable(p, ItemCostoVariable(
          id: 'cv_ci_${p}_1',
          tipo: TipoCostoVariable.cargosIndirectos,
          nombre: 'Electricidad Bombeo',
          cantidadUnitaria: 5000 + random.nextDouble() * 1000,
          costoUnitario: 1.80 + random.nextDouble() * 0.5,
        ), config.mesesPorPeriodo, inflacionAnual);
      }
      
      expect(proveedor.costosVariablesCompletos, isTrue);
      expect(proveedor.costosVariables.length, equals(20));
      
      // Verificar que la inflación funciona (periodo 20 > periodo 1)
      final cv1 = proveedor.costoVariableEnPeriodo(1);
      final cv20 = proveedor.costoVariableEnPeriodo(20);
      expect(cv20, greaterThan(cv1));

      // ========== PASO 5: COSTOS FIJOS ==========
      proveedor.setInflacionGlobalFijos(4.0); // 4% anual para fijos
      
      for (int p = 1; p <= config.totalPeriodos; p++) {
        proveedor.agregarItemCostoFijo(p, ItemCostoFijo(
          id: 'cf_${p}_1',
          nombre: 'Sueldo Administrativo',
          monto: 45000,
          aplicarInflacion: true,
        ));
        
        proveedor.agregarItemCostoFijo(p, ItemCostoFijo(
          id: 'cf_${p}_2',
          nombre: 'Renta Oficinas',
          monto: 18000,
          aplicarInflacion: true,
        ));
        
        proveedor.agregarItemCostoFijo(p, ItemCostoFijo(
          id: 'cf_${p}_3',
          nombre: 'Seguros',
          monto: 8500,
          aplicarInflacion: false, // Sin inflación
        ));
      }
      
      expect(proveedor.costosFijosCompletos, isTrue);
      expect(proveedor.costosFijos.length, equals(20));

      // ========== PASO 6: SIMULACIÓN COMPLETA ==========
      final tasaTREMA = 12.0; // 12% anual
      final horizonteAnios = 5;
      
      await proveedor.procesarSimulacionSimple(tasaTREMA, horizonteAnios);
      
      // DEBUG
      print('DEBUG resultado keys: ${proveedor.ultimoResultado?.keys}');
      print('DEBUG tir: ${proveedor.ultimoResultado?['tir']}');
      print('DEBUG tir_operativa: ${proveedor.ultimoResultado?['tir_operativa']}');
      print('DEBUG vpn: ${proveedor.ultimoResultado?['vpn']}');
      
      // Verificar que no hubo errores
      expect(proveedor.error, isNull);
      expect(proveedor.ultimoResultado, isNotNull);
      
      final resultado = proveedor.ultimoResultado!;
      
      // Verificar campos principales
      expect(resultado['vpn'], isA<double>());
      expect(resultado['vpn_operativo'], isA<double>());
      // TIR puede ser null si no converge (proyecto no viable o algoritmo no converge)
      expect(resultado['tir'], anyOf(isA<double>(), isNull));
      expect(resultado['tir_operativa'], anyOf(isA<double>(), isNull));
      expect(resultado['payback_periodos'], anyOf(isA<int>(), isNull));
      expect(resultado['payback_descontado'], anyOf(isA<int>(), isNull));
      expect(resultado['beneficio_costo'], isA<double>());
      expect(resultado['es_viable'], isA<bool>());
      expect(resultado['veredicto'], isA<String>());
      expect(resultado['kpis'], isA<Map<String, dynamic>>());
      expect(resultado['motor_fen'], isA<Map<String, dynamic>>());
      
      final vpn = resultado['vpn'] as double;
      final veredicto = resultado['veredicto'] as String;
      
      final tir = resultado['tir'] as double?;
      final tirOp = resultado['tir_operativa'] as double?;
      final payback = resultado['payback_periodos'] as int?;
      final paybackDesc = resultado['payback_descontado'] as int?;
      
      print('=== RESULTADOS SIMULACIÓN ===');
      print('Inversión Requerida: \$${inversionRequerida.toStringAsFixed(2)}');
      print('Aporte Propio: \$${proveedor.aportePropio.toStringAsFixed(2)}');
      print('Préstamo: \$${proveedor.montoPrestamo.toStringAsFixed(2)}');
      print('Cuota Mensual: \$${proveedor.cuotaMensual.toStringAsFixed(2)}');
      print('TREMA: ${tasaTREMA}%');
      print('Horizonte: ${horizonteAnios} años (${config.totalPeriodos} periodos)');
      print('VPN: \$${vpn.toStringAsFixed(2)}');
      print('VPN Operativo: \$${(resultado['vpn_operativo'] as double).toStringAsFixed(2)}');
      print('TIR: ${tir != null ? tir.toStringAsFixed(2) : "N/A"}%');
      print('TIR Operativa: ${tirOp != null ? tirOp.toStringAsFixed(2) : "N/A"}%');
      print('Payback: ${payback != null ? '$payback periodos' : 'No recupera'}');
      print('Payback Desc: ${paybackDesc != null ? '$paybackDesc periodos' : 'No recupera'}');
      print('B/C: ${(resultado['beneficio_costo'] as double).toStringAsFixed(2)}');
      print('Veredicto: $veredicto');
      
      // Verificar KPIs
      final kpis = resultado['kpis'] as Map<String, dynamic>;
      expect(kpis['roi'], isA<double>());
      expect(kpis['roi_aporte'], isA<double>());
      expect(kpis['margen_ebitda'], isA<double>());
      expect(kpis['total_ingresos'], isA<double>());
      expect(kpis['total_costos_variables'], isA<double>());
      
      // Verificar Motor FEN
      final motorData = resultado['motor_fen'] as Map<String, dynamic>;
      expect(motorData['flujos'], isA<List>());
      final flujos = motorData['flujos'] as List;
      expect(flujos.length, equals(config.totalPeriodos + 1)); // Periodo 0 + N periodos
      
      // Verificar estructura de flujo
      final flujo0 = flujos[0] as Map<String, dynamic>;
      expect(flujo0['periodo'], equals(0));
      expect(flujo0['flujo_caja'], equals(-proveedor.aportePropio)); // Flujo 0 = -aporte propio
      
      final flujo1 = flujos[1] as Map<String, dynamic>;
      expect(flujo1['periodo'], equals(1));
      expect(flujo1['ingreso'], greaterThan(0));
      expect(flujo1['costo_variable'], greaterThan(0));
      expect(flujo1['costo_fijo'], greaterThan(0));
      
      print('\n=== KPIs DETALLADOS ===');
      kpis.forEach((key, value) {
        print('$key: \$${value is double ? value.toStringAsFixed(2) : value}');
      });
      
      print('\n✅ PRUEBA COMPLETA EXITOSA');
    });

    test('Motor FEN directo: Verificar cálculos matemáticos', () {
      // Test unitario del motor con datos conocidos
      proveedor.configurarTemporal(ConfiguracionTemporal(
        mesesPorPeriodo: 6,
        anosProyeccion: 3,
        cosechasPorAnio: 1,
      )); // 6 periodos
      
      proveedor.agregarActivo(Activo(id: 'a1', nombre: 'Test', unidades: 1, costoUnitario: 1000000));
      
      // Verificar que la inversión requerida se calcula correctamente
      expect(proveedor.inversionRequerida.total, equals(1000000.0));
      
      proveedor.configurarFinanciamiento(EstructuraCapital(
        pctPropio: 100,
        pctDeuda: 0,
        inversionRequerida: 1000000,
      ));
      
      // DEBUG: Verificar estado del proveedor
      print('DEBUG: estructuraCapital = ${proveedor.estructuraCapital}');
      print('DEBUG: aportePropio = ${proveedor.aportePropio}');
      print('DEBUG: tieneDeuda = ${proveedor.tieneDeuda}');
      
      // Verificar que el aporte propio se calcula correctamente (100% de 1M = 1M)
      expect(proveedor.aportePropio, equals(1000000.0));
      expect(proveedor.tieneDeuda, isFalse);
      
      // Ingreso fijo por periodo
      for (int p = 1; p <= 6; p++) {
        proveedor.actualizarIngreso(IngresoPeriodo(periodo: p, precio: 100, demanda: 5000));
      }
      
      // Costos fijos
      proveedor.setInflacionGlobalFijos(0);
      for (int p = 1; p <= 6; p++) {
        proveedor.agregarItemCostoFijo(p, ItemCostoFijo(
          id: 'cf1', nombre: 'Fijo', monto: 100000, aplicarInflacion: false,
        ));
      }
      
      // Costos variables
      for (int p = 1; p <= 6; p++) {
        proveedor.agregarItemCostoVariable(p, ItemCostoVariable(
          id: 'cv1', tipo: TipoCostoVariable.materiaPrima,
          nombre: 'Variable', cantidadUnitaria: 1000, costoUnitario: 50,
        ), 6, 0);
      }
      
      final motor = MotorFEN.calcular(
        proveedor: proveedor,
        tremaPct: 10,
        horizonteAnios: 3,
      );
      
      // DEBUG: Verificar flujos
      print('DEBUG: Periodo 0 flujoCaja = ${motor.flujos[0].flujoCaja}');
      for (int p = 1; p <= 6; p++) {
        final f = motor.flujos[p];
        print('DEBUG P$p: ingreso=${f.ingreso}, costVar=${f.costoVariable}, costFix=${f.costoFijo}, ebitda=${f.ebitda}, flujoCaja=${f.flujoCaja}');
      }
      
      expect(motor.flujos.length, equals(7)); // 0 + 6 periodos
      expect(motor.flujos[0].flujoCaja, equals(-1000000.0)); // Periodo 0 = -aporte propio
      
      // Cada periodo: Ingreso 500,000 - CostoVar 50,000 - CostoFix 100,000 = 350,000
      // Último periodo incluye valor residual (10% de 1M = 100,000)
      for (int p = 1; p <= 6; p++) {
        expect(motor.flujos[p].ingreso, equals(500000.0));
        expect(motor.flujos[p].costoVariable, equals(50000.0));
        expect(motor.flujos[p].costoFijo, equals(100000.0));
        expect(motor.flujos[p].ebitda, equals(350000.0));
        final expectedFlujo = p == 6 ? 450000.0 : 350000.0; // Último periodo incluye valor residual 100k
        expect(motor.flujos[p].flujoCaja, equals(expectedFlujo), reason: 'Periodo $p');
      }
      
      final evaluacion = EvaluadorFinanciero.evaluar(motor);
      
      // VPN a 10%: -1M + Σ(350k/(1.1)^t) para t=1..6
      // VPN ≈ -1M + 350k * 4.355 = -1M + 1.524M = 524k
      expect(evaluacion.vpn, greaterThan(0));
      expect(evaluacion.veredicto, equals('VIABLE'));
      expect(evaluacion.tir, greaterThan(10)); // TIR > TREMA si VPN > 0
      
      print('Motor FEN Test - VPN: \$${evaluacion.vpn.toStringAsFixed(0)}');
      print('TIR: ${evaluacion.tir!.toStringAsFixed(2)}%');
      print('Veredicto: ${evaluacion.veredicto}');
    });
  });
}