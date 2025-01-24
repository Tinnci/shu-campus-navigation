import 'dart:math';

class Node<T> {
  T obj;
  int dimension;
  Node<T>? parent;
  Node<T>? left;
  Node<T>? right;

  Node(this.obj, this.dimension, this.parent);

  Node.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  )   : obj = fromJsonT(json['obj']),
        dimension = json['dim'] {
    if (json['left'] != null) {
      left = Node<T>.fromJson(json['left'], fromJsonT);
      left?.parent = this;
    }
    if (json['right'] != null) {
      right = Node<T>.fromJson(json['right'], fromJsonT);
      right?.parent = this;
    }
  }

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) toJsonT) => {
        'obj': toJsonT(obj),
        'dim': dimension,
        'left': left?.toJson(toJsonT),
        'right': right?.toJson(toJsonT),
      };

  int get length {
    return 1 +
        (left?.length ?? 0) +
        (right?.length ?? 0);
  }

  int get height {
    return 1 +
        max(
          left?.height ?? 0,
          right?.height ?? 0,
        );
  }

  int get depth {
    return 1 + (parent?.depth ?? 0);
  }
}
