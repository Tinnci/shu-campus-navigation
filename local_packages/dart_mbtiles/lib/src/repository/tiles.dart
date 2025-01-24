import 'dart:typed_data';
import 'package:logging/logging.dart' as log;
import 'package:mbtiles/src/helper/helpers_io.dart'
    if (dart.library.js_interop) 'package:mbtiles/src/helper/helpers_web.dart';
import 'package:sqflite/sqflite.dart';

/// 瓦片仓库类，用于管理和操作MBTiles中的瓦片数据
class TilesRepository {
  final Database database; // 数据库实例
  final bool useGzip; // 是否使用Gzip压缩
  final log.Logger logger; // 日志记录器

  /// 构造函数
  TilesRepository({
    required this.database,
    required this.useGzip,
    required this.logger,
  });

  /// 获取指定缩放级别、列和行的瓦片数据
  Future<Uint8List?> getTile(int zoom, int column, int row) async {
    //logger.info('尝试获取缩放级别 z=$zoom，列 x=$column，行 y=$row 的瓦片');
    try {
      final List<Map<String, dynamic>> rows = await database.rawQuery(
        '''
        SELECT tile_data FROM tiles 
        WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?
        LIMIT 1;
        ''',
        [zoom, column, row],
      );

      if (rows.isEmpty) {
        //logger.warning('No tile found at z=$zoom, x=$column, y=$row');
        return null;
      }

      final bytes = rows.first['tile_data'] as Uint8List;
      if (!useGzip) {
        //logger.info('在缩放级别 z=$zoom，列 x=$column，行 y=$row 找到瓦片，返回原始字节');
        return bytes;
      }

      logger.info('在缩放级别 z=$zoom，列 x=$column，行 y=$row 找到瓦片，正在解压Gzip数据');
      return bytes.gzipDecode();
    } catch (e) {
      logger.severe('获取缩放级别 z=$zoom，列 x=$column，行 y=$row 的瓦片时出错: $e');
      return null;
    }
  }

  /// 插入或更新指定缩放级别、列和行的瓦片数据
  Future<void> putTile(int zoom, int column, int row, Uint8List bytes) async {
    logger.info('尝试插入/更新缩放级别 z=$zoom，列 x=$column，行 y=$row 的瓦片');
    try {
      await database.insert(
        'tiles',
        {
          'zoom_level': zoom,
          'tile_column': column,
          'tile_row': row,
          'tile_data': useGzip ? bytes.gzipEncode() : bytes,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      logger.info('成功插入/更新缩放级别 z=$zoom，列 x=$column，行 y=$row 的瓦片');
    } catch (e) {
      logger.severe('插入/更新缩放级别 z=$zoom，列 x=$column，行 y=$row 的瓦片时出错: $e');
    }
  }

  /// 获取指定缩放级别下的所有瓦片
  Future<List<Map<String, int>>> getAllTilesAtZoom(int zoom) async {
    logger.info('获取缩放级别 $zoom 下的所有瓦片');
    final rows = await database.rawQuery(
      '''
      SELECT tile_column, tile_row FROM tiles 
      WHERE zoom_level = ?;
      ''',
      [zoom],
    );

    if (rows.isEmpty) {
      logger.warning('在缩放级别 $zoom 未找到任何瓦片');
      return [];
    }

    logger.info('在缩放级别 $zoom 找到 ${rows.length} 个瓦片');

    return rows.map((row) {
      return {
        'x': row['tile_column']! as int,
        'y': row['tile_row']! as int,
      };
    }).toList();
  }

  /// 查找与指定缩放级别、列和行最接近的瓦片
  Future<Map<String, int>?> findClosestTile(int zoom, int column, int row) async {
    //logger.info('尝试查找与 z=$zoom，x=$column，y=$row 最近的瓦片');

    const tolerance = 5; // 可调整的范围
    for (int dx = -tolerance; dx <= tolerance; dx++) {
      for (int dy = -tolerance; dy <= tolerance; dy++) {
        final List<Map<String, dynamic>> rows = await database.rawQuery(
          '''
          SELECT tile_column, tile_row FROM tiles 
          WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?
          LIMIT 1;
          ''',
          [zoom, column + dx, row + dy],
        );

        if (rows.isNotEmpty) {
          final tile = rows.first;
          //logger.info('找到最近的瓦片，列 x=${tile['tile_column']}，行 y=${tile['tile_row']}');
          return {
            'x': tile['tile_column'] as int,
            'y': tile['tile_row'] as int,
          };
        }
      }
    }

    logger.warning('在缩放级别 z=$zoom，列 x=$column，行 y=$row 附近未找到近似瓦片');
    return null;
  }

  /// 创建瓦片表
  Future<void> createTable() async {
    logger.info('尝试创建瓦片表');
    try {
      await database.execute('''
      CREATE TABLE tiles 
      (
        zoom_level INTEGER, 
        tile_column INTEGER, 
        tile_row INTEGER, 
        tile_data BLOB,
        PRIMARY KEY (zoom_level, tile_column, tile_row)
      );
      ''');
      logger.info('瓦片表创建成功');
    } catch (e) {
      logger.severe('创建瓦片表时出错: $e');
    }
  }

  /// 释放资源，关闭数据库连接
  Future<void> dispose() async {
    logger.info('释放准备好的语句并关闭资源');
    try {
      // sqflite 不需要手动处理语句
      await database.close(); // 确保关闭数据库连接
      logger.info('资源成功释放');
    } catch (e) {
      logger.severe('释放资源时出错: $e');
    }
  }
}
