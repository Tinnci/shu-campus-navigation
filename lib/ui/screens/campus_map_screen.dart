// lib/ui/screens/campus_map_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logging/logging.dart';

import '../../services/path_finding_service.dart'; // 导入本地路径寻找服务
import '../../services/geojson_loader.dart';
import '../../models/geojson_model.dart';

class CampusMapScreen extends ConsumerStatefulWidget {
  final VoidCallback onMapLoaded; // 地图加载完成时的回调

  const CampusMapScreen({
    super.key,
    required this.onMapLoaded,
  });

  @override
  CampusMapScreenState createState() => CampusMapScreenState();
}

class CampusMapScreenState extends ConsumerState<CampusMapScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  MbTilesTileProvider? tileProvider;
  bool isLoaded = false;
  late final MapController _mapController;
  late GeoJSONModel geoJsonModel;
  late Map<String, List<Edge>> _roadNetwork; // 修改为 String 类型的节点 ID
  late PathFindingService _pathFindingService;
  double? _walkingTime;
  double? _cyclingTime;

  bool isLoading = false;
  PolylineLayer? _routePolyline;
  LatLng? _startPoint;
  LatLng? _endPoint;
  final List<Marker> _markers = [];
  bool isPortrait = true;
  bool isPanelVisible = false; // 控制面板是否可见
  final List<Map<String, dynamic>> _instructions = [];

  final Logger _logger = Logger('CampusMapScreen');
  //List<Marker> _nodeMarkers = [];

  @override
  void initState() {
    super.initState();

    // 配置日志记录
    Logger.root.level = Level.ALL; // 设置日志级别为 ALL
    Logger.root.onRecord.listen((record) {
      // 使用 Logger 的输出，而不是 print
      print('${record.level.name}: ${record.time}: ${record.message}');
    });

    _mapController = MapController();
    _loadMbTiles();
    _loadGeoJson();
  }

  void _loadGeoJson() async {
    try {
      GeoJsonLoader loader = GeoJsonLoader();
      geoJsonModel = await loader.loadGeoJson('assets/shu.geojson');

      _logger.info('GeoJSON 数据加载成功');

      // Debug GeoJSON data
      loader.debugGeoJson(geoJsonModel);

      _pathFindingService = PathFindingService(geoJsonModel: geoJsonModel);
      _pathFindingService.buildRoadNetwork();

      // Generate markers for all nodes
      //_nodeMarkers = _pathFindingService.generateNodeMarkers();

      _logger.info("道路网络已构建完成");
      setState(() {}); // 触发重建以显示节点标记
    } catch (e, stacktrace) {
      _logger.severe('加载 GeoJSON 文件失败: $e', e, stacktrace);
    }
  }

  // 加载 MBTiles 文件
  void _loadMbTiles() async {
    if (isLoaded) {
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final mbtilesPath = '${directory.path}/shu_map.mbtiles';
      const assetPath = 'assets/shu_map.mbtiles';

      // 检查本地文件和资源文件是否一致
      if (!await _compareMbTilesHash(mbtilesPath, assetPath)) {
        final byteData = await rootBundle.load(assetPath);
        final file = File(mbtilesPath);
        await file.writeAsBytes(byteData.buffer.asUint8List());
        _logger.info('MBTiles 文件已从资源文件写入本地存储。');
      } else {
        _logger.info('MBTiles 文件已经是最新版本，无需写入。');
      }

      // 使用 MbTilesTileProvider.fromPath 加载 MBTiles 文件
      tileProvider = await MbTilesTileProvider.fromPath(path: mbtilesPath);

      setState(() {
        isLoaded = true; // 更新加载状态
      });

      widget.onMapLoaded(); // 通知地图加载完成
    } catch (e) {
      if (kDebugMode) {
        _logger.severe('加载 MBTiles 失败: $e');
      }
    }
  }

  // 比较 MBTiles 文件的哈希值
  Future<bool> _compareMbTilesHash(
      String localFilePath, String assetFilePath) async {
    final localFile = File(localFilePath);
    if (!await localFile.exists()) {
      return false;
    }

    final localBytes = await localFile.readAsBytes();
    final assetBytes =
        (await rootBundle.load(assetFilePath)).buffer.asUint8List();

    return listEquals(localBytes, assetBytes);
  }

// 加载路线
  void _loadRoute() async {
    if (_startPoint == null || _endPoint == null) {
      _logger.warning('起点或终点未设置。无法加载路线。');
      return;
    }

    setState(() {
      isLoading = true;
      isPanelVisible = false;
      _instructions.clear();
    });

    try {
      _logger.info('开始计算路径...');
      _logger.info('起点: $_startPoint, 终点: $_endPoint');

      String? startNodeId = _pathFindingService.findNearestNode(_startPoint!);
      String? endNodeId = _pathFindingService.findNearestNode(_endPoint!);

      if (startNodeId == null || endNodeId == null) {
        _logger.warning('未找到合适的起点或终点节点');
        return;
      }

      var shortestPath =
          _pathFindingService.findShortestPath(startNodeId, endNodeId);

      if (shortestPath.isEmpty || shortestPath.length < 2) {
        _logger.warning('未找到从起点到终点的有效路径。');
        return;
      }

      _logger.info('最短路径节点数: ${shortestPath.length}');
      _logger.info('路径节点: $shortestPath');

      var instructions =
          _pathFindingService.generateTurnByTurnInstructions(shortestPath);
      var polyline = _pathFindingService.buildPathPolyline(shortestPath);

      // 计算总距离 (单位: 米)
      double totalDistance =
          _pathFindingService.calculateTotalDistance(polyline);

      // 估算步行和骑行时间（单位：分钟）
      double walkingSpeed = 5.0; // km/h
      double cyclingSpeed = 15.0; // km/h
      double walkingTime = (totalDistance / 1000) / walkingSpeed * 60;
      double cyclingTime = (totalDistance / 1000) / cyclingSpeed * 60;

      setState(() {
        _instructions.clear();
        _instructions.addAll(instructions);
        _routePolyline = PolylineLayer(
          polylines: [
            Polyline(points: polyline, strokeWidth: 4.0, color: Colors.blue),
          ],
        );

        // 当有导航指令时显示面板
        isPanelVisible = _instructions.isNotEmpty;
      });

      // 将步行和骑行时间传递给导航信息面板
      _showNavigationInfoPanel(walkingTime, cyclingTime);
    } catch (e, stacktrace) {
      _logger.severe('加载路线失败: $e', e, stacktrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载路线失败: $e')),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showNavigationInfoPanel(double walkingTime, double cyclingTime) {
    // 打开导航信息面板，并传递计算的步行和骑行时间
    setState(() {
      _walkingTime = walkingTime;
      _cyclingTime = cyclingTime;
      isPanelVisible = true;
    });
  }

  // 处理地图长按事件来设置起点和终点
  void _handleLongPress(LatLng latLng) {
    setState(() {
      if (_startPoint == null) {
        _logger.info('设置起点: $latLng');
        _startPoint = latLng;
        _markers.add(_buildMarker(latLng, 'Start'));
      } else if (_endPoint == null) {
        _logger.info('设置终点: $latLng');
        _endPoint = latLng;
        _markers.add(_buildMarker(latLng, 'End'));
      } else {
        _logger.info('重置起点和终点');
        // 重置起点和终点
        _startPoint = latLng;
        _endPoint = null;
        _markers.clear();
        _markers.add(_buildMarker(latLng, 'Start'));
      }

      if (_startPoint != null && _endPoint != null) {
        _logger.info('起点和终点都已设置，开始加载路线...');
        _loadRoute(); // 选择起点和终点后加载路线
      }
    });
  }

  // 构建顶部控制栏
  Widget _buildTopControlBar() {
    final screenWidth = MediaQuery.of(context).size.width;

    return Positioned(
      top: 40.0,
      left: (screenWidth - 200) / 2,
      child: ClipRRect(
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
                  onPressed: () => rotateMap(-15.0),
                ),
                _buildAnimatedButton(
                  index: 1,
                  icon: Icons.rotate_right,
                  onPressed: () => rotateMap(15.0),
                ),
                _buildAnimatedButton(
                  index: 2,
                  icon: Icons.location_searching,
                  onPressed: () {
                    if (_startPoint != null && _endPoint != null) {
                      adjustCameraToBounds(_startPoint!, _endPoint!);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建动画按钮
  Widget _buildAnimatedButton({
    required int index,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          size: 30,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  // 构建标记
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

  // 地图旋转功能
  void rotateMap(double angle) {
    final currentRotation = _mapController.camera.rotation;
    _mapController.rotate(currentRotation + angle);
  }

  // 调整地图视角以适应路线的边界
  void adjustCameraToBounds(LatLng start, LatLng end) {
    final bounds = LatLngBounds(start, end);
    final center = bounds.center;
    _mapController.move(center, 16.0); // 根据需要调整缩放级别
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final LatLngBounds bounds = LatLngBounds(
      const LatLng(31.300080, 121.374460),
      const LatLng(31.333950, 121.423730),
    );

    // 确保初始中心点在边界内
    LatLng initialCenter = const LatLng(31.317015, 121.399095);
    if (!bounds.contains(initialCenter)) {
      initialCenter = bounds.center;
    }

    final bottomNavigationBarHeight = MediaQuery.of(context).padding.bottom;

    return isLoaded
        ? Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      _startPoint ?? const LatLng(31.31586, 121.390645),
                  initialZoom: 16,
                  maxZoom: 22,
                  minZoom: 7,
                  onMapReady: () {
                    widget.onMapLoaded();
                    if (_startPoint != null && _endPoint != null) {
                      adjustCameraToBounds(_startPoint!, _endPoint!);
                    }
                  },
                  onLongPress: (tapPosition, latLng) =>
                      _handleLongPress(latLng),
                ),
                children: [
                  TileLayer(
                    tileProvider: tileProvider!,
                  ),
                  MarkerLayer(
                    markers: _markers,
                  ),
                  // Add node markers
                  /*MarkerLayer(
                    markers: _nodeMarkers,
                  ),*/
                  if (_routePolyline != null) _routePolyline!,
                ],
              ),
              if (isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                ),
              // 顶部半透明控制栏
              _buildTopControlBar(),
              // 导航指示面板：只有在导航指令存在且面板可见时才显示
              if (_instructions.isNotEmpty && isPanelVisible)
                Positioned(
                    bottom: bottomNavigationBarHeight + 30.0,
                    left: 16.0,
                    right: 16.0,
                    child: NavigationInfoPanel(
                      instructions: _instructions,
                      isPortrait: isPortrait,
                      walkingTime: _walkingTime!,
                      cyclingTime: _cyclingTime!,
                      onClose: () {
                        setState(() {
                          isPanelVisible = false;
                        });
                      },
                    )),
            ],
          )
        : const Center(child: CircularProgressIndicator());
  }

  @override
  void dispose() {
    // 释放 tileProvider
    tileProvider?.dispose();
    _mapController.dispose(); // 释放 MapController
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;
}

// 导航信息面板部件
class NavigationInfoPanel extends StatefulWidget {
  final List<Map<String, dynamic>> instructions;
  final bool isPortrait;
  final VoidCallback onClose;
  final double walkingTime;
  final double cyclingTime;

  const NavigationInfoPanel({
    super.key,
    required this.instructions,
    required this.isPortrait,
    required this.onClose,
    required this.walkingTime,
    required this.cyclingTime,
  });

  @override
  _NavigationInfoPanelState createState() => _NavigationInfoPanelState();
}

class _NavigationInfoPanelState extends State<NavigationInfoPanel> {
  bool showWalkingTime = true; // 默认显示步行时间

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    final double panelHeight =
        widget.isPortrait ? screenHeight * 0.4 : screenHeight * 0.5;
    final double panelWidth =
        widget.isPortrait ? screenWidth * 0.9 : screenWidth * 0.5;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          width: panelWidth,
          height: panelHeight,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(30.0),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.1),
                spreadRadius: 5,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '导航信息',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                              ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
              // 添加步行/骑行切换按钮
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ToggleButtons(
                  isSelected: [showWalkingTime, !showWalkingTime],
                  onPressed: (index) {
                    setState(() {
                      showWalkingTime = index == 0;
                    });
                  },
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text("步行时间"),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text("骑行时间"),
                    ),
                  ],
                ),
              ),
              // 显示估算时间
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Text(
                  showWalkingTime
                      ? "预计步行时间: ${widget.walkingTime.toStringAsFixed(1)} 分钟"
                      : "预计骑行时间: ${widget.cyclingTime.toStringAsFixed(1)} 分钟",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                      ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.instructions.length,
                  itemBuilder: (context, index) {
                    final step = widget.instructions[index];
                    return ListTile(
                      leading: _getTurnIcon(step['instruction']),
                      title: Text(
                        step['instruction'],
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white,
                            ),
                      ),
                      subtitle: Text(
                        '距离 ${step['distance'].toStringAsFixed(1)} 米',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                            ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 16.0),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 根据指令内容选择合适的图标
  Icon _getTurnIcon(String instruction) {
    if (instruction.contains('left')) {
      return const Icon(Icons.turn_left, color: Colors.white);
    } else if (instruction.contains('right')) {
      return const Icon(Icons.turn_right, color: Colors.white);
    } else {
      return const Icon(Icons.straight, color: Colors.white);
    }
  }
}
