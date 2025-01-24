import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:executor_lib/executor_lib.dart';
import 'package:flutter/widgets.dart' hide Image;
import 'package:flutter_map/flutter_map.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' hide TileLayer;

import '../../vector_map_tiles.dart';
import '../grid/grid_tile_positioner.dart';
import '../grid/slippy_map_translator.dart';
import '../stream/tile_supplier.dart';
import '../stream/tile_supplier_raster.dart';
import '../stream/translated_tile_request.dart';
import '../stream/translating_tile_provider.dart';
import 'storage_image_cache.dart';
import 'package:logging/logging.dart' as log;

class TileLoader {
  final log.Logger appLogger = log.Logger('TileLogger'); // 添加 Logger 实例

  final Theme _theme;
  final SpriteStyle? _sprites;
  final Future<Image> Function()? _spriteAtlas;
  final TranslatingTileProvider _provider;
  final RasterTileProvider _rasterTileProvider;
  final StorageImageCache _imageCache;
  final TileOffset _tileOffset;
  final int _concurrency;
  final _scale = 2.0;
  late final ConcurrencyExecutor _jobQueue;

  TileLoader(
      this._theme,
      this._sprites,
      this._spriteAtlas,
      this._provider,
      this._rasterTileProvider,
      this._tileOffset,
      this._imageCache,
      this._concurrency) {
    _jobQueue = ConcurrencyExecutor(
        delegate: ImmediateExecutor(),
        concurrencyLimit: _concurrency * 2,
        maxQueueSize: _maxOutstandingJobs);
  }

  Future<ImageInfo> loadTile(TileCoordinates coords, TileLayer options,
      bool Function() cancelled) async {
    final requestedTile =
        TileIdentity(coords.z.toInt(), coords.x.toInt(), coords.y.toInt());
    var requestZoom = requestedTile.z;
    if (_tileOffset.zoomOffset < 0) {
      requestZoom = max(
          1, min(requestZoom + _tileOffset.zoomOffset, _provider.maximumZoom));
    }
    final cached = await _imageCache.retrieve(requestedTile);
    if (cached != null) {
      return ImageInfo(image: cached, scale: _scale);
    }
    final job =
        _TileJob(requestedTile, requestZoom, options.tileSize, cancelled);
    return _jobQueue.submit(Job<_TileJob, ImageInfo>(
        'render $requestedTile', _renderJob, job,
        deduplicationKey: 'render $requestedTile'));
  }

  Future<ImageInfo> _renderJob(job) => _renderTile(
      job.requestedTile, job.requestZoom, job.tileSize, job.cancelled);

  Future<ImageInfo> _renderTile(TileIdentity requestedTile, int requestZoom,
      double tileSize, bool Function() cancelled) async {
    appLogger
        .info('Starting to render tile: $requestedTile at zoom: $requestZoom');
    if (cancelled()) {
      throw CancellationException();
    }
    final translator = SlippyMapTranslator(_provider.maximumZoom);
    var translation = translator.translate(requestedTile);
    final originalRequest = TileRequest(
        tileId: requestedTile,
        zoom: requestedTile.z.toDouble(),
        zoomDetail: requestedTile.z.toDouble(),
        cancelled: cancelled);
    final translatedRequest =
        createTranslatedRequest(originalRequest, maximumZoom: requestZoom);

    final spriteAtlas = await _spriteAtlas?.call();
    final tileResponseFuture = _provider.provide(translatedRequest);
    final rasterTile =
        await _rasterTileProvider.retrieve(requestedTile.normalize());
    try {
      final tileResponse = await tileResponseFuture;
      appLogger.info('Tile response received for tile: $requestedTile');
      final tileset = tileResponse.tileset;
      if (tileset == null) {
        appLogger.warning(
            'No tileset found in tile response for tile: $requestedTile');
        throw 'No tile: $requestedTile';
      }

      // **检查 Tileset 中每个 Tile 的内容**
      if (tileset.tiles.isNotEmpty) {
        appLogger.info('Tileset contains ${tileset.tiles.length} tiles.');
        tileset.tiles.forEach((sourceId, tile) {
          appLogger.info('Processing tile for source: $sourceId');

          // 迭代每个 Tile 的 layers
          for (var layer in tile.layers) {
            appLogger.info(
                'Layer name: ${layer.name}, features count: ${layer.features.length}');

            // 进一步处理每个 feature
            for (var feature in layer.features) {
              appLogger.info('Processing feature of type: ${feature.type}');
              // 这里可以处理每个 feature，例如检查点、路径等
              if (feature.hasPoints) {
                appLogger.info('Feature has ${feature.points.length} points.');
              } else if (feature.hasPaths) {
                appLogger.info(
                    'Feature has paths with ${feature.paths.length} segments.');
              }
            }
          }
        });
      } else {
        appLogger.warning('Tileset contains no tiles for tile: $requestedTile');
      }

      final size = tileSize * _scale;
      final tileSizer = GridTileSizer(translation, _scale, Size.square(size));

      final rect = Rect.fromLTRB(0, 0, size, size);

      if (cancelled()) {
        throw CancellationException();
      }

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, rect);
      canvas.clipRect(rect);
      double zoomScaleFactor;
      if (tileSizer.effectiveScale == 1.0) {
        canvas.scale(_scale, _scale);
        zoomScaleFactor = _scale;
      } else {
        tileSizer.apply(canvas);
        zoomScaleFactor = tileSizer.effectiveScale / _scale;
      }
      final tileClip =
          tileSizer.tileClip(Size.square(size), tileSizer.effectiveScale);

      final tile = TileSource(
          tileset: tileResponse.tileset!,
          rasterTileset: rasterTile,
          spriteAtlas: spriteAtlas,
          spriteIndex: _sprites?.index);
      Renderer(theme: _theme).render(canvas, tile,
          zoomScaleFactor: zoomScaleFactor,
          zoom: requestedTile.z.toDouble(),
          rotation: 0.0,
          clip: tileClip);

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      await _cache(translation.original, image);
      appLogger.info('Rendering completed for tile: $requestedTile');
      return ImageInfo(image: image, scale: _scale);
    } catch (e) {
      appLogger.severe('Error while rendering tile: $requestedTile, error: $e');
      rethrow;
    } finally {
      rasterTile.dispose();
    }
  }

  Future<void> _cache(TileIdentity tile, Image image) async {
    Image cloned = image.clone();
    try {
      await _imageCache.put(tile, cloned);
    } catch (_) {
      // nothing to do
    } finally {
      cloned.dispose();
    }
  }
}

class _TileJob {
  final TileIdentity requestedTile;
  final int requestZoom;
  final double tileSize;
  final bool Function() cancelled;

  _TileJob(this.requestedTile, this.requestZoom, this.tileSize, this.cancelled);
}

int _maxOutstandingJobs = 100;
