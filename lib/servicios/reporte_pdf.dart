import 'dart:math' as math;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'motor_fen.dart';
import 'evaluador_financiero.dart';
import '../modelos/estructura_capital.dart';

/// Generador de reportes PDF para la evaluación financiera.
class ReportePDF {
  /// Genera y guarda/imprime el reporte PDF completo.
  static Future<Uint8List> generar({
    required ResultadoEvaluacion evaluacion,
    required String nombreProyecto,
    required String nombreUsuario,
  }) async {
    final pdf = pw.Document();
    final eval = evaluacion;
    final motor = eval.motorFEN;
    final flujos = motor.flujos;
    final estructura = motor.estructura;

    // Colores
    final colorPrimary = PdfColors.blue800;
    final colorSuccess = PdfColors.green800;
    final colorDanger = PdfColors.red800;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          // 1. Header
          _buildHeader(nombreProyecto, nombreUsuario, colorPrimary),
          pw.SizedBox(height: 16),
          
          // 2. Resumen Ejecutivo
          _buildResumenEjecutivo(eval, colorPrimary, colorSuccess, colorDanger),
          pw.SizedBox(height: 16),
          
          // 3. Configuración del Proyecto
          _buildConfiguracionProyecto(motor, colorPrimary),
          pw.SizedBox(height: 16),
          
          // 4. Estructura de Capital
          if (estructura != null) ...[
            _buildEstructuraCapital(estructura, motor, colorPrimary),
            pw.SizedBox(height: 16),
          ],
          
          // 5. Indicadores Financieros
          _buildIndicadoresFinancieros(eval, colorPrimary, colorSuccess, colorDanger),
          pw.SizedBox(height: 16),
          
          // 6. Tabla de Flujo de Caja
          _buildTablaFlujoCaja(flujos, colorPrimary),
          pw.SizedBox(height: 16),
          
          // 7. Amortización (si hay deuda)
          if (estructura != null && estructura.tieneDeuda) ...[
            _buildTablaAmortizacion(motor, colorPrimary),
            pw.SizedBox(height: 16),
          ],
          
          // 8. Sensibilidad
          _buildAnalisisSensibilidad(motor, colorPrimary),
        ],
      ),
    );

    return pdf.save();
  }

  /// Genera el PDF y lo comparte/imprime.
  static Future<void> guardarEImprimir({
    required ResultadoEvaluacion evaluacion,
    required String nombreProyecto,
    required String nombreUsuario,
  }) async {
    final bytes = await generar(
      evaluacion: evaluacion,
      nombreProyecto: nombreProyecto,
      nombreUsuario: nombreUsuario,
    );
    
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'Evaluacion_${nombreProyecto.replaceAll(' ', '_')}_${DateTime.now().toIso8601String().split('T')[0]}.pdf',
    );
  }

  // ==================== WIDGETS DE CONSTRUCCIÓN ====================

  static pw.Widget _buildHeader(String proyecto, String usuario, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 16),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: color, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'EVALUACIÓN FINANCIERA',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: color),
              ),
              pw.Text(
                proyecto,
                style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Fecha: ${DateTime.now().toString().split(' ')[0]}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
              pw.Text(
                'Usuario: $usuario',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildResumenEjecutivo(ResultadoEvaluacion eval, PdfColor primary, PdfColor success, PdfColor danger) {
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                'Resumen Ejecutivo',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: primary),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildKPICard('VEREDICTO', eval.veredicto, eval.esViable ? success : danger, pw.FontWeight.bold),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildKPICard('VPN', _formatCurrency(eval.vpn), eval.vpn >= 0 ? success : danger),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildKPICard('TIR', eval.tir != null ? '${eval.tir?.toStringAsFixed(2)}%' : 'N/A', primary),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildKPICard('Payback', eval.paybackPeriodos != null ? '${eval.paybackPeriodos} periodos' : 'No recupera', primary),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildKPICard('B/C', eval.beneficioCosto.toStringAsFixed(2), eval.beneficioCosto >= 1 ? success : danger),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildKPICard('ROI Aporte', eval.kpis['roi_aporte'] != null ? '${eval.kpis['roi_aporte'].toStringAsFixed(1)}%' : 'N/A', primary),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            eval.esViable
                ? 'El proyecto genera valor presente neto positivo. La inversión es rentable a la TREMA definida.'
                : 'El proyecto NO genera valor presente neto positivo. La inversión no cubre el costo de oportunidad.',
            style: pw.TextStyle(fontSize: 11, color: eval.esViable ? success : danger, fontStyle: pw.FontStyle.italic),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildKPICard(String label, String value, PdfColor color, [pw.FontWeight weight = pw.FontWeight.normal]) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: weight, color: color)),
        ],
      ),
    );
  }

  static pw.Widget _buildConfiguracionProyecto(ResultadoMotorFEN motor, PdfColor primary) {
    final config = motor.config;
    return _buildSection(
      'Configuración del Proyecto',
      primary,
      [
        _buildInfoRow('Horizonte de proyección', '${config.anosProyeccion} años (${config.totalMeses} meses)'),
        _buildInfoRow('Duración del periodo', '${config.mesesPorPeriodo} meses'),
        _buildInfoRow('Ciclos por año', '${config.cosechasPorAnio}'),
        _buildInfoRow('Total de periodos', '${config.totalPeriodos}'),
        _buildInfoRow('Periodos evaluados', '${motor.horizontePeriodos}'),
        _buildInfoRow('TREMA (Tasa de descuento)', '${(motor.trema * 100).toStringAsFixed(2)}%'),
        _buildInfoRow('Valor residual', '${(motor.valorResidualPct * 100).toStringAsFixed(0)}% de inversión'),
      ],
    );
  }

  static pw.Widget _buildEstructuraCapital(EstructuraCapital estructura, ResultadoMotorFEN motor, PdfColor primary) {
    return _buildSection(
      'Estructura de Capital y Financiamiento',
      primary,
      [
        _buildInfoRow('Inversión Requerida', _formatCurrency(motor.inversionRequerida)),
        _buildInfoRow('Capital Propio (${estructura.pctPropio.toStringAsFixed(1)}%)', _formatCurrency(motor.aportePropio)),
        _buildInfoRow('Financiamiento / Deuda (${estructura.pctDeuda.toStringAsFixed(1)}%)', _formatCurrency(motor.montoPrestamo)),
        if (estructura.tieneDeuda) ...[
          _buildInfoRow('Tasa de Interés Anual', '${estructura.tasaInteresAnual?.toStringAsFixed(2)}%'),
          _buildInfoRow('Plazo del Crédito', '${estructura.plazoMeses} meses'),
          _buildInfoRow('Cuota Mensual (Sistema Francés)', _formatCurrency(estructura.cuotaMensual)),
          _buildInfoRow('Total Intereses (vida préstamo)', _formatCurrency(estructura.generarTablaAmortizacion().fold(0, (s, a) => s + a.interes))),
        ],
      ],
    );
  }

  static pw.Widget _buildIndicadoresFinancieros(ResultadoEvaluacion eval, PdfColor primary, PdfColor success, PdfColor danger) {
    final kpis = eval.kpis;
    
    return _buildSection(
      'Indicadores Financieros Principales',
      primary,
      [
        _buildInfoRow('VPN (con financiamiento)', _formatCurrency(eval.vpn), valueColor: eval.vpn >= 0 ? PdfColors.green800 : PdfColors.red800),
        _buildInfoRow('VPN Operativo (sin financiamiento)', _formatCurrency(eval.vpnOperativo), valueColor: eval.vpnOperativo >= 0 ? PdfColors.green800 : PdfColors.red800),
        _buildInfoRow('TIR (con financiamiento)', eval.tir != null ? '${eval.tir?.toStringAsFixed(2)}%' : 'No calculable'),
        _buildInfoRow('TIR Operativa', eval.tirOperativa != null ? '${eval.tirOperativa?.toStringAsFixed(2)}%' : 'No calculable'),
        _buildInfoRow('Payback Simple', eval.paybackPeriodos != null ? '${eval.paybackPeriodos} periodos' : 'No recupera'),
        _buildInfoRow('Payback Descontado', eval.paybackDescontado != null ? '${eval.paybackDescontado} periodos' : 'No recupera'),
        _buildInfoRow('Beneficio / Costo (B/C)', eval.beneficioCosto.toStringAsFixed(2)),
        _buildInfoRow('B/C Operativo', eval.beneficioCostoOperativo.toStringAsFixed(2)),
        _buildInfoRow('ROI sobre Inversión', '${kpis['roi']?.toStringAsFixed(1)}%'),
        _buildInfoRow('ROI sobre Aporte Propio', '${kpis['roi_aporte']?.toStringAsFixed(1)}%'),
        _buildInfoRow('Margen EBITDA', '${kpis['margen_ebitda']?.toStringAsFixed(1)}%'),
        _buildInfoRow('Margen Neto', '${kpis['margen_neto']?.toStringAsFixed(1)}%'),
        _buildInfoRow('Total Ingresos', _formatCurrency(kpis['total_ingresos'] ?? 0)),
        _buildInfoRow('Total Costos Variables', _formatCurrency(kpis['total_costos_variables'] ?? 0)),
        _buildInfoRow('Total Costos Fijos', _formatCurrency(kpis['total_costos_fijos'] ?? 0)),
        _buildInfoRow('Total Intereses', _formatCurrency(kpis['total_intereses'] ?? 0)),
        _buildInfoRow('Total Amortización Capital', _formatCurrency(kpis['total_amortizacion_capital'] ?? 0)),
        _buildInfoRow('EBITDA Total', _formatCurrency(kpis['ebitda_total'] ?? 0)),
        _buildInfoRow('Utilidad Total', _formatCurrency(kpis['utilidad_total'] ?? 0)),
        _buildInfoRow('Flujo de Caja Total', _formatCurrency(kpis['flujo_caja_total'] ?? 0)),
        _buildInfoRow('Valor Residual', _formatCurrency(kpis['valor_residual'] ?? 0)),
      ],
    );
  }

  static pw.Widget _buildTablaFlujoCaja(List<FlujoPeriodo> flujos, PdfColor primary) {
    return _buildSection(
      'Flujo de Caja Detallado por Periodo',
      primary,
      [
        pw.Text('Incluye: Ingresos, Costos Variables, Costos Fijos, EBITDA, Intereses, UAI, Amortización, Liquidación, Valor Residual, Flujo de Caja Neto', 
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: ['Per.', 'Mes', 'Ingresos', 'Cost. Var.', 'Cost. Fix', 'EBITDA', 'Intereses', 'UAI', 'Amort. Cap.', 'Liq. Saldo', 'Val. Res.', 'FLUJO CAJA'],
          data: flujos.map((f) => [
            f.periodo.toString(),
            '${f.mesInicio}-${f.mesFin}',
            _formatCurrency(f.ingreso),
            _formatCurrency(f.costoVariable),
            _formatCurrency(f.costoFijo),
            _formatCurrency(f.ebitda),
            _formatCurrency(f.interes),
            _formatCurrency(f.uai),
            _formatCurrency(f.amortizacionCapital),
            _formatCurrency(f.liquidacionSaldo),
            _formatCurrency(f.valorResidual),
            _formatCurrency(f.flujoCaja),
          ]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: primary),
          cellStyle: pw.TextStyle(fontSize: 7),
          cellAlignment: pw.Alignment.centerRight,
          columnWidths: {
            0: const pw.FixedColumnWidth(30),
            1: const pw.FixedColumnWidth(50),
            2: const pw.FixedColumnWidth(70),
            3: const pw.FixedColumnWidth(70),
            4: const pw.FixedColumnWidth(70),
            5: const pw.FixedColumnWidth(70),
            6: const pw.FixedColumnWidth(60),
            7: const pw.FixedColumnWidth(70),
            8: const pw.FixedColumnWidth(70),
            9: const pw.FixedColumnWidth(60),
            10: const pw.FixedColumnWidth(60),
            11: const pw.FixedColumnWidth(80),
          },
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        ),
      ],
    );
  }

  static pw.Widget _buildTablaAmortizacion(ResultadoMotorFEN motor, PdfColor primary) {
    final estructura = motor.estructura;
    if (estructura == null) return pw.SizedBox();
    final mesesPorPeriodo = motor.config.mesesPorPeriodo;
    final resumen = estructura.resumenPorPeriodos(mesesPorPeriodo, motor.horizontePeriodos);
    
    return _buildSection(
      'Tabla de Amortización por Periodos del Proyecto (Sistema Francés)',
      primary,
      [
        pw.Text('Cuota mensual: ${_formatCurrency(estructura.cuotaMensual)} | Tasa: ${estructura.tasaInteresAnual?.toStringAsFixed(2)}% | Plazo: ${estructura.plazoMeses} meses',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: ['Periodo', 'Cuotas Totales', 'Interés (P&G)', 'Capital (Flujo)', 'Saldo Final'],
          data: resumen.map((r) => [
            'P${r.periodo}',
            _formatCurrency(r.totalCuotas),
            _formatCurrency(r.totalInteres),
            _formatCurrency(r.totalCapital),
            _formatCurrency(r.saldoFinal),
          ]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: primary),
          cellStyle: pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerRight,
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Nota: Interés va en Estado de Resultados (gasto). Capital va en Flujo de Caja (salida). '
          'Saldo final del último periodo se liquida en el Motor FEN.',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
        ),
      ],
    );
  }

  static pw.Widget _buildAnalisisSensibilidad(ResultadoMotorFEN motor, PdfColor primary) {
    final trema = motor.trema;
    
    // Sensibilidad: VPN vs TREMA
    final tasas = [trema * 0.5, trema * 0.75, trema, trema * 1.25, trema * 1.5];
    final vpns = tasas.map((t) => _calcularVPN(motor.flujosParaVPN, t)).toList();
    
    return _buildSection(
      'Análisis de Sensibilidad: VPN vs Tasa de Descuento',
      primary,
      [
        pw.Table.fromTextArray(
          headers: ['Tasa de Descuento', 'VPN', 'Viable'],
          data: List.generate(tasas.length, (i) => [
            '${(tasas[i] * 100).toStringAsFixed(1)}%',
            _formatCurrency(vpns[i]),
            vpns[i] > 0 ? 'SÍ' : 'NO',
          ]),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: primary),
          cellStyle: pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerRight,
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Muestra cómo cambia el VPN al variar la TREMA. '
          'Punto de inflexión (VPN=0) aproximado = TIR del proyecto.',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
        ),
      ],
    );
  }

  // ==================== HELPERS ====================

  static pw.Widget _buildSection(String title, PdfColor color, List<pw.Widget> children) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children),
        ),
      ],
    );
  }

  static pw.Widget _buildInfoRow(String label, String value, {PdfColor? valueColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: valueColor ?? PdfColors.grey900)),
        ],
      ),
    );
  }

  static String _formatCurrency(double value) {
    final sign = value < 0 ? '-' : '';
    final abs = value.abs();
    final formatted = abs.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$sign\$ $formatted';
  }

  static double _calcularVPN(List<double> flujos, double tasa) {
    double vpn = 0.0;
    for (int t = 0; t < flujos.length; t++) {
      vpn += flujos[t] / math.pow(1 + tasa, t);
    }
    return vpn;
  }
}