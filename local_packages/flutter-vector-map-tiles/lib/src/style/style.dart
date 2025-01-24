import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

import '../provider/network_vector_tile_provider.dart';
import '../tile_providers.dart';
import '../vector_tile_provider.dart';
import 'uri_mapper.dart';

class Style {
  final String? name;
  final Theme theme;
  final TileProviders providers;
  final SpriteStyle? sprites;
  final LatLng? center;
  final double? zoom;

  Style(
      {this.name,
      required this.theme,
      required this.providers,
      this.sprites,
      this.center,
      this.zoom});
}

class SpriteStyle {
  final Future<Uint8List> Function() atlasProvider;
  final SpriteIndex index;

  SpriteStyle({required this.atlasProvider, required this.index});
}

class StyleReader {
  final String uri;
  final String? apiKey;
  final Logger logger;
  final Map<String, String>? httpHeaders;

  StyleReader(
      {required this.uri, this.apiKey, Logger? logger, this.httpHeaders})
      : logger = logger ?? const Logger.noop();

  Future<Style> read() async {
    final uriMapper = StyleUriMapper(key: apiKey);
    final url = uriMapper.map(uri);
    final styleText = await _httpGet(url, httpHeaders, logger); // 传递 logger
    var style = await compute(jsonDecode, styleText);

    if (style is! Map<String, dynamic>) {
      throw _invalidStyle(url);
    }

    // 替换 JSON 中的 {key} 占位符
    style = _replaceKeyInStyle(style, apiKey);

    final sources = style['sources'];
    if (sources is! Map) {
      throw _invalidStyle(url);
    }
    final providerByName = await _readProviderByName(sources);
    final name = style['name'] as String?;

    final center = style['center'];
    LatLng? centerPoint;
    if (center is List && center.length == 2) {
      centerPoint =
          LatLng((center[1] as num).toDouble(), (center[0] as num).toDouble());
    }
    double? zoom = (style['zoom'] as num?)?.toDouble();
    if (zoom != null && zoom < 2) {
      zoom = null;
      centerPoint = null;
    }
    final spriteUri = style['sprite'];
    SpriteStyle? sprites;
    if (spriteUri is String && spriteUri.trim().isNotEmpty) {
      final spriteUris = uriMapper.mapSprite(uri, spriteUri);
      for (final spriteUri in spriteUris) {
        dynamic spritesJson;
        try {
          final spritesJsonText =
              await _httpGet(spriteUri.json, httpHeaders, logger);
          spritesJson = await compute(jsonDecode, spritesJsonText);
        } catch (e) {
          logger.log(() => 'error reading sprite uri: ${spriteUri.json}');
          continue;
        }
        sprites = SpriteStyle(
            atlasProvider: () =>
                _loadBinary(spriteUri.image, httpHeaders, logger),
            index: SpriteIndexReader(logger: logger).read(spritesJson));
        break;
      }
    }
    return Style(
        theme: ThemeReader(logger: logger).read(style),
        providers: TileProviders(providerByName),
        sprites: sprites,
        name: name,
        center: centerPoint,
        zoom: zoom);
  }

  Map<String, dynamic> _replaceKeyInStyle(
      Map<dynamic, dynamic> style, String? apiKey) {
    final Map<String, dynamic> updatedStyle = {};

    style.forEach((key, value) {
      if (key is String) {
        if (value is String && value.contains('{key}')) {
          updatedStyle[key] = value.replaceAll('{key}', apiKey ?? '');
        } else if (value is Map) {
          updatedStyle[key] =
              _replaceKeyInStyle(Map<String, dynamic>.from(value), apiKey);
        } else if (value is List) {
          updatedStyle[key] = value.map((item) {
            if (item is String && item.contains('{key}')) {
              return item.replaceAll('{key}', apiKey ?? '');
            } else if (item is Map) {
              return _replaceKeyInStyle(
                  Map<String, dynamic>.from(item), apiKey);
            } else {
              return item;
            }
          }).toList();
        } else {
          updatedStyle[key] = value;
        }
      }
    });

    return updatedStyle;
  }

  Future<Map<String, VectorTileProvider>> _readProviderByName(
      Map sources) async {
    final providers = <String, VectorTileProvider>{};
    final sourceEntries = sources.entries.toList();

    for (final entry in sourceEntries) {
      final type = TileProviderType.values
          .where((e) => e.name == entry.value['type'])
          .firstOrNull;
      if (type == null) continue;

      dynamic source;
      var entryUrl = entry.value['url'] as String?;

      if (entryUrl != null) {
        final sourceUrl = StyleUriMapper(key: apiKey).mapSource(uri, entryUrl);
        if (sourceUrl.contains('{key}')) {
          // 使用 warn 记录警告消息
          logger.warn(() => 'Skipping source with unresolved key: $sourceUrl');
          continue;
        }

        source = await compute(
            jsonDecode, await _httpGet(sourceUrl, httpHeaders, logger));

        if (source is! Map) {
          throw _invalidStyle(sourceUrl);
        }
      } else {
        source = entry.value;
      }

      final entryTiles = source['tiles'];
      final maxzoom = source['maxzoom'] as int? ?? 14;
      final minzoom = source['minzoom'] as int? ?? 1;

      if (entryTiles is List && entryTiles.isNotEmpty) {
        final tileUri = entryTiles[0] as String;
        final tileUrl = StyleUriMapper(key: apiKey).mapTiles(tileUri);

        if (tileUrl.contains('{key}')) {
          // 使用 warn 记录警告消息
          logger.warn(() => 'Skipping tile URL with unresolved key: $tileUrl');
          continue;
        }

        providers[entry.key] = NetworkVectorTileProvider(
            type: type,
            urlTemplate: tileUrl,
            maximumZoom: maxzoom,
            minimumZoom: minzoom,
            httpHeaders: httpHeaders);
      }
    }

    if (providers.isEmpty) {
      throw 'Unexpected response';
    }

    return providers;
  }
}

String _invalidStyle(String url) =>
    'Uri does not appear to be a valid style: $url';

Future<String> _httpGet(
    String url, Map<String, String>? httpHeaders, Logger logger) async {
  logger.info(() => 'Sending GET request to: $url');
  
  // 获取本地缓存目录
  final cacheDir = await getTemporaryDirectory();
  final cacheFile = File('${cacheDir.path}/${url.hashCode}.json');

  // 检查本地是否已经缓存了该文件
  if (await cacheFile.exists()) {
    logger.info(() => 'Cache hit for: $url');
    return await cacheFile.readAsString();
  }

  // 如果是本地资源路径，直接加载
  if (url.startsWith('assets/')) {
    return await rootBundle.loadString(url);
  } else {
    // 发送 HTTP 请求
    final response = await get(Uri.parse(url), headers: httpHeaders);
    if (response.statusCode == 200) {
      // 缓存请求结果到本地文件
      await cacheFile.writeAsString(response.body);
      return response.body;
    } else {
      logger.severe(() =>
          'Request failed with status: ${response.statusCode}, body: ${response.body}');
      throw 'HTTP ${response.statusCode}: ${response.body}';
    }
  }
}

Future<Uint8List> _loadBinary(
    String url, Map<String, String>? httpHeaders, Logger logger) async {
  logger.info(() => 'Sending binary GET request to: $url');
  
  final cacheDir = await getTemporaryDirectory();
  final cacheFile = File('${cacheDir.path}/${url.hashCode}.bin');

  // 检查本地是否有缓存
  if (await cacheFile.exists()) {
    logger.info(() => 'Cache hit for: $url');
    return await cacheFile.readAsBytes();
  }

  final response = await get(Uri.parse(url), headers: httpHeaders);
  if (response.statusCode == 200) {
    // 缓存二进制文件
    await cacheFile.writeAsBytes(response.bodyBytes);
    return response.bodyBytes;
  } else {
    logger.severe(() =>
        'Binary request failed with status: ${response.statusCode}, body: ${response.body}');
    throw 'HTTP ${response.statusCode}: ${response.body}';
  }
}

