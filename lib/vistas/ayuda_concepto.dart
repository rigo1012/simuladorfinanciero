import 'package:flutter/material.dart';
import '../nucleo/glosario.dart';

/// Icono de ayuda contextual para un término del glosario.
class AyudaConcepto extends StatelessWidget {
  final String termino;
  final double tamanoIcono;

  const AyudaConcepto({super.key, required this.termino, this.tamanoIcono = 16});

  @override
  Widget build(BuildContext context) {
    final definicion = Glosario.buscar(termino);
    if (definicion == null) return const SizedBox.shrink();
    return IconButton(
      icon: Icon(Icons.info_outline, size: tamanoIcono, color: Colors.blue.shade600),
      tooltip: definicion.definicion,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onPressed: () => mostrarAyudaConcepto(context, termino),
    );
  }
}

/// Muestra el diálogo de ayuda de un término. Reutilizable por el glosario.
Future<void> mostrarAyudaConcepto(BuildContext context, String clave) {
  final termino = Glosario.buscar(clave);
  if (termino == null) return Future.value();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              termino.abreviatura != null
                  ? '${termino.nombre} (${termino.abreviatura})'
                  : termino.nombre,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _seccion('Definición', termino.definicion),
              const SizedBox(height: 12),
              _seccion('Cómo se usa aquí', termino.comoSeUsa),
              if (termino.formula != null && termino.formula!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fórmula',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        termino.formula!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

Widget _seccion(String titulo, String contenido) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(contenido, style: const TextStyle(fontSize: 13, height: 1.4)),
    ],
  );
}
