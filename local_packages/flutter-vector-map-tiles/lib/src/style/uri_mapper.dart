import 'package:logger/logger.dart';

class StyleUriMapper {
  final String? _key;
  final Logger logger; // 添加 logger 实例

  StyleUriMapper({String? key, Logger? logger})
      : _key = key,
        logger = logger ?? Logger(); // 初始化 logger

  String map(String uri) {
    try {
      if (uri.startsWith('assets/')) {
        // 对于本地资源路径，直接返回
        return uri;
      }

      var mapped = uri;
      final parsed = Uri.parse(uri);
      logger.i('Original URI: $uri');

      if (parsed.scheme == 'mapbox') {
        mapped = _toMapboxStyleApiUri(uri);
      } else if (uri.contains(_keyToken)) {
        // 如果URI中包含`{key}`占位符则进行替换
        mapped = _replaceKey(mapped, _key);
      }

      logger.i('Mapped URI: $mapped');
      return mapped;
    } catch (e) {
      logger.e('Error mapping URI: $e');
      rethrow;
    }
  }

  String mapSource(String styleUri, String sourceUri) {
    logger.i('Mapping source URI: $sourceUri with style URI: $styleUri');

    if (sourceUri.startsWith('assets/')) {
      // 对于本地资源路径，直接返回
      return sourceUri;
    }

    final parameters = Uri.parse(map(styleUri)).queryParameters;
    final parsed = Uri.parse(sourceUri);
    var mapped = sourceUri;

    if (parsed.scheme == 'mapbox') {
      mapped = _toMapboxSourceApiUri(mapped, parameters);
    } else if (sourceUri.contains(_keyToken)) {
      // 如果sourceUri中包含`{key}`占位符则进行替换
      mapped = _replaceKey(mapped, _key);
    }

    logger.i('Mapped source URI: $mapped');
    return mapped;
  }

  List<SpriteUri> mapSprite(String styleUri, String spriteUri) {
    logger.i('Mapping sprite URI: $spriteUri with style URI: $styleUri');

    if (spriteUri.startsWith('assets/')) {
      // 如果是本地资源路径，直接返回对应的 SpriteUri 列表
      return [
        SpriteUri(json: '$spriteUri@2x.json', image: '$spriteUri@2x.png'),
        SpriteUri(json: '$spriteUri.json', image: '$spriteUri.png')
      ];
    }

    final parameters = Uri.parse(map(styleUri)).queryParameters;
    final parsed = Uri.parse(spriteUri);
    final uris = <SpriteUri>[];

    if (parsed.scheme == 'mapbox') {
      uris.add(_toMapboxSpriteUri(spriteUri, parameters, '@2x'));
      uris.add(_toMapboxSpriteUri(spriteUri, parameters, ''));
    } else {
      uris.add(_toSpriteUri(spriteUri, parameters, '@2x'));
      uris.add(_toSpriteUri(spriteUri, parameters, ''));
    }

    for (var sprite in uris) {
      logger
          .i('Mapped sprite URI: JSON: ${sprite.json}, Image: ${sprite.image}');
    }

    return uris;
  }

  String mapTiles(String tileUri) {
    return _replaceKey(tileUri, _key);
  }

  String _toMapboxStyleApiUri(String uri) {
    final match =
        RegExp(r'mapbox://styles/([^/]+)/([^?]+)\??(.+)?').firstMatch(uri);
    if (match == null) {
      throw 'Unexpected format: $uri';
    }
    final username = match.group(1);
    final styleId = match.group(2);
    final parameters = match.group(3);
    var apiUri = 'https://api.mapbox.com/styles/v1/$username/$styleId';
    if (parameters != null && parameters.isNotEmpty) {
      apiUri = '$apiUri?$parameters';
    }
    return apiUri;
  }

  String _toMapboxSourceApiUri(
      String sourceUri, Map<String, String> parameters) {
    final match = RegExp(r'mapbox://(.+)').firstMatch(sourceUri);
    if (match == null) {
      throw 'Unexpected format: $sourceUri';
    }
    final style = match.group(1);
    return 'https://api.mapbox.com/v4/$style.json?secure&${parameters.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
  }

  SpriteUri _toMapboxSpriteUri(
      String spriteUri, Map<String, String> parameters, String suffix) {
    final match = RegExp(r'mapbox://sprites/(.+)').firstMatch(spriteUri);
    if (match == null) {
      throw 'Unexpected format: $spriteUri';
    }
    final sprite = match.group(1);
    return SpriteUri(
        json:
            'https://api.mapbox.com/styles/v1/$sprite/sprite$suffix.json?secure&${parameters.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}',
        image:
            'https://api.mapbox.com/styles/v1/$sprite/sprite$suffix.png?secure&${parameters.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}');
  }

  SpriteUri _toSpriteUri(
      String spriteUri, Map<String, String> parameters, String suffix) {
    return SpriteUri(
        json:
            '$spriteUri$suffix.json?secure&${parameters.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}',
        image:
            '$spriteUri$suffix.png?secure&${parameters.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}');
  }
}

String _replaceKey(String url, String? key) {
  if (key == null || key.isEmpty) {
    // 如果key为空或未提供，则移除`{key}`占位符
    return url.replaceAll(RegExp(RegExp.escape(_keyToken)), '');
  } else {
    // 否则用提供的key替换
    return url.replaceAll(
        RegExp(RegExp.escape(_keyToken)), Uri.encodeQueryComponent(key));
  }
}

const _keyToken = '{key}';

class SpriteUri {
  final String json;
  final String image;

  SpriteUri({required this.json, required this.image});
}
