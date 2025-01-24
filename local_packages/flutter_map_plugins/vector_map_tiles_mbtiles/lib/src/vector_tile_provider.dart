import 'dart:typed_data';
import 'package:mbtiles/mbtiles.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

/// MBTiles raster TileProvider, use for `pbf` tiles.
class MbTilesVectorTileProvider extends VectorTileProvider {
  /// Create a new [MbTilesVectorTileProvider] and pass it to the flutter_map
  /// vector plugin vector_map_tiles.
  ///
  /// [minimumZoom] defaults to the minimum zoom of the mbtiles metadata.
  ///
  /// [maximumZoom] defaults to the maximum zoom of the mbtiles metadata.
  MbTilesVectorTileProvider({
    required this.mbtiles,
    int? minimumZoom,
    int? maximumZoom,
    @Deprecated(
      'This option is no longer used and will get removed in a future update.',
    )
    this.silenceTileNotFound = false,
  }) {
    // 这里的 minimumZoom 和 maximumZoom 设置为默认值，具体值在 async 方法中设置
    this.minimumZoom = minimumZoom ?? 0;
    this.maximumZoom = maximumZoom ?? 16; // 默认值
  }

  /// MBTiles database
  final MbTiles mbtiles;

  /// Get the metadata of the [MbTiles] archive.
  Future<MbTilesMetadata> get metadata async => mbtiles.getMetadata();

  /// Set to true if you want to silence exceptions that would be thrown if a
  /// tile does not exist in the mbtiles file.
  @Deprecated(
    'This option is no longer used and will get removed in a future update.',
  )
  final bool silenceTileNotFound;

  /// The minimum zoom level
  @override
  late final int minimumZoom;

  /// The maximum zoom level, higher zoom level get "over-zoomed"
  @override
  late final int maximumZoom;

  /// 使用 async 方法设置 minimumZoom 和 maximumZoom
  Future<void> initializeZoomLevels() async {
    final metadata = await this.metadata; // 等待元数据
    minimumZoom = metadata.minZoom?.truncate() ?? 0;
    maximumZoom = metadata.maxZoom?.truncate() ?? 16;
  }

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    final tmsY = ((1 << tile.z) - 1) - tile.y;
    final bytes = await mbtiles.getTile(z: tile.z, x: tile.x, y: tmsY);

    if (bytes == null) {
      throw Exception('Tile could not be found');
    }

    return Uint8List.fromList(bytes); // 确保返回List<int>
  }
}
