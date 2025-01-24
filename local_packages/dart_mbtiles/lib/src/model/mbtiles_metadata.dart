import 'package:latlong2/latlong.dart';
import 'package:meta/meta.dart';

/// mbtiles 元数据表的模型类
@immutable
class MbTilesMetadata {
  /// 瓦片集的人类可读名称。（必须包含）
  final String name;

  /// 瓦片数据的文件格式：pbf, jpg, png, webp，
  /// 或其他格式的 IETF 媒体类型。（必须包含）
  final String format;

  /// 渲染地图区域的最大范围。边界必须定义所有缩放级别覆盖的区域。
  /// 边界以 WGS 84 纬度和经度值表示，采用 OpenLayers 边界格式（左，下，
  /// 右，上）。例如，完整地球的边界（不包括极地）为：-180.0,-85,180,85。
  /// （应该包含）
  final MbTilesBounds? bounds;

  /// 地图默认视图的经度和纬度。（应该包含）
  final LatLng? defaultCenter;

  /// 地图默认视图的缩放级别。（应该包含）
  final double? defaultZoom;

  /// 瓦片集提供数据的最低缩放级别。（应该包含）
  final double? minZoom;

  /// 瓦片集提供数据的最高缩放级别。（应该包含）
  final double? maxZoom;

  /// 归属字符串，解释地图的数据来源和/或样式。（可包含）
  final String? attributionHtml;

  /// 文件集内容的描述。（可包含）
  final String? description;

  /// 瓦片层类型，覆盖层或基础层。（可包含）
  final TileLayerType? type;

  /// 瓦片集的版本。指的是瓦片集本身的修订版本，而不是 MBTiles 规范的版本。（可包含）
  final double? version;

  /// 列出矢量瓦片中出现的图层以及这些图层中要素的属性名称和类型。
  /// （如果格式为 pbf，则必须包含）
  final String? json;

  const MbTilesMetadata({
    required this.name,
    required this.format,
    this.bounds,
    this.defaultCenter,
    this.defaultZoom,
    this.minZoom,
    this.maxZoom,
    this.attributionHtml,
    this.description,
    this.type,
    this.version,
    this.json,
  });

  @override
  String toString() {
    var result = 'MBTilesMetadata(name: "$name", format: "$format"';
    if (bounds != null) result += ', bounds: $bounds';
    if (defaultCenter != null) result += ', defaultCenter: $defaultCenter';
    if (defaultZoom != null) result += ', defaultZoom: $defaultZoom';
    if (minZoom != null) result += ', minZoom: $minZoom';
    if (maxZoom != null) result += ', maxZoom: $maxZoom';
    if (attributionHtml != null) {
      result += ', attributionHtml: $attributionHtml';
    }
    if (description != null) result += ', description: $description';
    if (type != null) result += ', type: $type';
    if (version != null) result += ', version: $version';
    if (json != null) result += ', json: $json';
    return '$result)';
  }

  @override
  bool operator ==(Object o) {
    if (o is! MbTilesMetadata) return false;
    return name == o.name &&
        format == o.format &&
        bounds == o.bounds &&
        defaultCenter == o.defaultCenter &&
        defaultZoom == o.defaultZoom &&
        minZoom == o.minZoom &&
        maxZoom == o.maxZoom &&
        attributionHtml == o.attributionHtml &&
        description == o.description &&
        type == o.type &&
        version == o.version &&
        json == o.json;
  }

  @override
  int get hashCode => Object.hash(
        name,
        format,
        bounds,
        defaultCenter,
        defaultZoom,
        minZoom,
        maxZoom,
        attributionHtml,
        description,
        type,
        version,
        json,
      );
}

enum TileLayerType {
  overlay('overlay'),
  baseLayer('baselayer');

  final String name;

  const TileLayerType(this.name);

  @override
  String toString() => name;
}

@immutable
class MbTilesBounds {
  final double bottom;
  final double left;
  final double top;
  final double right;

  const MbTilesBounds({
    required this.bottom,
    required this.left,
    required this.top,
    required this.right,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MbTilesBounds &&
          runtimeType == other.runtimeType &&
          bottom == other.bottom &&
          left == other.left &&
          top == other.top &&
          right == other.right;

  @override
  int get hashCode => Object.hash(
        bottom,
        left,
        top,
        right,
      );

  @override
  String toString() => 'MbTilesBounds($bottom, $left, $top, $right)';
}

@Deprecated('MbTilesMetadata 已更名为 MbTilesMetadata')
typedef MBTilesMetadata = MbTilesMetadata;
