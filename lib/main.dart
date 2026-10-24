import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'controladores/proveedor_simulador.dart';
import 'vistas/diseno_escritorio.dart';
// import 'vistas/diseno_escritorio.dart'; // Descomentar cuando crees el NavigationRail

void main() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProveedorSimulador()),
      ],
      child: const SimuladorApp(),
    ),
  );
}

class SimuladorApp extends StatelessWidget {
  const SimuladorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simulador Riego',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const DisenoEscritorio(), // Aquí inyectas el layout
    );
  }
}