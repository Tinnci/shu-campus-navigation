class BinaryHeap<E> {
  final double Function(E) scoreFunction;
  final List<E> content;

  BinaryHeap(this.scoreFunction) : content = [];

  void push(E element) {
    content.add(element);
    // 允许向上冒泡。
    bubbleUp(content.length - 1);
  }

  E pop() {
    if (content.isEmpty) {
      throw Exception('Heap is empty.');
    }
    // 存储第一个元素以便稍后返回。
    final result = content[0];
    // 获取数组末尾的元素。
    final end = content.removeLast();
    // 如果还有元素，将末尾元素放到开始，并让其下沉。
    if (content.isNotEmpty) {
      content[0] = end;
      sinkDown(0);
    }
    return result;
  }

  E peek() {
    if (content.isEmpty) {
      throw Exception('Heap is empty.');
    }
    return content[0];
  }

  void remove(E element) {
    final len = content.length;
    for (var i = 0; i < len; i++) {
      if (content[i] == element) {
        final end = content.removeLast();
        if (i != len - 1) {
          content[i] = end;
          if (scoreFunction(end) < scoreFunction(element)) {
            bubbleUp(i);
          } else {
            sinkDown(i);
          }
        }
        return;
      }
    }
    throw Exception('Element not found in heap.');
  }

  int size() {
    return content.length;
  }

  void bubbleUp(int n) {
    final element = content[n];
    while (n > 0) {
      final parentN = ((n + 1) / 2).floor() - 1;
      final parent = content[parentN];
      if (scoreFunction(element) < scoreFunction(parent)) {
        content[parentN] = element;
        content[n] = parent;
        n = parentN;
      } else {
        break;
      }
    }
  }

  void sinkDown(int n) {
    final length = content.length;
    final element = content[n];
    final elemScore = scoreFunction(element);

    while (true) {
      final child2N = (n + 1) * 2;
      final child1N = child2N - 1;
      int? swap;
      double? child1Score;

      if (child1N < length) {
        final child1 = content[child1N];
        child1Score = scoreFunction(child1);
        if (child1Score < elemScore) {
          swap = child1N;
        }
      }

      if (child2N < length) {
        final child2 = content[child2N];
        final child2Score = scoreFunction(child2);
        if (child2Score < (swap == null ? elemScore : child1Score!)) {
          swap = child2N;
        }
      }

      if (swap != null) {
        content[n] = content[swap];
        content[swap] = element;
        n = swap;
      } else {
        break;
      }
    }
  }
}
