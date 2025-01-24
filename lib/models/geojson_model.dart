//lib/models/geojson_model.dart
import 'package:latlong2/latlong.dart';
import 'package:logging/logging.dart'; // 引入 logging 包

final Logger _logger = Logger('GeoJSONModel'); // 定义 logger

// 动态定义 Geometry 类来表示地理数据
class Geometry {
  final String type; // 动态的几何类型
  final List<dynamic>? coordinates;

  Geometry({required this.type, this.coordinates});

  // 从 JSON 数据中解析 Geometry 对象
  factory Geometry.fromJson(Map<String, dynamic>? json) {
    if (json == null || json['type'] == null) {
      return Geometry(type: 'Unknown'); // 处理缺失的 geometry 或未知类型
    }

    return Geometry(
      type: json['type'],
      coordinates: json['coordinates'],
    );
  }

  // 获取为 LatLng 的形式
  List<LatLng>? toLatLngList() {
    if (coordinates == null) return null;

    if (type == 'Point') {
      return [
        LatLng(coordinates![1], coordinates![0]),
      ];
    } else if (type == 'LineString') {
      return coordinates!.map<LatLng>((coord) {
        return LatLng(coord[1], coord[0]);
      }).toList();
    } else {
      return null; // 对于其他类型不进行处理
    }
  }
}

// 动态定义 Properties 类来存储每个 Feature 的附加信息
class Properties {
  final Map<String, dynamic> attributes; // 动态存储属性键值对

  Properties({required this.attributes});

  // 从 JSON 数据中解析 Properties 对象
  factory Properties.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return Properties(attributes: {}); // 处理缺失的 properties
    }
    return Properties(attributes: json); // 动态存储属性
  }

  // 返回所有属性键值对
  Map<String, dynamic> toJson() {
    return attributes;
  }
}

// 定义 Feature 类来表示 GeoJSON 中的每个地理元素
class Feature {
  final Geometry geometry;
  final Properties properties;

  Feature({required this.geometry, required this.properties});

  // 从 JSON 数据中解析 Feature 对象
  factory Feature.fromJson(Map<String, dynamic> json) {
    var properties = Properties.fromJson(json['properties']);

    // 添加调试日志
    json['properties'].forEach((key, value) {
      //_logger.info('解析属性 $key: 值 = $value, 类型 = ${value.runtimeType}');
    });

    return Feature(
      geometry: Geometry.fromJson(json['geometry']),
      properties: properties,
    );
  }
}

// 定义 GeoJSONModel 类来表示整个 GeoJSON 文件
class GeoJSONModel {
  final List<Feature> features;

  GeoJSONModel({required this.features});

  // 从 JSON 数据中解析 GeoJSONModel 对象
  factory GeoJSONModel.fromJson(Map<String, dynamic> json) {
    var featureList = json['features'] as List;
    List<Feature> features = featureList
        .map((featureJson) => Feature.fromJson(featureJson))
        .toList();
    return GeoJSONModel(features: features);
  }
}
