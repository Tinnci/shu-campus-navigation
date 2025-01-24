import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:executor_lib/executor_lib.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

import '../provider_exception.dart';
import '../tile_identity.dart';
import '../tile_providers.dart';
import '../vector_tile_provider.dart';
import 'memory_cache.dart';
import 'storage_cache.dart';
import 'package:logging/logging.dart' as log;

class VectorTileLoadingCache {
  final log.Logger appLogger = log.Logger('Vector_Tile_loading_cache_Logger');

  final Theme _theme;
  final MemoryTileDataCache _tileDataCache;
  final MemoryCache _memoryCache;
  final StorageCache _delegate;
  final TileProviders _providers;
  final Map<String, Future<Uint8List?>> _byteFuturesByKey = {};
  final Map<String, Future<Uint8List?>> _cacheByteFuturesByKey = {};
  final Executor _executor;
  bool _ready = false;
  final _readyCompleter = Completer<bool>();
  late final int maximumZoom;

  // 新增错误计数器
  int _providerExceptionCount = 0;
  int _unknownExceptionCount = 0;
  Timer? _logTimer;

  VectorTileLoadingCache(
      this._delegate,
      this._memoryCache,
      this._tileDataCache,
      this._providers,
      this._executor,
      this._theme) {
    maximumZoom = _providers.tileProviderBySource.values
        .map((e) => e.maximumZoom)
        .reduce(min);
    _initialize();
    _startLogTimer(); // 启动定时器
  }

  Future<TileData?> retrieve(String source, TileIdentity tile,
      {required CancellationCallback cancelled,
      required bool cachedOnly}) async {
    if (!_ready) {
      await _readyCompleter.future;
    }
    final key = _toKey(source, tile);
    return await _loadTile(source, key, tile, cancelled, cachedOnly);
  }

  void _initialize() async {
    final futures = _executor.submitAll(
        Job('setup theme', _setupTheme, _theme, deduplicationKey: null));
    for (final future in futures) {
      await future;
    }
    _ready = true;
    _readyCompleter.complete(true);
  }

  String _toKey(String source, TileIdentity id) =>
      '${id.z}_${id.x}_${id.y}_$source.pbf';

  Future<TileData?> _loadTile(String source, String key, TileIdentity tile,
      CancellationCallback cancelled, bool cachedOnly) async {
    appLogger.info('尝试加载瓦片: $tile 来自源: $source 使用键: $key');
    final cached = _tileDataCache.get(key);
    if (cached != null) {
      appLogger.fine('瓦片已缓存: $tile');
      return cached;
    }
    appLogger.fine('瓦片未缓存，从提供者加载。');
    var future =
        cachedOnly ? _cacheByteFuturesByKey[key] : _byteFuturesByKey[key];
    var loaded = false;
    if (future == null) {
      final provider = _providers.get(source);
      if (tile.z < provider.minimumZoom) {
        return _emptyTile();
      }
      loaded = true;
      future = _loadBytes(provider, key, tile, cachedOnly);
      if (cachedOnly) {
        _cacheByteFuturesByKey[key] = future;
      } else {
        _byteFuturesByKey[key] = future;
      }
    }
    Uint8List? bytes;
    try {
      bytes = await future;
      appLogger.fine('成功加载瓦片字节: $tile');
    } on ProviderException catch (error) {
      _providerExceptionCount++;
      if (error.statusCode == 404 || error.statusCode == 204) {
        return _emptyTile();
      }
      // 如果达到一定次数，记录一次汇总日志
      if (_providerExceptionCount >= 10) { // 设定阈值，例如10次
        appLogger.warning(
            '在短时间内有$_providerExceptionCount次Provider异常加载瓦片。最近的错误: $error');
        _providerExceptionCount = 0; // 重置计数器
      }
      // 可以选择继续抛出异常，或根据需求处理
      // rethrow;
    } catch (e) {
      _unknownExceptionCount++;
      if (_unknownExceptionCount >= 10) { // 设定阈值，例如10次
        appLogger.severe(
            '在短时间内有$_unknownExceptionCount次未知错误加载瓦片。最近的错误: $e');
        _unknownExceptionCount = 0; // 重置计数器
      }
      // 可以选择继续抛出异常，或根据需求处理
      // rethrow;
    } finally {
      if (loaded) {
        if (cachedOnly) {
          _cacheByteFuturesByKey.remove(key);
        } else {
          _byteFuturesByKey.remove(key);
        }
      }
    }
    // 确保 bytes 数据有效
    if (bytes == null || bytes.isEmpty) {
      _providerExceptionCount++;
      if (_providerExceptionCount >= 10) { // 设定阈值，例如10次
        appLogger.warning(
            '在短时间内有$_providerExceptionCount次加载瓦片字节为空或无效。');
        _providerExceptionCount = 0; // 重置计数器
      }
      return null;
    }
    final name = '$key/${_theme.id}';
    final tileData = await _executor.submit(Job(
        name, _createTile, _ThemeTile(themeId: _theme.id, bytes: bytes),
        cancelled: cancelled, deduplicationKey: name));
    _tileDataCache.put(key, tileData);
    return tileData;
  }

  Future<Uint8List?> _loadBytes(VectorTileProvider provider, String key,
      TileIdentity tile, bool cachedOnly) async {
    var bytes = _memoryCache.get(key) ?? await _delegate.retrieve(key);
    if (bytes == null && !cachedOnly) {
      bytes = await provider.provide(tile);
      _memoryCache.put(key, bytes);
      await _delegate.put(key, bytes);
    }
    return bytes;
  }

  TileData _emptyTile() => TileFactory(_theme, const Logger.noop())
      .createTileData(VectorTile(layers: []));

  // 启动定时器，定期记录汇总日志
  void _startLogTimer() {
    // 每隔一分钟记录一次汇总日志
    _logTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_providerExceptionCount > 0) {
        appLogger.warning(
            '在过去的一分钟内有$_providerExceptionCount次Provider异常加载瓦片。');
        _providerExceptionCount = 0;
      }
      if (_unknownExceptionCount > 0) {
        appLogger.severe(
            '在过去的一分钟内有$_unknownExceptionCount次未知错误加载瓦片。');
        _unknownExceptionCount = 0;
      }
    });
  }

  // 停止定时器
  void _stopLogTimer() {
    _logTimer?.cancel();
  }

  // 移除 @override 注解，因为没有父类的方法可以覆盖
  void dispose() {
    _stopLogTimer(); // 确保定时器被停止
  }
}

class _ThemeTile {
  final String themeId;
  final Uint8List bytes;

  _ThemeTile({required this.themeId, required this.bytes});
}

final _themeById = <String, Theme>{};

Future<void> _setupTheme(Theme theme) async {
  _themeById[theme.id] = theme;
}

TileData _createTile(_ThemeTile themeTile) =>
    TileFactory(_themeById[themeTile.themeId]!, const Logger.noop())
        .createTileData(VectorTileReader().read(themeTile.bytes));
