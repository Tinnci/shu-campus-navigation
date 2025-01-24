// lib/services/geojson_loader.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/geojson_model.dart';

class GeoJsonLoader {
  // 加载并解析 GeoJSON 文件
  Future<GeoJSONModel> loadGeoJson(String path) async {
    String geoJsonStr = await rootBundle.loadString(path);
    Map<String, dynamic> geoJsonData = json.decode(geoJsonStr);
    return GeoJSONModel.fromJson(geoJsonData);
  }

  // 在 debugGeoJson 方法中
  void debugGeoJson(GeoJSONModel geoJson) {
    Set<String> geometryTypes = {};
    Set<String> roadTypes = {};
    Set<String> propertyKeys = {};

    for (var feature in geoJson.features) {
      geometryTypes.add(feature.geometry.type);

      var roadType = feature.properties.attributes['highway'];
      if (roadType == null || roadType.isEmpty) {
        roadTypes.add('Unknown');
      } else {
        roadTypes.add(roadType);
      }

      feature.properties.attributes.keys.forEach((key) {
        propertyKeys.add(key);
      });
    }

    print("此 GeoJSON 文件中的几何类型有： ${geometryTypes.join(', ')}");
    print("此 GeoJSON 文件中的道路类型有： ${roadTypes.join(', ')}");
    print("此 GeoJSON 文件中的属性类别有： ${propertyKeys.join(', ')}");
  }
}
