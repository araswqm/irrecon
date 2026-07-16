import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/device_type.dart';
import '../models/brand.dart';
import '../models/ir_model.dart';
import '../models/ir_key.dart';
import '../../core/utils/fuzzy_matcher.dart';
import '../../core/constants.dart';

/// A brand search result with fuzzy score and device type context.
class BrandSearchHit {
  final IRBrand brand;
  final String deviceTypeName;
  final double score;
  const BrandSearchHit({
    required this.brand,
    required this.deviceTypeName,
    required this.score,
  });
}

/// A model search result with fuzzy score and parent context.
class ModelSearchHit {
  final IRModel model;
  final String brandName;
  final String deviceTypeName;
  final double score;
  const ModelSearchHit({
    required this.model,
    required this.brandName,
    required this.deviceTypeName,
    required this.score,
  });
}

/// Singleton SQLite database manager for the IRDB index.
class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  Database? _database;

  static const String _dbName = 'irrecon.db';
  static const int _dbVersion = 2;

  // ── Table Names ──
  static const String tableDeviceTypes = 'device_types';
  static const String tableBrands = 'brands';
  static const String tableModels = 'models';
  static const String tableKeys = 'keys';
  static const String tableMetadata = 'metadata';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableDeviceTypes (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableBrands (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        device_type_id INTEGER NOT NULL,
        normalized_name TEXT NOT NULL,
        FOREIGN KEY (device_type_id) REFERENCES $tableDeviceTypes(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableModels (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        brand_id INTEGER NOT NULL,
        file_name TEXT NOT NULL,
        file_url TEXT,
        FOREIGN KEY (brand_id) REFERENCES $tableBrands(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableKeys (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT DEFAULT 'parsed',
        protocol TEXT,
        address TEXT,
        command TEXT,
        frequency INTEGER,
        duty_cycle REAL,
        data TEXT,
        model_id INTEGER NOT NULL,
        FOREIGN KEY (model_id) REFERENCES $tableModels(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableMetadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Create indexes for fast lookup
    await db.execute(
        'CREATE INDEX idx_brands_device_type ON $tableBrands(device_type_id)');
    await db.execute(
        'CREATE INDEX idx_brands_normalized ON $tableBrands(normalized_name)');
    await db.execute(
        'CREATE INDEX idx_models_brand ON $tableModels(brand_id)');
    await db.execute(
        'CREATE INDEX idx_keys_model ON $tableKeys(model_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE $tableKeys ADD COLUMN frequency INTEGER');
      await db.execute(
          'ALTER TABLE $tableKeys ADD COLUMN duty_cycle REAL');
      await db.execute(
          'ALTER TABLE $tableKeys ADD COLUMN data TEXT');
    }
  }

  // ── Device Types ──

  Future<List<DeviceType>> getDeviceTypes() async {
    final db = await database;
    final maps = await db.query(tableDeviceTypes, orderBy: 'name ASC');
    return maps.map((m) => DeviceType.fromMap(m)).toList();
  }

  // ── Brands ──

  Future<List<IRBrand>> getBrandsByDeviceType(int deviceTypeId) async {
    final db = await database;
    final maps = await db.query(
      tableBrands,
      where: 'device_type_id = ?',
      whereArgs: [deviceTypeId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => IRBrand.fromMap(m)).toList();
  }

  /// Fuzzy search brands by normalized name.
  Future<List<IRBrand>> searchBrands(String query) async {
    final db = await database;
    final maps = await db.query(
      tableBrands,
      where: 'normalized_name LIKE ?',
      whereArgs: ['%${query.toLowerCase()}%'],
      orderBy: 'name ASC',
      limit: 20,
    );
    return maps.map((m) => IRBrand.fromMap(m)).toList();
  }

  // ── Models ──

  Future<List<IRModel>> getModelsByBrand(int brandId) async {
    final db = await database;
    final maps = await db.query(
      tableModels,
      where: 'brand_id = ?',
      whereArgs: [brandId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => IRModel.fromMap(m)).toList();
  }

  Future<List<IRModel>> searchModels(String query) async {
    final db = await database;
    final maps = await db.query(
      tableModels,
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
      limit: 20,
    );
    return maps.map((m) => IRModel.fromMap(m)).toList();
  }

  /// Levenshtein-based fuzzy brand search with device type context.
  ///
  /// Scores all brands against [query] using [FuzzyMatcher.similarityIgnoreCase].
  /// Returns matches above [matchThreshold] (0.6), sorted by score descending.
  /// Includes the device type name so the UI can disambiguate (e.g. Samsung/TV vs Samsung/AC).
  Future<List<BrandSearchHit>> fuzzySearchBrands(String query) async {
    final db = await database;
    final allBrands = await db.query(tableBrands, orderBy: 'normalized_name ASC');
    final dtMaps = await db.query(tableDeviceTypes);
    final dtNames = {for (final m in dtMaps) m['id'] as int: m['name'] as String};

    final threshold = AppConstants.matchThreshold;
    final results = <BrandSearchHit>[];
    for (final map in allBrands) {
      final brand = IRBrand.fromMap(map);
      final score = FuzzyMatcher.similarityIgnoreCase(query, brand.normalizedName);
      if (score >= threshold) {
        results.add(BrandSearchHit(
          brand: brand,
          deviceTypeName: dtNames[brand.deviceTypeId] ?? 'Unknown',
          score: score,
        ));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(50).toList();
  }

  /// Levenshtein-based fuzzy model search with brand and device type context.
  Future<List<ModelSearchHit>> fuzzySearchModels(String query) async {
    final db = await database;
    final allModels = await db.query(tableModels, orderBy: 'name ASC');
    final brandMaps = await db.query(tableBrands);
    final brands = {for (final m in brandMaps) m['id'] as int: IRBrand.fromMap(m)};
    final dtMaps = await db.query(tableDeviceTypes);
    final dtNames = {for (final m in dtMaps) m['id'] as int: m['name'] as String};

    final threshold = AppConstants.matchThreshold;
    final results = <ModelSearchHit>[];
    for (final map in allModels) {
      final model = IRModel.fromMap(map);
      final score = FuzzyMatcher.similarityIgnoreCase(query, model.name);
      if (score >= threshold) {
        final brand = brands[model.brandId];
        results.add(ModelSearchHit(
          model: model,
          brandName: brand?.name ?? 'Unknown',
          deviceTypeName: brand != null ? dtNames[brand.deviceTypeId] ?? 'Unknown' : 'Unknown',
          score: score,
        ));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(50).toList();
  }

  Future<IRModel?> getModelById(int id) async {
    final db = await database;
    final maps = await db.query(
      tableModels,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return IRModel.fromMap(maps.first);
  }

  // ── Keys ──

  Future<List<IRKey>> getKeysByModel(int modelId) async {
    final db = await database;
    final maps = await db.query(
      tableKeys,
      where: 'model_id = ?',
      whereArgs: [modelId],
    );
    return maps.map((m) => IRKey.fromMap(m)).toList();
  }

  // ── Metadata ──

  Future<String?> getMetadata(String key) async {
    final db = await database;
    final maps = await db.query(
      tableMetadata,
      where: '"key" = ?',
      whereArgs: [key],
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  Future<void> setMetadata(String key, String value) async {
    final db = await database;
    await db.insert(
      tableMetadata,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Bulk Insert (for index building) ──

  Future<void> insertDeviceTypes(List<DeviceType> types) async {
    final db = await database;
    final batch = db.batch();
    for (final t in types) {
      batch.insert(tableDeviceTypes, t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertBrands(List<IRBrand> brands) async {
    final db = await database;
    final batch = db.batch();
    for (final b in brands) {
      batch.insert(tableBrands, b.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertModels(List<IRModel> models) async {
    final db = await database;
    final batch = db.batch();
    for (final m in models) {
      batch.insert(tableModels, m.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertKeys(List<IRKey> keys) async {
    final db = await database;
    final batch = db.batch();
    for (final k in keys) {
      batch.insert(tableKeys, k.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Clear all data (used before re-import).
  Future<void> clearAll() async {
    final db = await database;
    await db.delete(tableKeys);
    await db.delete(tableModels);
    await db.delete(tableBrands);
    await db.delete(tableDeviceTypes);
    await db.delete(tableMetadata);
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
