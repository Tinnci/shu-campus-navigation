import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/src/mbtiles_image_provider.dart';
import 'package:mbtiles/mbtiles.dart';

/// MBTiles 栅格 [TileProvider]，用于 `png`、`jpg` 或 `webp` 瓦片。
class MbTilesTileProvider extends TileProvider {
  /// 使用已有的 MBTiles 实例创建一个新的 [MbTilesTileProvider] 实例。
  MbTilesTileProvider({
    required this.mbtiles,
    this.silenceTileNotFound = !kDebugMode,
  }) : _createdInternally = false;

  /// 通过提供 MBTiles 文件的路径创建一个新的 [MbTilesTileProvider] 实例。
  /// MBTiles 数据库将在内部打开。异步工厂方法。
  static Future<MbTilesTileProvider> fromPath({
    required String path,
    bool silenceTileNotFound = !kDebugMode,
  }) async {
    // 使用 MbTiles 的异步工厂方法来创建实例
    final mbtiles = await MbTiles.createInstance(mbtilesPath: path);
    return MbTilesTileProvider(
      mbtiles: mbtiles,
      silenceTileNotFound: silenceTileNotFound,
    );
  }

  /// MBTiles 数据库
  final MbTiles mbtiles;

  /// 如果 MBTiles 文件是在内部创建的，那么连接将在 [dispose] 时关闭。
  final bool _createdInternally;

  /// 如果不想为未找到的瓦片抛出异常，将此项设置为 true。
  /// 在调试模式下默认值为 false，其他情况下为 true。
  final bool silenceTileNotFound;

  /// 获取指定坐标的瓦片图像
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MbTilesImageProvider(
        coordinates: coordinates,
        mbtiles: mbtiles,
        silenceTileNotFound: silenceTileNotFound,
      );

  /// 销毁 MBTiles 资源
  @override
  void dispose() {
    if (_createdInternally) {
      mbtiles.dispose(); // 仅在内部创建时销毁连接
    }
    super.dispose();
  }
}
