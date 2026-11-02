import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:simuladorfinanciero/nucleo/dbayuda.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Migración v3 → v4 conserva inversion y agrega proyecto_json', () async {
    final directorio = Directory.systemTemp.createTempSync('simulador_migracion_');
    final ruta = p.join(directorio.path, 'prueba.db');

    final db = await databaseFactory.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (bd, version) async {
          await bd.execute('''
            CREATE TABLE inversion (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              monto REAL NOT NULL,
              tasa_descuento REAL NOT NULL,
              horizonte_anios INTEGER NOT NULL,
              van REAL NOT NULL
            )
          ''');
          await bd.execute('''
            CREATE TABLE sesion_borrador (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nombre TEXT NOT NULL,
              configuracion_texto TEXT NOT NULL,
              activos_texto TEXT NOT NULL,
              estructura_texto TEXT NOT NULL,
              creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
          ''');
        },
      ),
    );

    await db.insert('inversion', {
      'monto': 123.0,
      'tasa_descuento': 0.12,
      'horizonte_anios': 5,
      'van': 456.0,
    });

    // Ejecuta la misma migración que usa onUpgrade.
    await AyudanteBD.instancia.migrarEsquema(db, 3, 4);

    final filas = await db.query('inversion');
    expect(filas.length, equals(1));
    expect((filas.first['monto'] as num).toDouble(), equals(123.0));
    expect((filas.first['van'] as num).toDouble(), equals(456.0));

    final info = await db.rawQuery('PRAGMA table_info(sesion_borrador)');
    expect(info.any((col) => col['name'] == 'proyecto_json'), isTrue);

    await db.close();
    directorio.deleteSync(recursive: true);
  });
}
