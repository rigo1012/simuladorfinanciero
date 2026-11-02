import 'package:flutter/material.dart';
import '../nucleo/glosario.dart';
import 'ayuda_concepto.dart';

/// Pantalla con todos los términos del glosario y búsqueda simple.
class PantallaGlosario extends StatefulWidget {
  const PantallaGlosario({super.key});

  @override
  State<PantallaGlosario> createState() => _PantallaGlosarioState();
}

class _PantallaGlosarioState extends State<PantallaGlosario> {
  final _busquedaCtrl = TextEditingController();
  String _filtro = '';

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  List<TerminoGlosario> get _resultados {
    final texto = _filtro.trim().toLowerCase();
    if (texto.isEmpty) return Glosario.lista;
    return Glosario.lista.where((t) {
      return t.nombre.toLowerCase().contains(texto) ||
          (t.abreviatura ?? '').toLowerCase().contains(texto) ||
          t.definicion.toLowerCase().contains(texto);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final resultados = _resultados;
    return Scaffold(
      appBar: AppBar(title: const Text('Glosario de términos')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _busquedaCtrl,
              decoration: const InputDecoration(
                labelText: 'Buscar término',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (valor) => setState(() => _filtro = valor),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: resultados.isEmpty
                  ? const Center(child: Text('No se encontraron términos.'))
                  : ListView.separated(
                      itemCount: resultados.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final termino = resultados[index];
                        return ListTile(
                          title: Text(
                            termino.abreviatura != null
                                ? '${termino.nombre} (${termino.abreviatura})'
                                : termino.nombre,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            termino.definicion,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => mostrarAyudaConcepto(
                            context,
                            Glosario.terminos.entries
                                .firstWhere((e) => identical(e.value, termino))
                                .key,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
