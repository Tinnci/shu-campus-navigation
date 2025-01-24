import 'package:flutter_riverpod/flutter_riverpod.dart';

final mapStateProvider = StateNotifierProvider<MapStateNotifier, MapState>((ref) {
  return MapStateNotifier();
});

class MapState {
  final int selectedIndex;
  final bool isMapLoaded;
  final bool isError;
  final String errorMessage;

  MapState({
    this.selectedIndex = 0,
    this.isMapLoaded = false,
    this.isError = false,
    this.errorMessage = '',
  });

  MapState copyWith({
    int? selectedIndex,
    bool? isMapLoaded,
    bool? isError,
    String? errorMessage,
  }) {
    return MapState(
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isMapLoaded: isMapLoaded ?? this.isMapLoaded,
      isError: isError ?? this.isError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class MapStateNotifier extends StateNotifier<MapState> {
  MapStateNotifier() : super(MapState()) {
    _loadMap();
  }

  Future<void> _loadMap() async {
    try {
      state = state.copyWith(isError: false, isMapLoaded: false, errorMessage: '');

      await Future.delayed(const Duration(seconds: 2)); // 模拟加载地图的延迟
      _onMapLoaded();
    } catch (e) {
      state = state.copyWith(isError: true, errorMessage: '地图加载失败，请检查网络或重试。');
    }
  }

  void _onMapLoaded() {
    state = state.copyWith(isMapLoaded: true);
  }

  void retryLoadMap() {
    _loadMap();
  }

  void onItemTapped(int index) {
    if (state.selectedIndex != index) {
      state = state.copyWith(selectedIndex: index);
    }
  }
}
