// lib/services/path_finding_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:logging/logging.dart';
import '../models/geojson_model.dart';
import 'package:collection/collection.dart'; // 用于 HeapPriorityQueue
import 'dart:math';
import 'package:kdtree/kdtree.dart';
import 'package:r_tree/r_tree.dart';

class PathFindingService {
  bool _detailedLogging = false; // 默认为false，在寻路时设为true

  final Logger _logger = Logger('PathFindingService');
  final GeoJSONModel geoJsonModel;
  final Map<String, LatLng> _nodeCoordinates = {}; // 使用基于坐标的唯一节点ID
  final Map<String, List<Edge>> _graph = {}; // 道路网络图

  static const double someMaxReasonableDistance = 4000.0; // 定义合理的最大距离（米）
  static const int maxSearchRadius = 20;

  PathFindingService({required this.geoJsonModel}) {
    // 初始化 KDTree
    _kdTree = KDTree<NodePoint>(
      [],
      _metric,
      ['latitude', 'longitude'],
      _getDimension,
    );

    // 如果需要，可以在此处预先构建 KDTree
  }
  // 生成唯一的节点ID
  String generateNodeId(LatLng coord) {
    return '${coord.latitude.toStringAsFixed(8)}_${coord.longitude.toStringAsFixed(8)}';
  }

  double calculateTotalDistance(List<LatLng> path) {
    double totalDistance = 0.0;
    for (int i = 0; i < path.length - 1; i++) {
      totalDistance += _calculateDistance(path[i], path[i + 1]);
    }
    return totalDistance;
  }

  // 验证坐标合法性
  bool isValidCoordinate(LatLng coord) {
    // 设置合理的地理范围
    const double minLatitude = 31.0;
    const double maxLatitude = 32.0;
    const double minLongitude = 121.0;
    const double maxLongitude = 122.0;

    bool isValid = coord.latitude >= minLatitude &&
        coord.latitude <= maxLatitude &&
        coord.longitude >= minLongitude &&
        coord.longitude <= maxLongitude;

    if (!isValid) {
      _logger.warning('不合法的坐标: $coord');
    }

    return isValid;
  }

  // 初始化 R 树
  RTree<dynamic> _rTree = RTree();
  final UnionFind _unionFind = UnionFind();

  // 初始化 KDTree
  late KDTree<NodePoint> _kdTree;
  // 定义如何获取维度值
  double _getDimension(NodePoint point, String dimension) {
    switch (dimension) {
      case 'latitude':
        return point.coordinate.latitude;
      case 'longitude':
        return point.coordinate.longitude;
      default:
        throw Exception('Unknown dimension: $dimension');
    }
  }

  // 定义距离度量函数（欧几里得距离的平方）
  double _metric(NodePoint a, NodePoint b) {
    double latDiff = a.coordinate.latitude - b.coordinate.latitude;
    double lonDiff = a.coordinate.longitude - b.coordinate.longitude;
    return latDiff * latDiff + lonDiff * lonDiff;
  }

  // 获取所有连通分量
  List<Set<String>> getConnectedComponents() {
    Set<String> allNodes = _graph.keys.toSet();
    Set<String> visited = {};
    List<Set<String>> connectedComponents = [];

    while (visited.length < allNodes.length) {
      String startNodeId = allNodes.difference(visited).first;
      Set<String> component = _bfs(startNodeId);
      connectedComponents.add(component);
      visited.addAll(component);
    }

    return connectedComponents;
  }

  // 基于 BFS 的辅助方法，获取从某个节点出发的连通分量
  Set<String> _bfs(String startNodeId) {
    Set<String> visited = {};
    List<String> queue = [];

    queue.add(startNodeId);
    visited.add(startNodeId);

    while (queue.isNotEmpty) {
      String currentNode = queue.removeAt(0);

      for (Edge edge in _graph[currentNode] ?? []) {
        if (!visited.contains(edge.targetNodeId)) {
          visited.add(edge.targetNodeId);
          queue.add(edge.targetNodeId);
        }
      }
    }

    return visited;
  }

// 计算连通分量的中心点
  LatLng _getComponentCenter(Set<String> component) {
    double sumLat = 0.0;
    double sumLon = 0.0;
    int count = 0;

    for (String nodeId in component) {
      LatLng? coord = _nodeCoordinates[nodeId];
      if (coord != null) {
        sumLat += coord.latitude;
        sumLon += coord.longitude;
        count++;
      }
    }

    if (count == 0) {
      _logger.warning('连通分量为空，无法计算中心点');
      return const LatLng(0.0, 0.0); // 返回一个默认值或处理异常
    }

    double avgLat = sumLat / count;
    double avgLon = sumLon / count;

    return LatLng(avgLat, avgLon);
  }

  // 连接连通分量
  void connectComponents() {
    _logger.info('开始连接连通分量...');

    while (true) {
      List<Set<String>> components = _unionFind.getConnectedComponents();
      _logger.info('当前连通分量数量: ${components.length}');

      if (components.length <= 1) {
        _logger.info('图已经是连通的，无需进一步处理。');
        break;
      }

      double globalMinDistance = double.infinity;
      String? globalNodeA;
      String? globalNodeB;

      // 为每个连通分量计算中心点
      List<LatLng> componentCenters = components
          .map((component) => _getComponentCenter(component))
          .toList();

      for (int i = 0; i < components.length - 1; i++) {
        for (int j = i + 1; j < components.length; j++) {
          LatLng centerA = componentCenters[i];
          LatLng centerB = componentCenters[j];

          // 使用KD树查找中心点附近的节点
          NodePoint queryPointA = NodePoint('centerA_$i', centerA);
          List<dynamic> nearestToAList = _kdTree.nearest(queryPointA, 1);

          if (nearestToAList.isNotEmpty) {
            NodePoint? nearestToA = nearestToAList.first[0] as NodePoint?;
            if (nearestToA != null &&
                components[j].contains(nearestToA.nodeId)) {
              double distance =
                  _calculateDistance(centerA, nearestToA.coordinate);

              if (distance < globalMinDistance) {
                globalMinDistance = distance;
                globalNodeA = _findNearestNodeInComponent(
                    nearestToA.nodeId, components[j]);
                globalNodeB = nearestToA.nodeId;
              }
            }
          }
        }
      }

      if (globalNodeA != null && globalNodeB != null) {
        _connectNode(globalNodeA, globalNodeB);
        _logger.info(
            '连接分量节点: $globalNodeA <-> $globalNodeB, 距离: ${globalMinDistance.toStringAsFixed(2)} 米');
      } else {
        _logger.warning('无法找到合适的节点进行连接，增加搜索半径');
        // 可以在此处尝试增加搜索半径或其他策略
        break;
      }
    }
  }

  // 辅助函数：在指定分量中找到与 nodeIdB 最近的节点
  String _findNearestNodeInComponent(String nodeIdB, Set<String> component) {
    LatLng coordB = _nodeCoordinates[nodeIdB]!;

    double minDistance = double.infinity;
    String? nearestNodeId;

    for (String nodeId in component) {
      LatLng? coordA = _nodeCoordinates[nodeId];
      if (coordA == null) continue;

      double distance = _calculateDistance(coordA, coordB);
      if (distance < minDistance) {
        minDistance = distance;
        nearestNodeId = nodeId;
      }
    }

    return nearestNodeId!;
  }

  // 检查图的连通性，返回未访问到的节点列表
  Set<String> getUnvisitedNodes() {
    if (_graph.isEmpty) {
      _logger.warning('道路网络为空，无法检查连通性');
      return {};
    }

    Set<String> visited = {};
    List<String> queue = [];

    // 从图中的第一个节点开始
    String startNodeId = _graph.keys.first;
    queue.add(startNodeId);
    visited.add(startNodeId);

    while (queue.isNotEmpty) {
      String currentNode = queue.removeAt(0);

      for (Edge edge in _graph[currentNode] ?? []) {
        if (!visited.contains(edge.targetNodeId)) {
          visited.add(edge.targetNodeId);
          queue.add(edge.targetNodeId);
        }
      }
    }

    Set<String> unvisitedNodes = _graph.keys.toSet().difference(visited);

    // 如果所有节点都被访问过，则图是连通的
    if (unvisitedNodes.isEmpty) {
      _logger.info('道路网络是连通的');
    } else {
      _logger.warning('道路网络不连通，未访问到的节点数: ${unvisitedNodes.length}');
    }

    return unvisitedNodes;
  }

  // 添加未连接节点的边
  void connectDisconnectedNodes() {
    _logger.info('开始连接未连接的节点...');

    List<String> disconnectedNodeIds = _graph.keys.where((nodeId) {
      return (_graph[nodeId]?.isEmpty ?? true);
    }).toList();

    _logger.info('未连接的节点数量: ${disconnectedNodeIds.length}');

    for (String nodeId in disconnectedNodeIds) {
      LatLng? nodeCoord = _nodeCoordinates[nodeId];
      if (nodeCoord == null) {
        _logger.warning('未连接节点的坐标为空: $nodeId');
        continue; // 跳过当前循环
      }

      bool connected = false;
      double searchRadius = 0.001; // Initial search radius in degrees (~100m)
      double maxRadius = 0.01; // Max search radius (~1km)
      double increment = 0.001; // Increment radius by ~100m each time

      while (!connected && searchRadius <= maxRadius) {
        // Create a search rectangle around the node
        final rect = Rectangle<double>(
          nodeCoord.longitude - searchRadius,
          nodeCoord.latitude - searchRadius,
          2 * searchRadius,
          2 * searchRadius,
        );

        // Search for nearby points (nodes)
        final nearbyPoints = _rTree
            .search(rect)
            .where((datum) => datum.value is NodePoint)
            .map((datum) => datum.value as NodePoint)
            .toList();

        if (nearbyPoints.isNotEmpty) {
          // 找到距离最近的节点
          NodePoint nearestPoint = nearbyPoints.reduce((a, b) =>
              _calculateDistance(nodeCoord, a.coordinate) <
                      _calculateDistance(nodeCoord, b.coordinate)
                  ? a
                  : b);

          double distance =
              _calculateDistance(nodeCoord, nearestPoint.coordinate);

          // 添加边，确保双向连接
          _graph[nodeId] = _graph[nodeId] ?? [];
          _graph[nodeId]!.add(Edge(nearestPoint.nodeId, distance, {}));
          _graph[nearestPoint.nodeId] = _graph[nearestPoint.nodeId] ?? [];
          _graph[nearestPoint.nodeId]!.add(Edge(nodeId, distance, {}));

          _logger.info(
              '连接未连接节点: $nodeId <-> ${nearestPoint.nodeId}, 距离: ${distance.toStringAsFixed(2)} 米');

          connected = true;
        } else {
          // 增加搜索半径
          _logger.warning(
              '未在距离 ${(searchRadius * 111000).toStringAsFixed(2)} 米内找到合适节点，扩大搜索距离');
          searchRadius += increment;
        }
      }

      if (!connected) {
        _logger.warning('无法找到距离 $nodeId 以内的合适节点进行连接，尝试投影连接');
        // 尝试将未连接节点投影到最近的道路上
        LatLngAndSegment? projectedPointAndSegment =
            _projectPointOntoRoadNetwork(nodeCoord);
        if (projectedPointAndSegment != null) {
          _logger.info('投影点坐标: ${projectedPointAndSegment.point}');
          addProjectedPointToNetwork(
              projectedPointAndSegment.point, projectedPointAndSegment.segment);
          String projectedNodeId =
              generateNodeId(projectedPointAndSegment.point);
          _logger.info('投影后的节点ID: $projectedNodeId');
          connected = true;
        } else {
          _logger.warning('无法将节点 $nodeId 投影到任何道路上');
        }
      }
    }

    _logger.info('未连接的节点处理完成');
  }

// 构建道路网络，包括检测交叉点
  void buildRoadNetwork() {
    _logger.info('开始构建道路网络...');

    // 第一遍遍历，创建节点和边，并将线段插入 R 树和 KDTree
    for (var feature in geoJsonModel.features) {
      if (feature.geometry.type == 'LineString') {
        var coordinates = feature.geometry.coordinates;
        var roadType = feature.properties.attributes['highway'] ?? 'Unknown';

        if (coordinates != null && coordinates.length > 1) {
          List<String> wayNodeIds = [];

          for (var coord in coordinates) {
            LatLng point = LatLng(coord[1], coord[0]);

            if (!isValidCoordinate(point)) {
              _logger.warning('边界值检测：非法坐标: $point, 跳过此节点');
              continue;
            }

            String nodeId = generateNodeId(point);
            _nodeCoordinates[nodeId] = point;

            NodePoint nodePoint = NodePoint(nodeId, point);
            insertNodePoint(nodePoint); // 插入到 RTree
            _kdTree.insert(nodePoint); // 插入到 KDTree

            wayNodeIds.add(nodeId);
          }

          // 创建边并将线段插入 R 树，保持不变
          for (int i = 0; i < wayNodeIds.length - 1; i++) {
            String startId = wayNodeIds[i];
            String endId = wayNodeIds[i + 1];
            LatLng startCoord = _nodeCoordinates[startId]!;
            LatLng endCoord = _nodeCoordinates[endId]!;
            double distance = _calculateDistance(startCoord, endCoord);

            if (distance < someMaxReasonableDistance) {
              _graph[startId] = _graph[startId] ?? [];
              _graph[startId]!
                  .add(Edge(endId, distance, feature.properties.attributes));

              // 检查是否为单行道
              bool isOneWay = feature.properties.attributes['oneway'] == 'yes';

              if (!isOneWay) {
                _graph[endId] = _graph[endId] ?? [];
                _graph[endId]!.add(
                    Edge(startId, distance, feature.properties.attributes));
              }

              // 将线段插入 RTree，保持不变
              LineSegment segment =
                  LineSegment(startCoord, endCoord, startId, endId);
              insertSegment(segment);
            } else {
              _logger.warning('跳过长距离边: $startId -> $endId, 距离: $distance');
            }
          }
        }
      }
    }

    _logger.info('初始道路网络构建完成，节点数: ${_graph.length}');

    // 检测孤立节点并修复
    _logger.info('检测孤立节点并尝试修复...');
    for (String nodeId in _nodeCoordinates.keys) {
      if (!_graph.containsKey(nodeId) || (_graph[nodeId]?.isEmpty ?? true)) {
        _logger.warning('发现孤立节点: $nodeId, 坐标: ${_nodeCoordinates[nodeId]}');

        // 查找最近的非孤立节点并连接
        String? nearestConnectedNode = findNearestConnectedNode(nodeId);
        if (nearestConnectedNode != null) {
          double distance = _calculateDistance(_nodeCoordinates[nodeId]!,
              _nodeCoordinates[nearestConnectedNode]!);
          _graph[nodeId] = _graph[nodeId] ?? [];
          _graph[nodeId]!.add(Edge(nearestConnectedNode, distance, {}));

          // 如果不是单行道，双向连接
          _graph[nearestConnectedNode] = _graph[nearestConnectedNode] ?? [];
          _graph[nearestConnectedNode]!.add(Edge(nodeId, distance, {}));

          _logger.info('连接孤立节点 $nodeId 到最近的节点 $nearestConnectedNode');
        } else {
          _logger.warning('无法找到连接孤立节点 $nodeId 的合适节点');
        }
      }
    }

    // 第二遍遍历，检测并处理交叉点
    _logger.info('开始检测并处理交叉点...');
    int intersectionCount = 0;
    int maxDetailedLogs = 10; // 前10个交叉点详细记录
    List<LatLng> sampleIntersections = [];

    List<RTreeDatum<dynamic>> allData = _rTree.search(const Rectangle<double>(
      -180.0, // min longitude
      -90.0, // min latitude
      360.0, // width (maxLon - minLon)
      180.0, // height (maxLat - minLat)
    ));

    // Filter only LineSegment data
    List<RTreeDatum<LineSegment>> allSegments = allData
        .where((datum) => datum.value is LineSegment)
        .map((datum) => datum as RTreeDatum<LineSegment>)
        .toList();

    for (final segmentDatum in allSegments) {
      LineSegment seg1 = segmentDatum.value;

      final rect1 = segmentDatum.rect;

      final possibleIntersections = _rTree
          .search(rect1)
          .where((datum) => datum.value is LineSegment)
          .map((datum) => datum as RTreeDatum<LineSegment>)
          .toList();

      for (final otherDatum in possibleIntersections) {
        LineSegment seg2 = otherDatum.value;

        if (seg1 == seg2) continue;

        LatLng? intersection =
            _getIntersection(seg1.start, seg1.end, seg2.start, seg2.end);

        if (intersection != null) {
          String intersectionId = generateNodeId(intersection);

          if (_nodeCoordinates.containsKey(intersectionId)) {
            if (_detailedLogging) {
              _logger.info('检测到已存在的交叉点: $intersection');
            }
            continue; // 跳过重复的交叉点
          }

          intersectionCount++;
          if (intersectionCount <= maxDetailedLogs) {
            _logger.info('检测到新的交叉点: $intersection');
            sampleIntersections.add(intersection);
          }

          _nodeCoordinates[intersectionId] = intersection;
          NodePoint intersectionPoint = NodePoint(intersectionId, intersection);
          insertNodePoint(intersectionPoint); // 插入到 RTree 和 KDTree

          // 更新图，连接交叉点到相关节点
          _connectIntersection(intersectionId, seg1, seg2);
        }
      }
    }

    _logger.info('交叉点检测和处理完成，总共检测到 $intersectionCount 个交叉点。');

    // 检查交叉点有效性
    _logger.info('检测交叉点有效性...');
    for (final intersectionId in _nodeCoordinates.keys) {
      List<Edge>? edges = _graph[intersectionId];
      if (edges == null || edges.length < 2) {
        _logger
            .warning('交叉点可能无效：$intersectionId, 连接的边数量: ${edges?.length ?? 0}');
      }
    }

    // 检查双向边的对称性
    _logger.info('检查双向边的对称性...');
    for (String startId in _graph.keys) {
      for (Edge edge in _graph[startId] ?? []) {
        String endId = edge.targetNodeId;
        bool reverseEdgeExists =
            _graph[endId]?.any((e) => e.targetNodeId == startId) ?? false;
        if (!reverseEdgeExists) {
          _logger.warning('发现不对称的边: $startId -> $endId');
        }
      }
    }

    // 检查图的连通性
    _logger.info('检查图的连通性...');
    Set<String> unvisitedNodes = getUnvisitedNodes();
    if (unvisitedNodes.isNotEmpty) {
      _logger.warning('图不连通，开始连接连通分量');
      connectComponents();
      unvisitedNodes = getUnvisitedNodes();
      _forceConnectIsolatedNodes(unvisitedNodes);

      if (unvisitedNodes.isNotEmpty) {
        _logger.warning('在连接连通分量后，图仍然不连通');
      } else {
        _logger.info('在连接连通分量后，图已连通');
      }
    }

    // 连通分量详细分析
    _logger.info('连通分量详细分析...');
    List<Set<String>> components = _unionFind.getConnectedComponents();
    for (int i = 0; i < components.length; i++) {
      LatLng componentCenter = _getComponentCenter(components[i]);
      _logger.info(
          '分量 $i 中心点坐标: $componentCenter, 包含节点数: ${components[i].length}');
    }

    _logger.info('道路网络构建完成，节点数: ${_graph.length}');

    // 输出R树和KD树的统计信息
    logRTreeAndKDTreeStatistics(); // 在构建完网络后调用
    performConsistencyCheck();

    ensureTreesNotEmpty();
    _logger.info(
        '道路网络构建最终检查 - R树元素数: ${countRTreeElements()}, KD树节点数: ${countKDTreeNodes()}');
  }

  void _forceConnectIsolatedNodes(Set<String> isolatedNodes) {
    for (String nodeId in isolatedNodes) {
      LatLng nodeCoord = _nodeCoordinates[nodeId]!;
      String? nearestConnectedNode = findNearestConnectedNode(nodeId);
      if (nearestConnectedNode != null) {
        _connectNode(nodeId, nearestConnectedNode);
        _logger.info('强制连接孤立节点 $nodeId 到 $nearestConnectedNode');
      }
    }

    // 开始插入操作测试
    _logger.info('开始进行R树和KD树插入测试');
    List<LatLng> newTestPoints = [
      const LatLng(31.310, 121.395),
      const LatLng(31.325, 121.370),
    ];
    for (LatLng testPoint in newTestPoints) {
      String nodeId = generateNodeId(testPoint);
      NodePoint newNodePoint = NodePoint(nodeId, testPoint);
      insertNodePoint(newNodePoint);
    }
    logRTreeAndKDTreeStatistics();
    _logger.info('R树和KD树插入测试完成');

    // 开始查找测试
    _logger.info('开始进行查找测试');
    LatLng searchPoint = const LatLng(31.310124, 121.395274);

    // 查找最近节点
    String? nearestNodeId = findNearestNode(searchPoint);

    // 处理找到的最近节点
    if (nearestNodeId != null && _nodeCoordinates.containsKey(nearestNodeId)) {
      LatLng nearestNodeCoord = _nodeCoordinates[nearestNodeId]!;
      _logger.info('在KD树中找到最近的节点: $nearestNodeId, 坐标: $nearestNodeCoord');
    } else {
      // 如果没有找到节点或者节点ID不在_nodeCoordinates中，进行警告日志记录
      if (nearestNodeId == null) {
        _logger.warning('KD树中未找到最近的节点');
      } else {
        _logger.warning('最近的节点ID $nearestNodeId 不存在于 _nodeCoordinates 中');
      }
    }

    // 在R树中查找最近的道路段
    LatLngAndSegment? projectionResult =
        _projectPointOntoRoadNetwork(searchPoint);

    if (projectionResult != null) {
      _logger.info(
          '在R树中找到最近的道路段: 投影点: ${projectionResult.point}, 道路段: 起点 ${projectionResult.segment.start}, 终点 ${projectionResult.segment.end}');
    } else {
      _logger.warning('R树中未找到最近的道路段');
    }

    // 开始删除测试
    _logger.info('开始进行删除测试');
    for (LatLng testPoint in newTestPoints) {
      String nodeId = generateNodeId(testPoint);
      removeNodeFromTree(nodeId); // 需要实现删除函数
    }
    logRTreeAndKDTreeStatistics();
    _logger.info('删除测试完成');

    // **开始进行投影测试：随机选取几个点**
    _logger.info('开始进行投影测试...');

    // 定义一些随机测试点（也可以手动选择一些固定的测试点）
    List<LatLng> testPoints = [
      const LatLng(31.315012, 121.392111), // 测试点1
      const LatLng(31.320321, 121.383451), // 测试点2
      const LatLng(31.305887, 121.375654), // 测试点3
      const LatLng(31.330230, 121.380267), // 测试点4
      const LatLng(31.330552, 121.380214), // 测试点5
    ];

    // 对每个测试点进行道路段投影测试
    for (LatLng testPoint in testPoints) {
      _logger.info('测试点坐标: $testPoint');
      LatLngAndSegment? projectionResult =
          _projectPointOntoRoadNetwork(testPoint);

      if (projectionResult != null) {
        _logger.info(
            '投影成功: ${projectionResult.point}, 最近的道路段起点: ${projectionResult.segment.start}, 终点: ${projectionResult.segment.end}');
      } else {
        _logger.warning('投影失败，未找到合适的道路段');
      }
    }

    _logger.info('投影测试完成');

    // 开始随机点连通性测试
    _logger.info('开始随机点连通性测试...');
    Random random = Random();
    for (int i = 0; i < 5; i++) {
      double lat = 31.0 + random.nextDouble();
      double lon = 121.0 + random.nextDouble();
      LatLng randomPoint = LatLng(lat, lon);
      _logger.info('随机测试点坐标: $randomPoint');

      String? nearestNodeId = findNearestNode(randomPoint);
      if (nearestNodeId != null) {
        _logger.info('随机测试点找到最近节点: $nearestNodeId');
      } else {
        _logger.warning('随机测试点未能找到最近的节点');
      }
    }
  }

  void performConsistencyCheck() {
    _logger.info('开始进行网络一致性检查...');

    // 检查前确保树不为空
    ensureTreesNotEmpty();

    Set<String> isolatedNodes = <String>{};
    Set<String> nodesWithDanglingEdges = <String>{};

    for (String nodeId in _graph.keys) {
      if (_graph[nodeId]?.isEmpty ?? true) {
        isolatedNodes.add(nodeId);
      } else {
        for (Edge edge in _graph[nodeId]!) {
          if (!_graph.containsKey(edge.targetNodeId) ||
              !_graph[edge.targetNodeId]!
                  .any((e) => e.targetNodeId == nodeId)) {
            nodesWithDanglingEdges.add(nodeId);
            break;
          }
        }
      }
    }

    _logger.info('发现 ${isolatedNodes.length} 个孤立节点');
    _logger.info('发现 ${nodesWithDanglingEdges.length} 个具有悬空边的节点');

    if (isolatedNodes.isNotEmpty || nodesWithDanglingEdges.isNotEmpty) {
      _repairNetwork(isolatedNodes, nodesWithDanglingEdges);
    } else {
      _logger.info('网络一致性检查完成，未发现问题');
    }

    // 检查后确保树不为空
    ensureTreesNotEmpty();
  }

  void _repairNetwork(
      Set<String> isolatedNodes, Set<String> nodesWithDanglingEdges) {
    _logger.info('开始修复网络问题...');

    // 修复前检查树状态
    ensureTreesNotEmpty();

    // 处理孤立节点
    for (String nodeId in isolatedNodes) {
      _connectIsolatedNode(nodeId);
    }

    // 处理悬空边
    for (String nodeId in nodesWithDanglingEdges) {
      _repairDanglingEdges(nodeId);
    }

    _logger.info('网络修复完成');

    // 修复后检查树状态
    ensureTreesNotEmpty();
  }

  void ensureTreesNotEmpty() {
    if (countRTreeElements() == 0 || countKDTreeNodes() == 0) {
      _logger.severe('树结构被意外清空，尝试恢复...');
      // 实现恢复逻辑，例如从 _graph 重建树
      rebuildTreesFromGraph();
    }
  }

  void rebuildTreesFromGraph() {
    _rTree = RTree(); // 重新创建一个新的 RTree 实例来清空它
    _kdTree = KDTree<NodePoint>(
        [],
        _metric, // 使用类方法 _metric
        ['latitude', 'longitude'],
        _getDimension // 使用类方法 _getDimension
        );

    for (String nodeId in _nodeCoordinates.keys) {
      LatLng coord = _nodeCoordinates[nodeId]!;
      NodePoint nodePoint = NodePoint(nodeId, coord);
      insertNodePoint(nodePoint); // 重新插入节点到R树和KD树
    }

    _logger.info('已从图结构重建R树和KD树');
  }

  void _connectIsolatedNode(String nodeId) {
    // 检查树状态
    ensureTreesNotEmpty();

    LatLng nodeCoord = _nodeCoordinates[nodeId]!;
    List<NodeDistance> nearestNodes =
        _findNearestNodes(nodeCoord, 5); // 寻找5个最近的节点

    if (nearestNodes.isEmpty) {
      _logger.warning('无法为孤立节点 $nodeId 找到任何近邻节点');
      return;
    }

    int connectionsAdded = 0;
    for (NodeDistance nd in nearestNodes) {
      if (connectionsAdded >= 3) break; // 最多连接到3个节点

      double distance = nd.distance;
      if (distance < someMaxReasonableDistance) {
        _addBidirectionalEdge(nodeId, nd.nodeId, distance);
        connectionsAdded++;
      }
    }

    if (connectionsAdded > 0) {
      _logger.info('孤立节点 $nodeId 已连接到 $connectionsAdded 个节点');
    } else {
      _logger.warning('无法为孤立节点 $nodeId 建立任何有效连接');
    }

    // 连接后检查树状态
    ensureTreesNotEmpty();
  }

  void _repairDanglingEdges(String nodeId) {
    List<Edge> danglingEdges = _graph[nodeId]!
        .where((edge) =>
            !_graph.containsKey(edge.targetNodeId) ||
            !_graph[edge.targetNodeId]!.any((e) => e.targetNodeId == nodeId))
        .toList();

    for (Edge edge in danglingEdges) {
      if (!_graph.containsKey(edge.targetNodeId)) {
        _graph[nodeId]!.remove(edge);
        _logger.info('移除指向不存在节点的边: $nodeId -> ${edge.targetNodeId}');
      } else {
        _addBidirectionalEdge(nodeId, edge.targetNodeId, edge.distance);
        //_logger.info('修复单向边为双向: $nodeId <-> ${edge.targetNodeId}');
      }
    }
  }

  void _addBidirectionalEdge(String nodeId1, String nodeId2, double distance) {
    _graph[nodeId1] = _graph[nodeId1] ?? [];
    _graph[nodeId1]!.add(Edge(nodeId2, distance, {}));

    _graph[nodeId2] = _graph[nodeId2] ?? [];
    _graph[nodeId2]!.add(Edge(nodeId1, distance, {}));
  }

  List<NodeDistance> _findNearestNodes(LatLng point, int k) {
    NodePoint queryPoint = NodePoint('query', point);
    List<dynamic> nearestNodes = _kdTree.nearest(queryPoint, k);

    return nearestNodes
        .map((node) =>
            NodeDistance((node[0] as NodePoint).nodeId, node[1] as double))
        .toList();
  }

// 连接交叉点到相关的道路段
  void _connectIntersection(
      String intersectionId, LineSegment seg1, LineSegment seg2) {
    // 确保交叉点已经插入到 RTree 和 KDTree 中
    if (_nodeCoordinates.containsKey(intersectionId)) {
      NodePoint intersectionPoint =
          NodePoint(intersectionId, _nodeCoordinates[intersectionId]!);
      insertNodePoint(intersectionPoint); // 插入到 RTree
      _kdTree.insert(intersectionPoint); // 插入到 KDTree
    }

    // 分别连接交叉点与 seg1 和 seg2 的起点和终点
    _connectNode(intersectionId, seg1.startId);
    _connectNode(intersectionId, seg1.endId);
    _connectNode(intersectionId, seg2.startId);
    _connectNode(intersectionId, seg2.endId);
  }

  // 连接两个节点
  void _connectNode(String nodeIdA, String nodeIdB) {
    LatLng? coordA = _nodeCoordinates[nodeIdA];
    LatLng? coordB = _nodeCoordinates[nodeIdB];

    if (coordA == null || coordB == null) {
      _logger.warning('无法连接节点 $nodeIdA 和 $nodeIdB，因为其中一个坐标为空');
      return;
    }

    double distance = _calculateDistance(coordA, coordB);

    if (distance < someMaxReasonableDistance) {
      _graph[nodeIdA] = _graph[nodeIdA] ?? [];
      _graph[nodeIdA]!.add(Edge(nodeIdB, distance, {}));

      _graph[nodeIdB] = _graph[nodeIdB] ?? [];
      _graph[nodeIdB]!.add(Edge(nodeIdA, distance, {}));

      // 使用 UnionFind 合并连通分量
      _unionFind.union(nodeIdA, nodeIdB);
    }
  }

  // 检测两条线段是否相交，并返回交点
  LatLng? _getIntersection(LatLng p1, LatLng p2, LatLng p3, LatLng p4) {
    double denominator =
        ((p4.longitude - p3.longitude) * (p2.latitude - p1.latitude)) -
            ((p4.latitude - p3.latitude) * (p2.longitude - p1.longitude));
    if (denominator == 0) {
      return null; // 平行或重合
    }

    double ua = (((p4.longitude - p3.longitude) * (p1.latitude - p3.latitude)) -
            ((p4.latitude - p3.latitude) * (p1.longitude - p3.longitude))) /
        denominator;
    double ub = (((p2.longitude - p1.longitude) * (p1.latitude - p3.latitude)) -
            ((p2.latitude - p1.latitude) * (p1.longitude - p3.longitude))) /
        denominator;

    if (ua >= 0 && ua <= 1 && ub >= 0 && ub <= 1) {
      double x = p1.longitude + ua * (p2.longitude - p1.longitude);
      double y = p1.latitude + ua * (p2.latitude - p1.latitude);
      return LatLng(y, x);
    }

    return null;
  }

  // 使用 Dijkstra 算法找到从起点到终点的最短路径
  List<String> findShortestPath(String startNodeId, String endNodeId) {
    // 启用详细日志输出
    _detailedLogging = true;

    // 检查起点和终点是否相同
    if (startNodeId == endNodeId) {
      _logger.info('起点和终点相同，返回直接路径');
      _detailedLogging = false; // 关闭详细日志输出
      return [startNodeId]; // 如果起点和终点是同一个节点，直接返回该节点作为路径
    }

    if (!_graph.containsKey(startNodeId) || !_graph.containsKey(endNodeId)) {
      _logger.warning('起点或终点不在道路网络中');
      _detailedLogging = false; // 关闭详细日志输出
      return [];
    }

    Map<String, double> distances = {}; // 存储起点到每个节点的最短距离
    Map<String, String?> previousNodes = {}; // 记录路径的前驱节点
    Set<String> visited = {}; // 记录访问过的节点
    HeapPriorityQueue<NodeDistance> priorityQueue =
        HeapPriorityQueue<NodeDistance>();

    _logger.info('开始寻路... 起点ID: $startNodeId, 终点ID: $endNodeId');

    distances[startNodeId] = 0;
    priorityQueue.add(NodeDistance(startNodeId, 0));

    while (priorityQueue.isNotEmpty) {
      NodeDistance current = priorityQueue.removeFirst();

      // 如果节点已经被访问，跳过
      if (visited.contains(current.nodeId)) continue;

      _logger.info(
          '处理节点: ${current.nodeId}, 当前距离: ${current.distance}, 前驱节点: ${previousNodes[current.nodeId]}');

      // 标记当前节点为已访问
      visited.add(current.nodeId);

      // 如果到达终点，停止搜索
      if (current.nodeId == endNodeId) {
        _logger.info('找到终点，结束寻路');
        break;
      }

      // 遍历当前节点的所有相邻节点
      for (Edge edge in _graph[current.nodeId] ?? []) {
        if (visited.contains(edge.targetNodeId)) continue; // 跳过已访问节点

        double newDistance = current.distance + edge.distance;

        // 如果新路径比之前找到的更短，更新路径
        if (newDistance < (distances[edge.targetNodeId] ?? double.infinity)) {
          distances[edge.targetNodeId] = newDistance;
          previousNodes[edge.targetNodeId] = current.nodeId;
          priorityQueue.add(NodeDistance(edge.targetNodeId, newDistance));

          _logger.info('更新节点: ${edge.targetNodeId}, 新距离: $newDistance');
        }
      }
    }

    // 生成最短路径
    List<String> path = [];
    String? currentNode = endNodeId;
    while (currentNode != null) {
      path.insert(0, currentNode);
      currentNode = previousNodes[currentNode];
    }

    // 如果起点和终点相同且路径长度为1，则不视为无效路径
    if (path.isEmpty) {
      _logger.warning('未找到从起点到终点的有效路径');
      _detailedLogging = false; // 关闭详细日志输出
      return [];
    }

    if (path.length == 1 && startNodeId == endNodeId) {
      _logger.info('起点和终点相同，路径节点: $path');
      _detailedLogging = false; // 关闭详细日志输出
      return path;
    }

    if (path.length < 2) {
      _logger.warning('未找到从起点到终点的有效路径');
      _detailedLogging = false; // 关闭详细日志输出
      return [];
    }

    _logger.info('路径找到，路径节点: $path');

    // 关闭详细日志输出
    _detailedLogging = false;

    return path;
  }

  // 检查并连接图中未连通的边
  void checkAndConnectDisconnectedEdges() {
    _logger.info('开始检查并连接图中未连通的边...');

    for (String nodeId in _graph.keys) {
      for (Edge edge in _graph[nodeId] ?? []) {
        // 如果发现目标节点的边没有返回到当前节点，则手动添加反向边
        if (!_graph[edge.targetNodeId]!.any((e) => e.targetNodeId == nodeId)) {
          _graph[edge.targetNodeId]!
              .add(Edge(nodeId, edge.distance, edge.properties));
          _logger.info('修复未连接的边: $nodeId <-> ${edge.targetNodeId}');
        }
      }
    }
    _logger.info('边连接检查完成');
  }

  // 生成 turn-by-turn 指令
  List<Map<String, dynamic>> generateTurnByTurnInstructions(
      List<String> pathNodeIds) {
    List<Map<String, dynamic>> instructions = [];

    for (int i = 0; i < pathNodeIds.length - 1; i++) {
      LatLng? current = _nodeCoordinates[pathNodeIds[i]];
      LatLng? next = _nodeCoordinates[pathNodeIds[i + 1]];

      if (current == null || next == null) {
        _logger.warning('路径中的节点坐标为空: ${pathNodeIds[i]}, ${pathNodeIds[i + 1]}');
        continue; // 跳过当前循环
      }

      String instruction = _getDirectionInstruction(current, next);
      instructions.add({
        "instruction": instruction,
        "start_point": current,
        "end_point": next,
        "distance": _calculateDistance(current, next)
      });
    }

    return instructions;
  }

  // 根据方向计算转向指令
  String _getDirectionInstruction(LatLng current, LatLng next) {
    double bearing = _calculateBearing(current, next);
    if (bearing >= 45 && bearing < 135) {
      return "右转";
    } else if (bearing >= 135 && bearing < 225) {
      return "直行";
    } else if (bearing >= 225 && bearing < 315) {
      return "左转";
    } else {
      return "直行";
    }
  }

  // 计算方位角
  double _calculateBearing(LatLng start, LatLng end) {
    double lat1 = _toRadians(start.latitude);
    double lon1 = _toRadians(start.longitude);
    double lat2 = _toRadians(end.latitude);
    double lon2 = _toRadians(end.longitude);

    double dLon = lon2 - lon1;
    double y = sin(dLon) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    double bearing = atan2(y, x);

    return (bearing * 180 / pi + 360) % 360;
  }

  // 将角度转换为弧度
  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  // 使用 latlong2 的 Distance 类计算距离
  double _calculateDistance(LatLng start, LatLng end) {
    // ignore: prefer_const_constructors
    final Distance distance = Distance();
    return distance.as(LengthUnit.Meter, start, end); // 返回两点之间的距离，单位是米
  }

  // 将路径转换为 Polyline 形式以便绘制
  List<LatLng> buildPathPolyline(List<String> pathNodeIds) {
    List<LatLng> polyline = [];
    for (String nodeId in pathNodeIds) {
      polyline.add(_nodeCoordinates[nodeId]!); // 使用 _nodeCoordinates 获取坐标
    }
    return polyline;
  }

// 查找最近的已连接节点
  String? findNearestConnectedNode(String nodeId) {
    LatLng? nodeCoord = _nodeCoordinates[nodeId];
    if (nodeCoord == null) {
      _logger.warning('节点 $nodeId 不存在于 _nodeCoordinates 中');
      return null;
    }

    // 创建查询点
    NodePoint queryPoint = NodePoint(nodeId, nodeCoord);
    List<dynamic> nearestNodes = _kdTree.nearest(queryPoint, 5); // 查找最近的5个节点

    for (var nearestNode in nearestNodes) {
      NodePoint nearestPoint = nearestNode[0] as NodePoint;
      if (_graph.containsKey(nearestPoint.nodeId) &&
          (_graph[nearestPoint.nodeId]?.isNotEmpty ?? false)) {
        return nearestPoint.nodeId; // 返回最近的已连接节点
      }
    }

    _logger.warning('未找到与节点 $nodeId 连接的节点');
    return null;
  }

  String? findNearestNode(LatLng point) {
    _logger.info('开始查找最近的节点，目标坐标: $point');

    logRTreeAndKDTreeStatistics();

    NodePoint queryPoint = NodePoint('query', point);
    List<dynamic> nearestNodes = _kdTree.nearest(queryPoint, 10); // 增加到5个最近节点

    for (var node in nearestNodes) {
      NodePoint nearestPoint = node[0] as NodePoint;
      double distance = node[1] as double;

      // 检查节点是否在图中并且已连接
      if (_graph.containsKey(nearestPoint.nodeId) &&
          (_graph[nearestPoint.nodeId]?.isNotEmpty ?? false)) {
        _logger.info(
            '找到最近的有效节点，节点ID: ${nearestPoint.nodeId}, 距离: ${distance.toStringAsFixed(2)} 米');
        return nearestPoint.nodeId;
      }
    }

    _logger.warning('KD树中未找到有效的最近节点，尝试投影到道路网络');
    return _projectAndCreateNode(point);
  }

  String? _projectAndCreateNode(LatLng point) {
    LatLngAndSegment? projectedPointAndSegment =
        _projectPointOntoRoadNetwork(point);

    if (projectedPointAndSegment != null) {
      _logger.info('投影点坐标: ${projectedPointAndSegment.point}');
      addProjectedPointToNetwork(
          projectedPointAndSegment.point, projectedPointAndSegment.segment);
      String nodeId = generateNodeId(projectedPointAndSegment.point);
      _logger.info('投影后的节点ID: $nodeId');
      return nodeId;
    } else {
      _logger.warning('无法投影到道路网络，创建临时节点');
      return createTemporaryNode(point);
    }
  }

  String createTemporaryNode(LatLng point) {
    String tempNodeId = generateNodeId(point);
    _nodeCoordinates[tempNodeId] = point;
    NodePoint tempNodePoint = NodePoint(tempNodeId, point);
    insertNodePoint(tempNodePoint);

    // 连接到最近的已知节点
    String? nearestNodeId = findNearestConnectedNode(tempNodeId);
    if (nearestNodeId != null) {
      _connectNode(tempNodeId, nearestNodeId);
    }

    _logger.info('创建临时节点: $tempNodeId');
    return tempNodeId;
  }

  // 投影点到最近的道路网络
  LatLngAndSegment? _projectPointOntoRoadNetwork(LatLng point) {
    double searchRadius = 0.005; // 初始搜索半径大约 500 米
    double maxRadius = 0.1; // 最大搜索半径大约 10 公里
    double increment = 0.001; // 每次增加 100 米

    while (searchRadius <= maxRadius) {
      final rect = Rectangle<double>(
        point.longitude - searchRadius,
        point.latitude - searchRadius,
        2 * searchRadius,
        2 * searchRadius,
      );

      final possibleSegments = _rTree
          .search(rect)
          .where((datum) => datum.value is LineSegment)
          .map((datum) => datum.value as LineSegment)
          .toList();

      LatLngAndSegment? result = _findClosestSegment(point, possibleSegments);

      if (result != null) {
        _logger.info(
            '找到最近的道路投影点，距离: ${_calculateDistance(point, result.point).toStringAsFixed(2)} 米');
        return result;
      }

      searchRadius += increment;
      _logger.info('增加搜索半径到: ${(searchRadius * 111000).toStringAsFixed(2)} 米');
    }

    _logger.warning('未能找到任何道路段进行投影');
    return null;
  }

  LatLngAndSegment? _findClosestSegment(
      LatLng point, List<LineSegment> segments) {
    double minDistance = double.infinity;
    LatLng? closestPoint;
    LineSegment? closestSegment;

    for (var segment in segments) {
      LatLng projection =
          _projectPointOntoLineSegment(point, segment.start, segment.end);
      double distance = _calculateDistance(point, projection);

      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = projection;
        closestSegment = segment;
      }
    }

    if (closestPoint != null && closestSegment != null) {
      return LatLngAndSegment(closestPoint, closestSegment);
    }

    return null;
  }

  LatLng _projectPointOntoLineSegment(LatLng p, LatLng a, LatLng b) {
    double latA = a.latitude;
    double lonA = a.longitude;
    double latB = b.latitude;
    double lonB = b.longitude;
    double latP = p.latitude;
    double lonP = p.longitude;

    double dx = lonB - lonA;
    double dy = latB - latA;

    if (dx == 0 && dy == 0) {
      _logger.info('投影点位于线段起点: ${a.latitude}, ${a.longitude}');
      return a;
    }

    double t = ((latP - latA) * dy + (lonP - lonA) * dx) / (dx * dx + dy * dy);
    t = t.clamp(0.0, 1.0);

    double latProj = latA + t * dy;
    double lonProj = lonA + t * dx;
    LatLng projection = LatLng(latProj, lonProj);

    // 输出投影点的经纬度
    if (_detailedLogging) {
      _logger.info('计算出的投影点: ${projection.latitude}, ${projection.longitude}');
    }
    return projection;
  }

// Insert a LineSegment into the R-Tree
  void insertSegment(LineSegment segment) {
    // Create a bounding rectangle for the segment
    final double minX = min(segment.start.longitude, segment.end.longitude);
    final double maxX = max(segment.start.longitude, segment.end.longitude);
    final double minY = min(segment.start.latitude, segment.end.latitude);
    final double maxY = max(segment.start.latitude, segment.end.latitude);

    final rect = Rectangle<double>(minX, minY, maxX - minX, maxY - minY);

    // Wrap the LineSegment in an RTreeDatum
    final datum = RTreeDatum<LineSegment>(rect, segment);

    // Insert into the R-Tree (wrap datum in a list)
    _rTree.add([datum]); // Fix here: wrap datum in a list
  }

  void insertNodePoint(NodePoint point) {
    if (_detailedLogging) {
      _logger
          .info('插入节点到R树和KD树，节点ID: ${point.nodeId}, 坐标: ${point.coordinate}');
    }

    final rect = Rectangle<double>(
      point.coordinate.longitude,
      point.coordinate.latitude,
      0.0,
      0.0,
    );
    final datum = RTreeDatum<NodePoint>(rect, point);

    // 检查R树是否已经存在该点，避免重复插入
    if (!_rTree.search(rect).any((n) => n.value == point)) {
      _rTree.add([datum]); // 插入到R树
    } else {
      if (_detailedLogging) {
        _logger.warning('R树中已存在该节点: ${point.nodeId}');
      }
    }

    // 同样检查KD树是否已经存在该点
    if (_kdTree.nearest(point, 1).isEmpty) {
      _kdTree.insert(point); // 插入到KD树
    } else {
      if (_detailedLogging) {
        _logger.warning('KD树中已存在该节点: ${point.nodeId}');
      }
    }
  }

  // 将投影点加入道路网络
  void addProjectedPointToNetwork(
      LatLng projectedPoint, LineSegment closestSegment) {
    String nodeId = generateNodeId(projectedPoint);
    _nodeCoordinates[nodeId] = projectedPoint;
    NodePoint nodePoint = NodePoint(nodeId, projectedPoint);
    insertNodePoint(nodePoint); // 插入到 RTree
    _kdTree.insert(nodePoint); // 插入到 KDTree

    _logger.info('投影点添加到道路网络: $nodeId, 坐标: $projectedPoint');

    // 连接投影点到最近的道路段的起点和终点
    String startId = closestSegment.startId;
    String endId = closestSegment.endId;

    LatLng? coordStart = _nodeCoordinates[startId];
    LatLng? coordEnd = _nodeCoordinates[endId];

    if (coordStart == null || coordEnd == null) {
      _logger.warning('连接投影点到道路段时，起点或终点坐标为空: $startId, $endId');
      return;
    }

    double distanceToStart = _calculateDistance(projectedPoint, coordStart);
    double distanceToEnd = _calculateDistance(projectedPoint, coordEnd);

    // 添加边，确保双向连接
    _graph[nodeId] = _graph[nodeId] ?? [];
    _graph[nodeId]!.add(Edge(startId, distanceToStart, {}));
    _graph[nodeId]!.add(Edge(endId, distanceToEnd, {}));

    _graph[startId] = _graph[startId] ?? [];
    _graph[startId]!.add(Edge(nodeId, distanceToStart, {}));

    _graph[endId] = _graph[endId] ?? [];
    _graph[endId]!.add(Edge(nodeId, distanceToEnd, {}));

    _logger.info('投影点 $nodeId 成功连接到道路网络: 起点 $startId, 终点 $endId');

    // 更新连通性
    connectComponents(); // 在添加投影点和边之后，重新连接连通分量

    checkAndConnectDisconnectedEdges(); // 在添加投影点和边之后，检查并连接未双向连接的边
  }

  // 生成节点标记
  List<Marker> generateNodeMarkers() {
    List<Marker> markers = [];

    _nodeCoordinates.forEach((nodeId, coord) {
      markers.add(
        Marker(
          point: coord,
          width: 30.0,
          height: 30.0,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.blue, // 设置标记的颜色
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on,
              color: Colors.white, // 设置图标的颜色
              size: 15,
            ),
          ),
        ),
      );
    });

    return markers;
  }

// 通过搜索整个树获取R树的元素数量
  int countRTreeElements() {
    final allData = _rTree.search(const Rectangle<double>(
        -180.0, // min longitude
        -90.0, // min latitude
        360.0, // width
        180.0 // height
        ));
    return allData.length;
  }

// 由于R树没有公开获取高度的方法，无法直接计算高度。可以用其他方式估算。
  double estimateRTreeComplexity() {
    // 假设树的高度与元素数量的对数成正比
    int numElements = countRTreeElements();
    return log(numElements) / log(2); // 基于完全平衡树的高度估算
  }

// 记录R树的统计信息
  void logRTreeStatistics() {
    _logger.info('R树统计信息:');
    _logger.info('  总元素数: ${countRTreeElements()}');
    _logger.info('  树复杂度（估计）: ${estimateRTreeComplexity()}');
  }

// 计算KD树的节点数量
  int countKDTreeNodes() {
    // KD树没有直接的节点统计方法，可以通过插入时手动跟踪
    return _kdTree.length; // 使用提供的公开字段获取节点数
  }

// 由于KDTree没有暴露树的高度，可以手动维护
  double estimateKDTreeComplexity() {
    int numNodes = countKDTreeNodes();
    return log(numNodes) / log(2); // 基于完全平衡树的高度估算
  }

// 记录KD树的统计信息
  void logKDTreeStatistics() {
    _logger.info('KD树统计信息:');
    _logger.info('  总节点数: ${countKDTreeNodes()}');
    _logger.info('  树复杂度（估计）: ${estimateKDTreeComplexity()}');
  }

// 输出R树和KD树的统计信息，避免使用私有类型或字段
  void logRTreeAndKDTreeStatistics() {
    // 输出R树的统计信息
    logRTreeStatistics();

    // 输出KD树的统计信息
    logKDTreeStatistics();
  }

  void removeNodeFromTree(String nodeId) {
    // 获取节点对应的坐标
    LatLng? nodeCoord = _nodeCoordinates[nodeId];
    if (nodeCoord == null) {
      _logger.warning('节点 $nodeId 不存在，无法删除');
      return;
    }

    // 从R树中删除节点
    _logger.info('尝试从R树中删除节点: $nodeId');
    bool rTreeRemoved = removeNodeFromRTree(nodeCoord);
    if (rTreeRemoved) {
      _logger.info('成功从R树中删除节点: $nodeId');
    } else {
      _logger.warning('未能从R树中删除节点: $nodeId');
    }

    // 从KD树中删除节点
    _logger.info('尝试从KD树中删除节点: $nodeId');
    bool kdTreeRemoved = removeNodeFromKDTree(nodeCoord);
    if (kdTreeRemoved) {
      _logger.info('成功从KD树中删除节点: $nodeId');
    } else {
      _logger.warning('未能从KD树中删除节点: $nodeId');
    }

    // 从节点坐标映射中删除
    _nodeCoordinates.remove(nodeId);
  }

// 从R树中删除节点
// 从R树中删除节点
  bool removeNodeFromRTree(LatLng coord) {
    // 创建一个0宽度的矩形表示该节点
    final rect = Rectangle<double>(
      coord.longitude,
      coord.latitude,
      0.0,
      0.0,
    );

    // 查找该节点的RTreeDatum
    final matchingNodes = _rTree
        .search(rect)
        .where((datum) =>
            datum.value is NodePoint &&
            (datum.value as NodePoint).coordinate == coord)
        .toList();

    if (matchingNodes.isNotEmpty) {
      // 遍历 matchingNodes 并删除每一个
      for (var node in matchingNodes) {
        _rTree.remove(node);
      }
      return true;
    }

    return false;
  }

// 从KD树中删除节点
  bool removeNodeFromKDTree(LatLng coord) {
    NodePoint queryPoint = NodePoint('query', coord);
    List<dynamic> nearestNodes = _kdTree.nearest(queryPoint, 1);

    if (nearestNodes.isNotEmpty) {
      NodePoint nearestNode = nearestNodes.first[0] as NodePoint;
      if (nearestNode.coordinate == coord) {
        _kdTree.remove(nearestNode);
        _logger.info('成功从KD树中删除节点: ${nearestNode.nodeId}');
        return true;
      } else {
        _logger.warning('KD树中找到的节点不匹配，未能删除节点: ${nearestNode.nodeId}');
      }
    } else {
      _logger.warning('KD树中未找到任何匹配节点');
    }
    return false;
  }
}

// 边类，用于表示图中的一条边
class Edge {
  final String targetNodeId;
  final double distance;
  final Map<String, dynamic> properties; // 包含道路类型等附加信息

  Edge(this.targetNodeId, this.distance, this.properties);
}

// 节点-距离类，用于优先队列的比较
class NodeDistance implements Comparable<NodeDistance> {
  final String nodeId;
  final double distance;

  NodeDistance(this.nodeId, this.distance);

  @override
  int compareTo(NodeDistance other) {
    return distance.compareTo(other.distance);
  }
}

// 新增 LatLngAndSegment 类，用于投影定位：在投影过程中，需要同时返回投影点和对应的线段，以便后续连接操作
class LatLngAndSegment {
  final LatLng point;
  final LineSegment segment;

  LatLngAndSegment(this.point, this.segment);
}

// 线段类，用于 R 树索引
// Define the LineSegment class if not already defined
class LineSegment {
  final LatLng start;
  final LatLng end;
  final String startId;
  final String endId;

  LineSegment(this.start, this.end, this.startId, this.endId);
}

// 新增 NodePoint 类
class NodePoint {
  final String nodeId;
  final LatLng coordinate;

  NodePoint(this.nodeId, this.coordinate);
}

class UnionFind {
  final Map<String, String> parent = {};

  String find(String x) {
    if (!parent.containsKey(x)) {
      parent[x] = x;
    }
    if (parent[x] != x) {
      parent[x] = find(parent[x]!); // 路径压缩
    }
    return parent[x]!;
  }

  void union(String x, String y) {
    String rootX = find(x);
    String rootY = find(y);
    if (rootX != rootY) {
      parent[rootY] = rootX;
    }
  }

  List<Set<String>> getConnectedComponents() {
    Map<String, Set<String>> components = {};
    for (String node in parent.keys) {
      String root = find(node);
      components[root] = components[root] ?? {};
      components[root]!.add(node);
    }
    return components.values.toList();
  }
}
