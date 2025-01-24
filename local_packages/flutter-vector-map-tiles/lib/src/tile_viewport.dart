import 'dart:math';

import 'package:flutter_map/flutter_map.dart';

import '../vector_map_tiles.dart';

class TileViewport {
  final int zoom;
  final Bounds<int> bounds;

  TileViewport(this.zoom, this.bounds);

  /// 判断当前视口是否与给定瓦片有重叠
  bool overlaps(TileIdentity tile) {
    if (tile.z == zoom) {
      final contains = bounds.contains(Point(tile.x, tile.y));
      print('Tile at same zoom level: $tile, contains: $contains');
      return contains;
    }

    final zoomDifference = zoom - tile.z;
    final multiplier = pow(2, zoomDifference.abs()).toInt();

    if (zoomDifference > 0) {
      // 瓦片比视口瓦片大
      final startX = tile.x * multiplier;
      final endX = (tile.x + 1) * multiplier - 1;
      final startY = tile.y * multiplier;
      final endY = (tile.y + 1) * multiplier - 1;

      final tileRange = Bounds<int>(
        Point<int>(startX, startY),
        Point<int>(endX, endY),
      );

      final overlaps = bounds.containsPartialBounds(tileRange);
      print('Tile larger than viewport tile: $tile, overlaps: $overlaps');
      return overlaps;
    } else {
      // 瓦片比视口瓦片小
      final parentX = tile.x ~/ multiplier;
      final parentY = tile.y ~/ multiplier;
      final contains = bounds.contains(Point(parentX, parentY));
      print(
          'Tile smaller than viewport tile: $tile, parent: ($parentX, $parentY), contains: $contains');
      return contains;
    }
  }
}
