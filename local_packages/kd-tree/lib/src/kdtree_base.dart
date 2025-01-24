import 'dart:math';

import 'binary_heap.dart';
import 'node.dart';

typedef DimensionGetter<T> = double Function(T point, String dimension);
typedef MetricFunction<T> = double Function(T a, T b);

class KDTree<T> {
  final List<String> _dimensions;
  final DimensionGetter<T> _getDimension;
  late Node<T>? _root;
  MetricFunction<T>? _metric;

  KDTree(
    List<T> points,
    this._metric,
    this._dimensions,
    this._getDimension,
  ) {
    _root = _buildTree(points, 0, null);
  }

  Node<T>? _buildTree(List<T> points, int depth, Node<T>? parent) {
    if (points.isEmpty) {
      return null;
    }

    final dim = depth % _dimensions.length;

    points.sort((a, b) {
      final aValue = _getDimension(a, _dimensions[dim]);
      final bValue = _getDimension(b, _dimensions[dim]);
      return aValue.compareTo(bValue);
    });

    final medianIndex = (points.length / 2).floor();
    final node = Node<T>(points[medianIndex], dim, parent);
    node.left = _buildTree(points.sublist(0, medianIndex), depth + 1, node);
    node.right = _buildTree(points.sublist(medianIndex + 1), depth + 1, node);

    return node;
  }

  /// 插入一个点到 K-d 树中
  void insert(T point) {
    Node<T>? innerSearch(Node<T>? node, Node<T>? parent) {
      if (node == null) {
        return parent;
      }

      final dimension = _dimensions[node.dimension];
      final pointValue = _getDimension(point, dimension);
      final nodeValue = _getDimension(node.obj, dimension);

      if (pointValue.compareTo(nodeValue) < 0) {
        return innerSearch(node.left, node);
      } else {
        return innerSearch(node.right, node);
      }
    }

    final insertPosition = innerSearch(_root, null);
    final newNode = Node<T>(
      point,
      (insertPosition?.dimension ?? 0) % _dimensions.length,
      insertPosition,
    );
    final dimension = _dimensions[newNode.dimension];

    if (insertPosition == null) {
      _root = newNode;
    } else {
      final pointValue = _getDimension(point, dimension);
      final parentValue = _getDimension(insertPosition.obj, dimension);
      if (pointValue.compareTo(parentValue) < 0) {
        insertPosition.left = newNode;
      } else {
        insertPosition.right = newNode;
      }
    }
  }

  /// 从 K-d 树中移除一个点
  void remove(T point) {
    Node<T>? nodeToRemove;

    Node<T>? nodeSearch(Node<T>? node) {
      if (node == null) {
        return null;
      }

      if (node.obj == point) {
        return node;
      }

      final dimension = _dimensions[node.dimension];
      final pointValue = _getDimension(point, dimension);
      final nodeValue = _getDimension(node.obj, dimension);

      if (pointValue.compareTo(nodeValue) < 0) {
        return nodeSearch(node.left);
      } else {
        return nodeSearch(node.right);
      }
    }

    void removeNode(Node<T> node) {
      Node<T>? nextNode;
      late T nextObj; // 修改为非可空类型
      String? pDimension;

      Node<T>? findMin(Node<T>? node, int dim) {
        if (node == null) {
          return null;
        }

        if (node.dimension == dim) {
          if (node.left != null) {
            return findMin(node.left, dim);
          }
          return node;
        }

        final own = _getDimension(node.obj, _dimensions[dim]);
        final leftMin = findMin(node.left, dim);
        final rightMin = findMin(node.right, dim);
        Node<T> minNode = node;

        if (leftMin != null &&
            _getDimension(leftMin.obj, _dimensions[dim]).compareTo(own) < 0) {
          minNode = leftMin;
        }

        if (rightMin != null &&
            _getDimension(rightMin.obj, _dimensions[dim])
                    .compareTo(_getDimension(minNode.obj, _dimensions[dim])) <
                0) {
          minNode = rightMin;
        }

        return minNode;
      }

      if (node.left == null && node.right == null) {
        if (node.parent == null) {
          _root = null;
          return;
        }

        pDimension = _dimensions[node.parent!.dimension];
        final nodeValue = _getDimension(node.obj, pDimension);
        final parentValue = _getDimension(node.parent!.obj, pDimension);

        if (nodeValue.compareTo(parentValue) < 0) {
          node.parent!.left = null;
        } else {
          node.parent!.right = null;
        }
        return;
      }

      if (node.right != null) {
        nextNode = findMin(node.right, node.dimension);
        if (nextNode == null) {
          throw Exception('findMin returned null unexpectedly.');
        }
        nextObj = nextNode.obj;
        removeNode(nextNode);
        node.obj = nextObj;
      } else {
        nextNode = findMin(node.left, node.dimension);
        if (nextNode == null) {
          throw Exception('findMin returned null unexpectedly.');
        }
        nextObj = nextNode.obj;
        removeNode(nextNode);
        node.right = node.left;
        node.left = null;
        node.obj = nextObj;
      }
    }

    nodeToRemove = nodeSearch(_root);

    if (nodeToRemove == null) {
      return;
    }

    removeNode(nodeToRemove);
  }

  /// 查找最近的 [maxNodes] 个节点。
  /// 距离通过 Metric 函数计算。
  /// 可以通过 [maxDistance] 参数设置最大距离
  // 修改后的 KDTree.nearest 方法
  List<dynamic> nearest(T point, int maxNodes, [double? maxDistance]) {
    if (_metric == null) {
      throw Exception(
          'Metric function undefined. Please define the metric function.');
    }

    final bestNodes = BinaryHeap<List<dynamic>>((e) => -e[1]);

    void nearestSearch(Node<T>? node) {
      if (node == null) return;

      final dimension = _dimensions[node.dimension];
      final ownDistance = _metric!(point, node.obj);

      if (node.left == null && node.right == null) {
        if (bestNodes.size() < maxNodes || ownDistance < bestNodes.peek()[1]) {
          if (maxDistance == null || ownDistance <= maxDistance) {
            bestNodes.push([node, ownDistance]);
            if (bestNodes.size() > maxNodes) {
              bestNodes.pop();
            }
          }
        }
        return;
      }

      Node<T>? bestChild;
      Node<T>? otherChild;
      final pointValue = _getDimension(point, dimension);
      final nodeValue = _getDimension(node.obj, dimension);

      if (pointValue.compareTo(nodeValue) < 0) {
        bestChild = node.left;
        otherChild = node.right;
      } else {
        bestChild = node.right;
        otherChild = node.left;
      }

      // 先搜索最可能包含最近邻的子节点
      nearestSearch(bestChild);

      if (bestNodes.size() < maxNodes || ownDistance < bestNodes.peek()[1]) {
        if (maxDistance == null || ownDistance <= maxDistance) {
          bestNodes.push([node, ownDistance]);
          if (bestNodes.size() > maxNodes) {
            bestNodes.pop();
          }
        }
      }

      // 计算在当前维度上的差值平方
      double diff = (pointValue.toDouble() - nodeValue.toDouble());
      double diffSquared = diff * diff;

      // 决定是否需要访问另一子节点
      if (bestNodes.size() < maxNodes || diffSquared < bestNodes.peek()[1]) {
        nearestSearch(otherChild);
      }
    }

    if (maxDistance != null) {
      for (var i = 0; i < maxNodes; i++) {
        bestNodes.push([null, maxDistance]);
      }
    }

    if (_root != null) {
      nearestSearch(_root);
    }

    final result = <dynamic>[];
    for (var i = 0; i < min(maxNodes, bestNodes.content.length); i++) {
      if (bestNodes.content[i][0] != null) {
        result.add([bestNodes.content[i][0].obj, bestNodes.content[i][1]]);
      }
    }

    return result;
  }

  /// 计算 K-d 树的平衡因子
  double balanceFactor() => height / (log(length) / log(2));

  KDTree.fromJson(
    Map<String, dynamic> json,
    this._getDimension,
    T Function(Map<String, dynamic>) fromJsonT,
  )   : _dimensions = List<String>.from(json['dim']),
        _metric = null {
    if (json['root'] != null) {
      _root = Node<T>.fromJson(json['root'], fromJsonT);
    }
  }

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) toJsonT) => {
        'dim': _dimensions,
        'root': _root?.toJson(toJsonT),
      };

  /// 计算 K-d 树的长度
  int get length {
    return _root?.length ?? 0;
  }

  /// 计算 K-d 树的高度
  int get height {
    return _root?.height ?? 0;
  }

  /// 返回在树创建时设置的维度
  List<String> get dimensions {
    return _dimensions;
  }

  /// 设置新的 Metric 函数。在 JSON 反序列化后必须这样做，因为 JSON 无法序列化函数。
  set metric(MetricFunction<T>? newMetric) {
    _metric = newMetric;
  }
}
