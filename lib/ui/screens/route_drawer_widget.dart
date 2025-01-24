// lib/ui/screens/route_drawer_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/route_drawer.dart';
import '../../services/valhalla_service.dart';

class RouteDrawerWidget {
  final RouteDrawer routeDrawer;
  final MapController mapController;
  final Function(LatLng?, LatLng?) onRouteLoaded;
  PolylineLayer? routePolyline;
  final List<Map<String, dynamic>> instructions = [];

  RouteDrawerWidget({
    required this.routeDrawer,
    required this.mapController,
    required this.onRouteLoaded,
  });

  /// 加载路线，并返回路线数据和多段导航指令
  Future<Map<String, dynamic>> loadRoute(LatLng start, LatLng end) async {
    try {
      final result = await routeDrawer.drawRoute(start, end, Colors.red);
      routePolyline = result['polylineLayer'] as PolylineLayer?;
      final tripData = result['tripData'] as Map<String, dynamic>;

      // 确保通过实例调用 getTurnByTurnInstructions
      ValhallaService valhallaService = ValhallaService(); // 实例化
      instructions.clear();
      instructions
          .addAll(valhallaService.getTurnByTurnInstructions(tripData)); // 实例调用

      print('Instructions after loading: ${instructions.length} steps');

      // 通知外部起点和终点已加载
      onRouteLoaded(start, end);

      return tripData;
    } catch (e) {
      throw Exception('Failed to load route: $e');
    }
  }

  /// 将 tripData 中的多段导航指令解析为可展示的数据
  List<Map<String, dynamic>> getTurnByTurnInstructions(
      Map<String, dynamic> tripData) {
    List<Map<String, dynamic>> parsedInstructions = [];
    if (tripData['legs'] != null && tripData['legs'].isNotEmpty) {
      for (var maneuver in tripData['legs'][0]['maneuvers']) {
        parsedInstructions.add({
          'instruction': maneuver['instruction'],
          'distance': maneuver['length'],
          'type': maneuver['type'],
          'street_name':
              maneuver['street_names']?.join(', ') ?? 'Unknown street',
        });
      }
    }
    return parsedInstructions;
  }

  /// 调整地图视角以适应路线的边界
  void adjustCameraToBounds(LatLng start, LatLng end) {
    final bounds = LatLngBounds(start, end);
    final center = bounds.center;
    mapController.move(center, 14.0); // 根据需要调整缩放级别
  }

  /// 地图旋转功能
  void rotateMap(double angle) {
    final currentRotation = mapController.camera.rotation;
    mapController.rotate(currentRotation + angle);
  }
}
