import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:vector_tile/vector_tile_layer.dart';
import 'package:vector_tile/raw/raw_vector_tile.dart' as raw;
import 'package:vector_tile/util/geojson.dart';

export 'package:vector_tile/vector_tile_geom_type.dart';
export 'package:vector_tile/vector_tile_value.dart';
export 'package:vector_tile/vector_tile_feature.dart';
export 'package:vector_tile/vector_tile_layer.dart';
export 'package:vector_tile/util/geojson.dart';
export 'package:vector_tile/util/geometry.dart';

import 'package:logging/logging.dart';
import 'package:archive/archive.dart'; // 用于处理压缩数据

class VectorTile {
  List<VectorTileLayer> layers;

  // 创建一个 Logger 实例，注意命名不要与其他地方的 logger 冲突
  static final Logger vectorTileLogger = Logger('VectorTileLogger');

  VectorTile({
    required this.layers,
  });

  /// decodes the given bytes (`.mvt`/`.pbf`) to a [VectorTile]
  static VectorTile fromBytes({required Uint8List bytes}) {
    vectorTileLogger.info('Starting to parse VectorTile from bytes.');

    // 检查并解压数据
    if (bytes.isNotEmpty && bytes[0] == 0x1F) {
      vectorTileLogger.info('Detected GZIP-compressed data, decompressing...');
      bytes = Uint8List.fromList(GZipDecoder().decodeBytes(bytes));

      // 保存解压后的数据到文件
      final filePath = 'decompressed_tile_data.bin';
      File(filePath).writeAsBytesSync(bytes);
      vectorTileLogger
          .info('Decompressed data saved to $filePath for analysis.');
    }

    // 在解析之前输出原始字节信息
    vectorTileLogger.fine(
        'Raw bytes after decompression (length: ${bytes.length}): $bytes');

    final tile = raw.VectorTile.fromBuffer(bytes);

    vectorTileLogger
        .info('Parsed raw VectorTile with ${tile.layers.length} layers.');

    List<VectorTileLayer> layers = tile.layers.map((rawLayer) {
      vectorTileLogger.fine('Parsing layer: ${rawLayer.name}');
      return VectorTileLayer.fromRaw(rawLayer: rawLayer);
    }).toList(growable: false);

    vectorTileLogger
        .info('Finished parsing VectorTile with ${layers.length} layers.');

    return VectorTile(layers: layers);
  }

  Future<void> toPath({required String path}) async {}

  GeoJsonFeatureCollection toGeoJson(
      {required int x, required int y, required int z}) {
    List<GeoJson?> featuresGeoJson = [];
    this.layers.forEach((layer) {
      int size = layer.extent * (pow(2, z) as int);
      int x0 = layer.extent * x;
      int y0 = layer.extent * y;

      layer.features.forEach((feature) {
        featuresGeoJson.add(
            feature.toGeoJsonWithExtentCalculated(x0: x0, y0: y0, size: size));
      });
    });

    return GeoJsonFeatureCollection(features: featuresGeoJson);
  }

  void setupLogging() {
    // 设置日志级别和输出格式
    Logger.root.level = Level.ALL; // 捕获所有日志级别的信息
    Logger.root.onRecord.listen((LogRecord rec) {
      print(
          '${rec.level.name}: ${rec.time}: ${rec.loggerName}: ${rec.message}');
    });
  }
}
