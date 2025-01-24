// lib/services/route_drawer.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'valhalla_service.dart';

class RouteDrawer {
  final ValhallaService valhallaService;

  RouteDrawer({required this.valhallaService});

  // 获取并绘制静态路线
  Future<Map<String, dynamic>> drawRoute(
      LatLng start, LatLng end, Color color) async {
    try {
      // 异步获取路线数据
      final tripData = await valhallaService.getRouteData(start, end);

      // 调试输出，查看 tripData 的结构
      print('tripData received from ValhallaService: $tripData');

      final polylineLayer = buildPolyline(tripData, color);

      return {
        'polylineLayer': polylineLayer,
        'tripData': tripData, // 确保 tripData 被正确返回
      };
    } catch (e) {
      print('Error fetching route: $e');
      return {
        'polylineLayer': _buildPolylineLayer([], Colors.grey),
        'tripData': {},
      };
    }
  }

  // 构建 PolylineLayer
  PolylineLayer buildPolyline(Map<String, dynamic> tripData, Color color) {
    final polyline = tripData['polyline'] as String;
    final routePoints = valhallaService.decodePolyline(polyline);
    return _buildPolylineLayer(routePoints, color);
  }

  // 构建 PolylineLayer 的私有方法
  PolylineLayer _buildPolylineLayer(List<LatLng> points, Color color) {
    return PolylineLayer(
      polylines: [
        Polyline(
          points: points,
          strokeWidth: 4.0,
          color: color,
        ),
      ],
    );
  }
}
