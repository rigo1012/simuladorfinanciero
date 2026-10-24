import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controladores/proveedor_simulador.dart';
import '../servicios/motor_fen.dart';
import '../servicios/evaluador_financiero.dart';
import '../servicios/reporte_pdf.dart';

/// Vista de Resultados: muestra la evaluación financiera completa con opción a exportar PDF.
class VistaResultados extends StatelessWidget {
  const VistaResultados({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProveedorSimulador>(
      builder: (context, proveedor, _) {
        final resultado = proveedor.ultimoResultado;
        
        if (resultado == null) {
          return _buildEmptyState();
        }

        return _buildResultadosContent(proveedor, resultado);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assessment_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Sin resultados aún',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete el formulario y presione "Calcular Rentabilidad"\npara ver la evaluación financiera aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultadosContent(ProveedorSimulador proveedor, Map<String, dynamic> data) {
    final vpn = (data['vpn'] as num?)?.toDouble() ?? 0;
    final vpnOperativo = (data['vpn_operativo'] as num?)?.toDouble() ?? 0;
    final tir = (data['tir'] as num?)?.toDouble();
    final tirOperativa = (data['tir_operativa'] as num?)?.toDouble();
    final payback = (data['payback_periodos'] as int?);
    final paybackDesc = (data['payback_descontado'] as int?);
    final bc = (data['beneficio_costo'] as num?)?.toDouble() ?? 0;
    final bcOperativo = (data['beneficio_costo_operativo'] as num?)?.toDouble() ?? 0;
    final esViable = (data['es_viable'] as bool?) ?? false;
    final veredicto = data['veredicto'] as String? ?? 'NO VIABLE';
    final kpis = Map<String, dynamic>.from(data['kpis'] ?? {});
    final motorData = data['motor_fen'] as Map<String, dynamic>? ?? {};
    final flujosData = motorData['flujos'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(proveedor, esViable, veredicto, vpn),
          const SizedBox(height: 24),
          _buildKPIsGrid(vpn, vpnOperativo, tir, tirOperativa, payback, paybackDesc, bc, bcOperativo, kpis),
          const SizedBox(height: 24),
          _buildDetailTabs(flujosData, kpis),
        ],
      ),
    );
  }

  Widget _buildHeader(ProveedorSimulador proveedor, bool esViable, String veredicto, double vpn) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Evaluación Financiera',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Resultados de la simulación del proyecto de riego',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf, size: 20),
              label: const Text('Exportar PDF'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                side: BorderSide(color: Colors.red.shade400, width: 2),
                foregroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _exportarPDF(proveedor),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Recalcular'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _recalcular(proveedor),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKPIsGrid(
    double vpn, double vpnOperativo, double? tir, double? tirOperativa,
    int? payback, int? paybackDesc, double bc, double bcOp, Map<String, dynamic> kpis) {
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _KPICard(label: 'VPN', value: _formatCurrency(vpn), icon: Icons.attach_money, color: vpn >= 0 ? Colors.green : Colors.red)),
            const SizedBox(width: 12),
            Expanded(child: _KPICard(label: 'VPN Operativo', value: _formatCurrency(vpnOperativo), icon: Icons.business, color: vpnOperativo >= 0 ? Colors.green : Colors.red)),
            const SizedBox(width: 12),
            Expanded(child: _KPICard(label: 'TIR', value: tir != null ? '${tir.toStringAsFixed(2)}%' : 'N/A', icon: Icons.trending_up, color: Colors.blue)),
            const SizedBox(width: 12),
            Expanded(child: _KPICard(label: 'TIR Operativa', value: tirOperativa != null ? '${tirOperativa.toStringAsFixed(2)}%' : 'N/A', icon: Icons.trending_up, color: Colors.indigo)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _KPICard(label: 'Payback', value: payback != null ? '$payback periodos' : 'No recupera', icon: Icons.timer, color: payback != null ? Colors.green : Colors.orange)),
            const SizedBox(width: 12),
            Expanded(child: _KPICard(label: 'Payback Desc.', value: paybackDesc != null ? '$paybackDesc periodos' : 'No recupera', icon: Icons.timer_off, color: paybackDesc != null ? Colors.green : Colors.orange)),
            const SizedBox(width: 12),
            Expanded(child: _KPICard(label: 'B/C', value: bc.toStringAsFixed(2), icon: Icons.balance, color: bc >= 1 ? Colors.green : Colors.red)),
            const SizedBox(width: 12),
            Expanded(child: _KPICard(label: 'B/C Oper.', value: bcOp.toStringAsFixed(2), icon: Icons.balance, color: bcOp >= 1 ? Colors.green : Colors.red)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _KPICard(label: 'ROI Inversión', value: '${kpis['roi']?.toStringAsFixed(1) ?? 0}%', icon: Icons.percent, color: Colors.purple)),
            const SizedBox(width: 12),
            Expanded(child: _KPICard(label: 'ROI Aporte', value: '${kpis['roi_aporte']?.toStringAsFixed(1) ?? 0}%', icon: Icons.account_balance_wallet, color: Colors.teal)),
            const SizedBox(width: 12),
            Expanded(child: _KPICard(label: 'Margen EBITDA', value: '${kpis['margen_ebitda']?.toStringAsFixed(1) ?? 0}%', icon: Icons.show_chart, color: Colors.deepOrange)),
            const SizedBox(width: 12),
            Expanded(child: _KPICard(label: 'Margen Neto', value: '${kpis['margen_neto']?.toStringAsFixed(1) ?? 0}%', icon: Icons.analytics, color: Colors.cyan)),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailTabs(List<dynamic> flujosData, Map<String, dynamic> kpis) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            labelColor: Colors.blue.shade700,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.blue.shade700,
            tabs: const [
              Tab(icon: Icon(Icons.table_chart), text: 'Flujo de Caja'),
              Tab(icon: Icon(Icons.account_balance), text: 'Amortización'),
              Tab(icon: Icon(Icons.analytics), text: 'KPIs Detalle'),
              Tab(icon: Icon(Icons.insights), text: 'Sensibilidad'),
            ],
          ),
          SizedBox(
            height: 500,
            child: TabBarView(
              children: [
                _buildFlujoCajaTab(flujosData),
                _buildAmortizacionTab(),
                _buildKPIsDetalleTab(kpis),
                _buildSensibilidadTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlujoCajaTab(List<dynamic> flujosData) {
    if (flujosData.isEmpty) {
      return Center(child: Text('Sin datos de flujo de caja', style: TextStyle(color: Colors.grey.shade600)));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(Colors.blue.shade100),
        columns: const [
          DataColumn(label: Text('Per.')),
          DataColumn(label: Text('Mes'), numeric: true),
          DataColumn(label: Text('Ingresos'), numeric: true),
          DataColumn(label: Text('Cost. Var.'), numeric: true),
          DataColumn(label: Text('Cost. Fix'), numeric: true),
          DataColumn(label: Text('EBITDA'), numeric: true),
          DataColumn(label: Text('Intereses'), numeric: true),
          DataColumn(label: Text('UAI'), numeric: true),
          DataColumn(label: Text('Amort. Cap.'), numeric: true),
          DataColumn(label: Text('Liq. Saldo'), numeric: true),
          DataColumn(label: Text('Val. Res.'), numeric: true),
          DataColumn(label: Text('FLUJO CAJA'), numeric: true),
        ],
        rows: flujosData.map((f) {
          final map = Map<String, dynamic>.from(f);
          return DataRow(cells: [
            DataCell(Text(map['periodo'].toString())),
            DataCell(Text('${map['mes_inicio']}-${map['mes_fin']}')),
            DataCell(Text(_formatCurrency(map['ingreso']))),
            DataCell(Text(_formatCurrency(map['costo_variable']))),
            DataCell(Text(_formatCurrency(map['costo_fijo']))),
            DataCell(Text(_formatCurrency(map['ebitda']))),
            DataCell(Text(_formatCurrency(map['interes']))),
            DataCell(Text(_formatCurrency(map['uai']))),
            DataCell(Text(_formatCurrency(map['amortizacion_capital']))),
            DataCell(Text(_formatCurrency(map['liquidacion_saldo']))),
            DataCell(Text(_formatCurrency(map['valor_residual']))),
            DataCell(Text(_formatCurrency(map['flujo_caja']), style: const TextStyle(fontWeight: FontWeight.bold))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildAmortizacionTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Tabla de Amortización',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Disponible en el reporte PDF completo.\nIncluye: cuotas, intereses, capital, saldo por periodo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIsDetalleTab(Map<String, dynamic> kpis) {
    final entries = kpis.entries.toList();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: entries.map((e) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Icon(Icons.analytics, color: Colors.blue.shade700, size: 20),
            ),
            title: Text(e.key.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${e.value}'),
            trailing: Text(
              e.value is double ? (e.value as double).toStringAsFixed(2) : e.value.toString(),
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildSensibilidadTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insights, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Análisis de Sensibilidad',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'VPN vs Tasa de Descuento (TREMA).\nDisponible en el reporte PDF completo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Future<void> _exportarPDF(ProveedorSimulador proveedor) async {
    try {
      // Mostrar loading
      showDialog(
        context: proveedor.context!,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );
      
      // Generar PDF usando el servicio
      await ReportePDF.guardarEImprimir(
        evaluacion: _reconstruirEvaluacion(proveedor),
        nombreProyecto: 'Sistema de Riego',
        nombreUsuario: 'Usuario',
      );
      
      Navigator.pop(proveedor.context!);
      
      ScaffoldMessenger.of(proveedor.context!).showSnackBar(
        const SnackBar(content: Text('PDF generado y compartido exitosamente'), backgroundColor: Colors.green),
      );
    } catch (e) {
      Navigator.pop(proveedor.context!);
      ScaffoldMessenger.of(proveedor.context!).showSnackBar(
        SnackBar(content: Text('Error generando PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _recalcular(ProveedorSimulador proveedor) async {
    proveedor.procesarSimulacionSimple(
      proveedor.ultimaTREMA > 0 ? proveedor.ultimaTREMA : 12.0,
      proveedor.ultimoHorizonte > 0 ? proveedor.ultimoHorizonte : 5,
    );
  }

  ResultadoEvaluacion _reconstruirEvaluacion(ProveedorSimulador proveedor) {
    return EvaluadorFinanciero.evaluar(
      MotorFEN.calcular(
        proveedor: proveedor,
        tremaPct: proveedor.ultimaTREMA > 0 ? proveedor.ultimaTREMA : 12.0,
        horizonteAnios: proveedor.ultimoHorizonte > 0 ? proveedor.ultimoHorizonte : 5,
      ),
    );
  }

  String _formatCurrency(double value) {
    final sign = value < 0 ? '-' : '';
    final abs = value.abs();
    final formatted = abs.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$sign\$ $formatted';
  }
}

class _KPICard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KPICard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}