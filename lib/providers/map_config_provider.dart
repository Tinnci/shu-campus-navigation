import 'package:flutter_riverpod/flutter_riverpod.dart';

// 定义一个配置类来存储 API URL 和 API key
class MapConfig {
  final String apiUrl;
  final String apiKey;

  MapConfig({required this.apiUrl, required this.apiKey});

  // 更新 apiUrl 和 apiKey
  MapConfig copyWith({String? apiUrl, String? apiKey}) {
    return MapConfig(
      apiUrl: apiUrl ?? this.apiUrl,
      apiKey: apiKey ?? this.apiKey,
    );
  }

  @override
  String toString() {
    return 'API URL: $apiUrl, API Key: $apiKey';
  }
}

// 定义一个预设类，用于存储预设的名称和配置
class PresetConfig {
  final String name;
  final MapConfig config;

  PresetConfig({required this.name, required this.config});
}

// StateNotifier 管理 MapConfig 的状态，包括 API 历史记录和预设
class MapConfigNotifier extends StateNotifier<MapConfig> {
  MapConfigNotifier()
      : super(MapConfig(
            apiUrl: 'assets/map_style.json', apiKey: '0LG1oUxWEAhbiDq9gn3C'));

  // 历史记录列表，存储完整的 MapConfig 对象
  List<MapConfig> configHistory = [];

  // 预设 API 配置，使用 PresetConfig 存储名称和配置
// 在 PresetConfig 列表中添加一个本地 assets 文件作为预设
  final List<PresetConfig> presets = [
    PresetConfig(
      name: 'Local Asset',
      config: MapConfig(
          apiUrl: 'assets/map_style.json', // 本地 asset 文件路径
          apiKey: '0LG1oUxWEAhbiDq9gn3C'), // 本地文件也需要 API Key
    ),
    PresetConfig(
      name: 'OSM Bright',
      config: MapConfig(
          apiUrl:
              'https://cdn.jsdelivr.net/gh/openmaptiles/osm-bright-gl-style@v1.9/style.json',
          apiKey: '0LG1oUxWEAhbiDq9gn3C'),
    ),
    PresetConfig(
      name: 'Klokantech Basic',
      config: MapConfig(
          apiUrl:
              'https://cdn.jsdelivr.net/gh/openmaptiles/klokantech-basic-gl-style@v1.9/style.json',
          apiKey: '0LG1oUxWEAhbiDq9gn3C'),
    ),
  ];

  // 更新 API URL 和 Key，并保存到历史记录
  void updateApiConfig(String newApiUrl, String newApiKey) {
    final newConfig = state.copyWith(apiUrl: newApiUrl, apiKey: newApiKey);

    // 如果历史记录不包含该配置，则保存到历史记录
    if (!configHistory.contains(newConfig)) {
      configHistory.add(newConfig);
    }

    state = newConfig;
  }

  // 应用预设的 API 配置
  void applyPreset(String presetName) {
    final preset = presets.firstWhere(
      (preset) => preset.name == presetName,
      orElse: () => presets[0], // 默认选择第一个预设
    );
    state = preset.config;

    // 将预设添加到历史记录中
    if (!configHistory.contains(preset.config)) {
      configHistory.add(preset.config);
    }
  }

  // 获取所有的预设名称
  List<String> getPresetNames() {
    return presets.map((preset) => preset.name).toList();
  }

  // 清除 API 历史记录
  void clearHistory() {
    configHistory.clear();
  }
}

// 提供一个 MapConfig 的 Provider
final mapConfigProvider = StateNotifierProvider<MapConfigNotifier, MapConfig>(
  (ref) => MapConfigNotifier(),
);
