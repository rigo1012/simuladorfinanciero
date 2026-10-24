import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class AyudanteBD {
  static final AyudanteBD instancia = AyudanteBD._init();
  static Database? _baseDatos;

  AyudanteBD._init();

  Future<Database> get baseDatos async {
    if (_baseDatos != null) return _baseDatos!;
    _baseDatos = await _initBD('simulador_riego.db');
    return _baseDatos!;
  }

  Future<Database> _initBD(String rutaArchivo) async {
    final rutaBD = await getDatabasesPath();
    final ruta = join(rutaBD, rutaArchivo);
    return await databaseFactoryFfi.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: 2, // Se incrementa la versión para forzar el cambio
        onCreate: _crearBD,
        onUpgrade: _actualizarBD, // Nuevo disparador de migración
      ),
    );
  }

  Future _crearBD(Database bd, int version) async {
    await bd.execute('''
      CREATE TABLE inversion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        monto REAL NOT NULL,
        tasa_descuento REAL NOT NULL,
        horizonte_anios INTEGER NOT NULL,
        van REAL NOT NULL 
      )
    ''');
  }

  // Ejecuta la destrucción controlada de la tabla anterior
  Future _actualizarBD(Database bd, int versionAnterior, int versionNueva) async {
    if (versionAnterior < 2) {
      await bd.execute('DROP TABLE IF EXISTS inversion');
      await _crearBD(bd, versionNueva);
    }
  }
}