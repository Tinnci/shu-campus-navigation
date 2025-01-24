import 'dart:typed_data';
import 'package:logging/logging.dart' as log;
import 'package:mbtiles/src/model/mbtiles_metadata.dart';
import 'package:mbtiles/src/repository/metadata.dart';
import 'package:mbtiles/src/repository/tiles.dart';
import 'package:path/path.dart'; // 确保导入path库
import 'package:sqflite/sqflite.dart';

/// MbTiles 类，用于管理和操作 MBTiles 数据库
class MbTiles {
  // 数据库不可编辑时的断言消息
  static const _notEditableAssertMsg =
      '数据库不可编辑，请设置参数 `MBTiles(..., editable: true)`。';
  
  late final Database _database; // 数据库实例
  late final MetadataRepository _metadataRepo; // 元数据仓库
  late final TilesRepository _tileRepo; // 瓦片仓库

  final bool editable; // 数据库是否可编辑
  MbTilesMetadata? _metadata; // 缓存的元数据
  final log.Logger _logger = log.Logger('MbTiles'); // 日志记录器

  /// 私有构造函数
  MbTiles._({
    required this.editable,
  });

  /// 异步工厂构造函数，用于确保初始化完成
  static Future<MbTiles> createInstance({
    required String mbtilesPath, // MBTiles 文件路径
    bool? gzip, // 是否使用 Gzip 压缩
    bool editable = false, // 是否可编辑，默认不可编辑
  }) async {
    final instance = MbTiles._(editable: editable);
    await instance._initializeDatabase(mbtilesPath);
    instance._metadataRepo = MetadataRepository(database: instance._database);
    final metadata = await instance.getMetadata();
    instance._tileRepo = TilesRepository(
      database: instance._database,
      useGzip: gzip ?? (metadata.format == 'pbf'), // 根据格式决定是否使用 Gzip
      logger: instance._logger,
    );
    if (editable) {
      instance.createTables(); // 创建必要的表
    }
    return instance;
  }

  /// 命名构造函数，用于创建新的 MBTiles 数据库并设置元数据
  static Future<MbTiles> createNew({
    required String mbtilesPath, // MBTiles 文件路径
    required MbTilesMetadata metadata, // 初始元数据
  }) async {
    final instance = MbTiles._(editable: true);
    await instance._initializeDatabase(mbtilesPath);
    instance._metadataRepo = MetadataRepository(database: instance._database);
    instance._tileRepo = TilesRepository(
      database: instance._database,
      useGzip: metadata.format == 'pbf', // 根据格式决定是否使用 Gzip
      logger: instance._logger,
    );
    instance.createTables(); // 创建必要的表
    instance.setMetadata(metadata); // 设置元数据
    return instance;
  }

  /// 初始化数据库连接
  Future<void> _initializeDatabase(String mbtilesPath) async {
    final String path = join(await getDatabasesPath(), mbtilesPath);
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        // 可以在这里创建表
      },
    );
    _logger.info('数据库已初始化，路径: $path');
  }

  /// 获取 MBTiles 的元数据
  Future<MbTilesMetadata> getMetadata({bool allowCache = true}) async {
    if (_metadata != null && allowCache) return _metadata!;
    _metadata = await _metadataRepo.getAll();
    _logger.info('已获取元数据: $_metadata');
    return _metadata!;
  }

  /// 获取指定缩放级别、列和行的瓦片数据
  Future<Uint8List?> getTile({
    required int z, // 缩放级别
    required int x, // 列
    required int y, // 行
  }) async {
    //_logger.info('尝试获取缩放级别 z=$z，列 x=$x，行 y=$y 的瓦片');
    return await _tileRepo.getTile(z, x, y);
  }

  /// 创建必要的数据库表
  void createTables() {
    assert(editable, _notEditableAssertMsg);
    _logger.info('创建数据库表');
    _metadataRepo.createTable();
    _tileRepo.createTable();
    _logger.info('数据库表创建完成');
  }

  /// 插入或更新指定缩放级别、列和行的瓦片数据
  void putTile({
    required int z, // 缩放级别
    required int x, // 列
    required int y, // 行
    required Uint8List bytes, // 瓦片数据
  }) {
    assert(editable, _notEditableAssertMsg);
    _logger.info('尝试插入/更新缩放级别 z=$z，列 x=$x，行 y=$y 的瓦片');
    _tileRepo.putTile(z, x, y, bytes);
  }

  /// 设置 MBTiles 的元数据
  void setMetadata(MbTilesMetadata metadata) {
    assert(editable, _notEditableAssertMsg);
    _logger.info('设置元数据: $metadata');
    _metadataRepo.putAll(metadata);
  }

  /// 释放资源，关闭数据库连接
  Future<void> dispose() async {
    _logger.info('释放资源，关闭数据库连接');
    await _database.close();
    _tileRepo.dispose();
    _logger.info('资源已释放，数据库连接已关闭');
  }
}

@Deprecated('MBTiles 已更名为 MbTiles')
typedef MBTiles = MbTiles;
