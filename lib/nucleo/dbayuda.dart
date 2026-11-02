import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../modelos/activo.dart';
import '../modelos/configuracion_temporal.dart';
import '../modelos/estructura_capital.dart';

class AyudanteBD {
  static final AyudanteBD instancia = AyudanteBD._init();
  static Database? _baseDatos;

  AyudanteBD._init();

  Future<Database> get baseDatos async {
    final existente = _baseDatos;
    if (existente != null) return existente;
    final nueva = await _initBD('simulador_riego.db');
    _baseDatos = nueva;
    return nueva;
  }

  Future<Database> _initBD(String rutaArchivo) async {
    final rutaBD = await getDatabasesPath();
    final ruta = join(rutaBD, rutaArchivo);
    return await databaseFactoryFfi.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: 4, // v4: columna proyecto_json para proyectos completos
        onCreate: _crearBD,
        onUpgrade: _actualizarBD,
      ),
    );
  }

  Future _crearBD(Database bd, int version) async {
    await bd.execute('''
      CREATE TABLE IF NOT EXISTS inversion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        monto REAL NOT NULL,
        tasa_descuento REAL NOT NULL,
        horizonte_anios INTEGER NOT NULL,
        van REAL NOT NULL 
      )
    ''');

    await bd.execute('''
      CREATE TABLE IF NOT EXISTS sesion_borrador (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        configuracion_texto TEXT NOT NULL,
        activos_texto TEXT NOT NULL,
        estructura_texto TEXT NOT NULL,
        proyecto_json TEXT,
        creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  // Migración NO destructiva: conserva 'inversion' y los borradores existentes.
  Future _actualizarBD(Database bd, int versionAnterior, int versionNueva) async {
    await migrarEsquema(bd, versionAnterior, versionNueva);
  }

  /// Aplica la migración de esquema sin borrar datos. Público para pruebas.
  Future<void> migrarEsquema(Database bd, int versionAnterior, int versionNueva) async {
    if (versionAnterior < 4) {
      // Garantiza que la tabla exista (instalaciones antiguas) sin borrar datos.
      await _crearBD(bd, versionNueva);

      // Agrega la columna solo si aún no existe.
      final info = await bd.rawQuery('PRAGMA table_info(sesion_borrador)');
      final tieneColumna = info.any((col) => col['name'] == 'proyecto_json');
      if (!tieneColumna) {
        await bd.execute('ALTER TABLE sesion_borrador ADD COLUMN proyecto_json TEXT');
      }
    }
  }

  /// Guarda un proyecto completo (JSON serializado).
  Future<int> guardarProyecto(String nombre, String json) async {
    final bd = await baseDatos;
    return await bd.insert('sesion_borrador', {
      'nombre': nombre,
      'configuracion_texto': '',
      'activos_texto': '',
      'estructura_texto': '',
      'proyecto_json': json,
    });
  }

  /// Lista los proyectos guardados sin cargar el JSON pesado.
  Future<List<Map<String, dynamic>>> listarProyectos() async {
    final bd = await baseDatos;
    return await bd.query(
      'sesion_borrador',
      columns: ['id', 'nombre', 'creado_en'],
      where: 'proyecto_json IS NOT NULL',
      orderBy: 'creado_en DESC',
    );
  }

  /// Carga el JSON de un proyecto por su id. Devuelve null si no existe.
  Future<Map<String, dynamic>?> cargarProyectoPorId(int id) async {
    final bd = await baseDatos;
    final filas = await bd.query(
      'sesion_borrador',
      columns: ['proyecto_json'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (filas.isEmpty) return null;
    final raw = filas.first['proyecto_json'];
    if (raw is! String || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }

  /// Elimina un proyecto guardado.
  Future<int> eliminarProyecto(int id) async {
    final bd = await baseDatos;
    return await bd.delete('sesion_borrador', where: 'id = ?', whereArgs: [id]);
  }

  /// Guardar sesión actual como borrador
  Future<int> guardarBorrador(String nombre, ConfiguracionTemporal config, List<Activo> activos, EstructuraCapital estructura) async {
    final bd = await baseDatos;
    final configMap = config.toMap();
    final activosMap = activos.map((a) => a.toMap()).toList();
    final estructuraMap = estructura.toMap();

    return await bd.insert('sesion_borrador', {
      'nombre': nombre,
      'configuracion_texto': jsonEncode(configMap),
      'activos_texto': jsonEncode(activosMap),
      'estructura_texto': jsonEncode(estructuraMap),
    });
  }

  /// Recuperar la última sesión de borrador guardada
  Future<Map<String, dynamic>?> recuperarUltimoBorrador() async {
    final bd = await baseDatos;
    final List<Map<String, dynamic>?> resultado =
        await bd.query('sesion_borrador', orderBy: 'creado_en DESC', limit: 1);

    if (resultado.isEmpty) return null;

    final mapa = resultado.first;
    if (mapa == null) return null;
    return {
      'configuracion_texto': mapa['configuracion_texto'],
      'activos_texto': mapa['activos_texto'],
      'estructura_texto': mapa['estructura_texto'],
    };
  }

  /// Convertir texto JSON a ConfiguracionTemporal
  ConfiguracionTemporal? _configFromJson(String? json) {
    if (json == null) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return ConfiguracionTemporal.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  /// Convertir texto JSON a List<Activo>
  List<Activo>? _activosFromJson(String? json) {
    if (json == null) return null;
    try {
      final List<dynamic> lista = jsonDecode(json);
      return lista.map((e) => Activo.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  /// Convertir texto JSON a EstructuraCapital
  EstructuraCapital? _estructuraFromJson(String? json) {
    if (json == null) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return EstructuraCapital.fromMap(map);
    } catch (_) {
      return null;
    }
  }
}