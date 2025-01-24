import 'dart:async';
import 'package:latlong2/latlong.dart';
import 'package:mbtiles/src/model/mbtiles_metadata.dart';
import 'package:sqflite/sqflite.dart';

class MetadataRepository {
  final Database database;

  const MetadataRepository({required this.database});

  Future<MbTilesMetadata> getAll() async {
    final List<Map<String, dynamic>> rows = await database.query('metadata');
    final map = <String, String>{};
    for (final row in rows) {
      final name = row['name'] as String;
      final value = row['value'] as String;
      map[name] = value;
    }

    assert(
      map.containsKey('name'),
      'Invalid metadata table: The table must contain a name row.',
    );
    assert(
      map.containsKey('format'),
      'Invalid metadata table: The table must contain a format row.',
    );

    // tile layer bounds
    MbTilesBounds? bounds;
    if (map['bounds']?.split(',') case [
          final left,
          final bottom,
          final right,
          final top,
        ]) {
      bounds = MbTilesBounds(
        left: double.parse(left),
        bottom: double.parse(bottom),
        right: double.parse(right),
        top: double.parse(top),
      );
    }

    // default tile layer center and zoom level
    LatLng? center;
    double? zoom;
    if (map['center']?.split(',') case [final long, final lat, final z]) {
      center = LatLng(double.parse(lat), double.parse(long));
      zoom = double.parse(z);
    }

    return MbTilesMetadata(
      name: map['name']!,
      format: map['format']!,
      type: _parseTileLayerType(map['type']),
      bounds: bounds,
      attributionHtml: map['attribution'],
      defaultCenter: center,
      defaultZoom: zoom,
      description: map['description'],
      json: map['json'],
      maxZoom: map['maxzoom'] == null ? null : double.parse(map['maxzoom']!),
      minZoom: map['minzoom'] == null ? null : double.parse(map['minzoom']!),
      version: map['version'] == null ? null : double.parse(map['version']!),
    );
  }

  TileLayerType? _parseTileLayerType(String? raw) => switch (raw) {
        'baselayer' => TileLayerType.baseLayer,
        'overlay' => TileLayerType.overlay,
        null => null,
        _ => throw Exception(
            'The MBTiles file contains an unsupported tile layer type: $raw',
          ),
      };

  Future<void> createTable() async {
    await database.execute('''
      CREATE TABLE metadata (name TEXT PRIMARY KEY, value TEXT);
    ''');
  }

  Future<void> putAll(MbTilesMetadata metadata) async {
    assert(
      metadata.defaultCenter == null && metadata.defaultZoom == null ||
          metadata.defaultCenter != null && metadata.defaultZoom != null,
      'Default center and zoom need to be both set if one is set.',
    );

    final batch = database.batch();
    batch.insert('metadata', {'name': 'name', 'value': metadata.name}, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('metadata', {'name': 'format', 'value': metadata.format}, conflictAlgorithm: ConflictAlgorithm.replace);
    
    if (metadata.bounds != null) {
      batch.insert('metadata', {
        'name': 'bounds',
        'value': '${metadata.bounds!.left},${metadata.bounds!.bottom},${metadata.bounds!.right},${metadata.bounds!.top}',
      }, conflictAlgorithm: ConflictAlgorithm.replace,);
    }
    
    if (metadata.type != null) {
      batch.insert('metadata', {'name': 'type', 'value': metadata.type!.name}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    
    if (metadata.defaultZoom != null && metadata.defaultCenter != null) {
      batch.insert('metadata', {
        'name': 'center',
        'value': '${metadata.defaultCenter!.longitude},${metadata.defaultCenter!.latitude},${metadata.defaultZoom}',
      }, conflictAlgorithm: ConflictAlgorithm.replace,);
    }
    
    if (metadata.attributionHtml != null) {
      batch.insert('metadata', {'name': 'attribution', 'value': metadata.attributionHtml}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    
    if (metadata.description != null) {
      batch.insert('metadata', {'name': 'description', 'value': metadata.description}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    
    if (metadata.json != null) {
      batch.insert('metadata', {'name': 'json', 'value': metadata.json}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    
    if (metadata.maxZoom != null) {
      batch.insert('metadata', {'name': 'maxzoom', 'value': metadata.maxZoom.toString()}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    
    if (metadata.minZoom != null) {
      batch.insert('metadata', {'name': 'minzoom', 'value': metadata.minZoom.toString()}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    
    if (metadata.version != null) {
      batch.insert('metadata', {'name': 'version', 'value': metadata.version.toString()}, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }
}
