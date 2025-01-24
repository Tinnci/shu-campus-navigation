## 上海大学通信与信息学院数据结构课程项目 - 校园地图导航系统

### 项目简介
本项目是一个基于 Flutter 开发的上海大学校园地图导航系统，主要实现校园地图展示和路径导航功能。

### 项目结构
```
lib/
├─services/
│      path_finding_service.dart    # 路径规划核心服务
│      valhalla_service.dart        # Valhalla路由引擎集成
│
├─ui/
│  └─screens/
│         campus_map_screen.dart    # 校园地图主界面
│
└─utils/
       geo_utils.dart              # 地理坐标工具类
       logging_utils.dart          # 日志工具类
```

### 核心功能

#### 1. 路径规划引擎
- 基于KD树的最近邻搜索
- Dijkstra最短路径算法
- 路网连通性分析与优化
- 路径投影与匹配

#### 2. 地图数据处理
- 矢量瓦片(MBTiles)解析与渲染
- GeoJSON数据处理
- 空间索引优化

#### 3. 导航功能
- 最短路径计算
- 分段导航指令生成
- 距离计算与时间估算

### 技术依赖

#### 核心依赖包
- flutter_map: 地图渲染引擎
- latlong2: 地理坐标处理
- kdtree: 空间索引实现
- sqlite3_flutter_libs: 数据库支持

#### 本地修改包
- vector_map_tiles
- mbtiles
- flutter_map_mbtiles

### 数据资源
- assets/shu_map.mbtiles: 校园地图瓦片数据
- assets/shu.geojson: 校园POI和路网数据
- assets/map_style.json: 地图样式配置

### 开发环境要求
- Flutter SDK: >=3.0.0 <4.0.0
- Dart SDK: >=3.0.0 <4.0.0

## Flutter 项目基础知识

### 项目结构说明
Flutter 项目的标准结构如下：
```
项目根目录/
├── lib/                 # 主要的 Dart 源代码目录
├── assets/             # 资源文件目录（图片、字体等）
├── test/              # 测试代码目录
├── android/           # Android 平台相关代码
├── ios/              # iOS 平台相关代码
├── windows/          # Windows 平台相关代码
├── pubspec.yaml      # 项目配置文件，包含依赖项和资源声明
└── README.md         # 项目说明文档
```

### lib 目录组织
- `lib/main.dart`: 应用程序的入口点
- `lib/models/`: 数据模型类
- `lib/services/`: 业务逻辑和服务类
- `lib/ui/`: 用户界面相关代码
- `lib/utils/`: 工具类和辅助函数

## 环境要求
- Flutter SDK: >=3.0.0 <4.0.0
- 操作系统：Windows/Linux/macOS

## 开发环境设置
1. 安装 Flutter SDK
2. 配置 Flutter 环境变量
3. 安装 IDE（推荐 VS Code 或 Android Studio）
4. 安装 Flutter 和 Dart 插件

## 依赖说明

### 本地修改的地图相关插件
- flutter_map (本地包)
- vector_map_tiles_mbtiles (本地包)
- mbtiles (本地包)
- vector_map_tiles (本地包)
- vector_tile_renderer (本地包)
- flutter_map_mbtiles (本地包)
- line_animator (本地包)
- kdtree (本地包)

### 第三方依赖包
- cupertino_icons: ^1.0.8 (iOS 风格图标)
- path_provider: ^2.1.4 (文件系统访问)
- latlong2: ^0.9.1 (地理坐标处理)
- http: ^1.2.2 (网络请求)
- url_strategy: ^0.3.0 (URL 策略)
- logging: ^1.2.0 (日志记录)
- crypto: ^3.0.5 (加密功能)
- sqlite3_flutter_libs: ^0.5.24 (SQLite 支持)
- package_info_plus: ^8.0.2 (应用包信息)
- shared_preferences: ^2.3.2 (本地数据存储)
- flutter_riverpod: ^2.5.1 (状态管理)
- flutter_polyline_points: ^2.1.0 (路线绘制)
- sqflite & sqflite_common_ffi (数据库支持)
- collection: ^1.19.0 (集合操作工具)
- r_tree (空间索引)

### 开发依赖
- flutter_test (单元测试支持)
- flutter_lints: ^4.0.0 (代码规范检查)

## 资源文件
- assets/map_style.json (地图样式配置)
- assets/shu_map.mbtiles (离线地图数据)
- assets/shu_map.osm.pbf (OpenStreetMap 数据)
- assets/windows/sqlite3.dll (Windows SQLite 支持)
- assets/shu.geojson (地理数据)

## 开始使用
1. 克隆项目
```bash
git clone https://github.com/tinnci/shu-campus-navigation.git
cd shu-campus-navigation
```

2. 安装依赖
```bash
flutter pub get
```

3. 运行项目
```bash
flutter run
```

### 开发指南

#### 路径规划服务开发
- 路径规划服务位于 `lib/services/path_finding_service.dart`
- 使用 KD树进行空间索引和最近邻搜索
- 实现了 Dijkstra 算法进行最短路径计算
- 包含路网连通性检查和修复功能

#### 地图数据处理
- 支持离线矢量瓦片(MBTiles)格式
- GeoJSON 数据的解析和处理
- 提供了地图样式自定义功能

### 常见问题

1. 地图瓦片无法加载
   - 检查 assets 目录下是否包含 shu_map.mbtiles 文件
   - 确认 pubspec.yaml 中已正确配置资源路径

2. 路径规划失败
   - 检查起终点是否在路网覆盖范围内
   - 确认 shu.geojson 文件包含完整的路网数据

### 项目维护

#### 代码规范
- 遵循 Flutter 官方代码规范
- 使用 flutter_lints 进行代码质量检查
- 保持代码注释的完整性

#### 性能优化
- 使用空间索引提升路径查询效率
- 实现瓦片数据缓存机制
- 优化大规模路网数据的处理

### 贡献指南

1. Fork 项目仓库
2. 创建功能分支
3. 提交代码更改
4. 创建 Pull Request

### 许可证
MIT License
## 注意事项
- 首次运行前确保已安装所有依赖
- 确保 assets 目录下的地图资源文件完整
- Windows 平台需要 sqlite3.dll 支持

### 本地包版本兼容性

由于项目使用了多个本地修改的地图相关插件，这些插件的 `pubspec.yaml` 中可能包含过时的 SDK 约束，需要进行以下调整：

1. `local_packages/flutter_map/pubspec.yaml`:
```yaml
environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.0.0"
```

2. `local_packages/vector_map_tiles/pubspec.yaml`:
```yaml
environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.0.0"
```

3. `local_packages/mbtiles/pubspec.yaml`:
```yaml
environment:
  sdk: ">=3.0.0 <4.0.0"
```

4. `local_packages/flutter_map_mbtiles/pubspec.yaml`:
```yaml
environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.0.0"
```

请在运行项目前检查并更新这些本地包的 SDK 版本约束，以确保项目能够正常编译和运行。如果遇到其他依赖相关的编译错误，也请检查相应包的版本约束。

### 其他依赖说明
- 确保所有本地包的依赖项版本与主项目保持一致
- 如遇编译错误，可能需要手动解决依赖冲突
- 建议使用 `flutter pub get --verbose` 命令查看详细的依赖解析过程

## 项目状态说明

⚠️ **重要提示**：
- 本项目是上海大学通信与信息学院数据结构课程的学生作业项目
- 项目目前处于**冻结状态**，不再进行维护和更新
- 代码仅供学习和参考使用
- 不建议用于生产环境

如果您对本项目感兴趣，建议：
- Fork 本项目进行自己的开发和改进
- 参考项目中的算法实现和架构设计
- 使用本项目作为学习 Flutter 开发和地图应用的参考资料

### 地图数据获取

#### MBTiles 文件
项目需要的地图数据文件（`assets/shu_map.mbtiles`）由于文件较大未包含在代码仓库中。你需要：

1. 使用 QGIS 下载上海大学区域的地图数据
2. 导出为 MBTiles 格式
3. 将生成的文件重命名为 `shu_map.mbtiles` 并放置在 `assets` 目录下

具体步骤：
1. 打开 QGIS
2. 安装 QuickMapServices 插件
3. 添加 OpenStreetMap 底图
4. 选择上海大学区域（宝山校区）
5. 使用 "导出地图瓦片" 功能导出为 MBTiles 格式
6. 确保导出时选择合适的缩放级别（建议 14-19 级）