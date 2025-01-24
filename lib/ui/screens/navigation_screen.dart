import 'dart:ui'; // 需要引入 dart:ui 用于 BackdropFilter
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/route_drawer.dart';
import 'navigation_info_panel.dart';
import 'route_drawer_widget.dart';

class NavigationScreen extends StatefulWidget {
  final VoidCallback onMapLoaded;
  final RouteDrawer routeDrawer;

  const NavigationScreen({
    super.key,
    required this.onMapLoaded,
    required this.routeDrawer,
  });

  @override
  NavigationScreenState createState() => NavigationScreenState();
}

class NavigationScreenState extends State<NavigationScreen>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late RouteDrawerWidget _routeDrawerWidget;
  bool isLoading = false;
  PolylineLayer? _routePolyline;
  LatLng? _startPoint;
  LatLng? _endPoint;
  final List<Marker> _markers = [];
  final double _currentZoom = 14.0;
  bool isPortrait = true;
  bool isPanelVisible = false; // 控制面板是否可见
  final List<Map<String, dynamic>> _instructions = [];
  int _selectedButtonIndex = -1;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // 初始化 RouteDrawerWidget
    _routeDrawerWidget = RouteDrawerWidget(
      routeDrawer: widget.routeDrawer,
      mapController: _mapController,
      onRouteLoaded: (start, end) {
        setState(() {
          _instructions.clear();
          _instructions.addAll(_routeDrawerWidget.instructions);
          _routePolyline = _routeDrawerWidget.routePolyline;

          // 调试输出
          print('Instructions loaded: ${_instructions.length} steps');
          print('Polyline generated: ${_routePolyline?.polylines.length}');

          // 当有导航指令时显示面板
          isPanelVisible = _instructions.isNotEmpty;
        });
      },
    );
  }

  // 加载路线
  void _loadRoute() async {
    if (_startPoint == null || _endPoint == null) return;

    setState(() {
      isLoading = true;
      isPanelVisible = false; // 开始加载时隐藏面板
      _instructions.clear();
    });

    try {
      // 确保实际调用了 loadRoute 以加载导航路线
      await _routeDrawerWidget.loadRoute(_startPoint!, _endPoint!);

      setState(() {
        // 在指令加载成功后显示面板
        isPanelVisible = _instructions.isNotEmpty;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load route: $e')),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // 处理地图长按事件来设置起点和终点
  void _handleLongPress(LatLng latLng) {
    setState(() {
      if (_startPoint == null) {
        _startPoint = latLng;
        _markers.add(_buildMarker(latLng, 'Start'));
      } else if (_endPoint == null) {
        _endPoint = latLng;
        _markers.add(_buildMarker(latLng, 'End'));
      } else {
        // 重置起点和终点
        _startPoint = latLng;
        _endPoint = null;
        _markers.clear();
        _markers.add(_buildMarker(latLng, 'Start'));
      }

      if (_startPoint != null && _endPoint != null) {
        _loadRoute(); // 选择起点和终点后加载路线
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomNavigationBarHeight =
        MediaQuery.of(context).padding.bottom + 80.0;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _startPoint ?? const LatLng(31.31586, 121.390645),
              initialZoom: _currentZoom,
              maxZoom: 18.0,
              minZoom: 10.0,
              onMapReady: () {
                widget.onMapLoaded();
                if (_startPoint != null && _endPoint != null) {
                  _routeDrawerWidget.adjustCameraToBounds(
                      _startPoint!, _endPoint!);
                }
              },
              onLongPress: (tapPosition, latLng) => _handleLongPress(latLng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              if (_routePolyline != null) _routePolyline!,
              MarkerLayer(markers: _markers),
            ],
          ),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          // 顶部半透明控制栏
          Positioned(
            top: 40.0,
            left: (screenWidth - 200) / 2,
            child: _buildTopControlBar(),
          ),
          // 导航指示面板：只有在导航指令存在且面板可见时才显示
          if (_instructions.isNotEmpty && isPanelVisible)
            Positioned(
              bottom: bottomNavigationBarHeight + 30.0,
              left: 16.0,
              right: 16.0,
              child: NavigationInfoPanel(
                instructions: _instructions,
                isPortrait: isPortrait,
                onClose: () {
                  setState(() {
                    isPanelVisible = false;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  // 顶部控制栏
  Widget _buildTopControlBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          height: 60.0,
          width: 200,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(30.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAnimatedButton(
                index: 0,
                icon: Icons.rotate_left,
                onPressed: () => _routeDrawerWidget.rotateMap(-15.0),
              ),
              _buildAnimatedButton(
                index: 1,
                icon: Icons.rotate_right,
                onPressed: () => _routeDrawerWidget.rotateMap(15.0),
              ),
              _buildAnimatedButton(
                index: 2,
                icon: Icons.location_searching,
                onPressed: () {
                  if (_startPoint != null && _endPoint != null) {
                    _routeDrawerWidget.adjustCameraToBounds(
                        _startPoint!, _endPoint!);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedButton({
    required int index,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final bool isSelected = _selectedButtonIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedButtonIndex = index;
        });
        onPressed();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.black.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          size: 30,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Marker _buildMarker(LatLng point, String label) {
    return Marker(
      point: point,
      width: 80.0,
      height: 80.0,
      child: Column(
        children: [
          Icon(
            Icons.location_on,
            color: label == 'Start' ? Colors.green : Colors.red,
            size: 30,
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.black),
          ),
        ],
      ),
    );
  }
}
