# mbtiles

Mapbox MBTiles v1.3 files, support for vector and raster tiles.

- Supported raster tiles: `jpg`, `png`, `webp`
- Supported vector tiles: `pbf`
- Web is not supported because of its missing support for SQLite.

[![Pub Version](https://img.shields.io/pub/v/mbtiles)](https://pub.dev/packages/mbtiles)
[![likes](https://img.shields.io/pub/likes/mbtiles?logo=flutter)](https://pub.dev/packages/mbtiles)
[![Pub Points](https://img.shields.io/pub/points/mbtiles)](https://pub.dev/packages/mbtiles/score)
[![Pub Popularity](https://img.shields.io/pub/popularity/mbtiles)](https://pub.dev/packages/mbtiles)

[![GitHub last commit](https://img.shields.io/github/last-commit/josxha/dart_mbtiles)](https://github.com/josxha/dart_mbtiles)
[![stars](https://badgen.net/github/stars/josxha/dart_mbtiles?label=stars&color=green&icon=github)](https://github.com/josxha/dart_mbtiles/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/josxha/dart_mbtiles)](https://github.com/josxha/dart_mbtiles/issues)
[![codecov](https://codecov.io/gh/josxha/dart_mbtiles/graph/badge.svg?token=RGB99KA1GJ)](https://codecov.io/gh/josxha/dart_mbtiles)

## Getting started

#### pubspec.yaml

```yaml
dependencies:
  # this package:
  mbtiles: ^0.4.0
  # coordinates will be returned as `LatLng`, include the following package 
  # if you want to work with them.
  latlong2: ^0.9.0
  # sqlite libraries (in case not otherwise bundled)
  sqlite3_flutter_libs: ^0.5.18
```

## Usage

This package has by design no flutter dependency to be able to use it in
dart programs. Please refer to the [flutter instructions](#flutter) if you want
to use it in a flutter app and [dart-only instructions](#dart-only) to use it in
pure dart.

### flutter

1. Ensure that you have added the `sqlite3_flutter_libs` package as a dependency
   if you don't provide the sqlite3 libraries otherwise.
2. Open your .mbtiles file.
    - It is recommended to store the mbtiles file in one of the directories
      provided by [path_provider](https://pub.dev/packages/path_provider).
    - The mbtiles file cannot be opened if it is inside your flutter assets!
      Copy it to your file system first.
    - If you want to open the file from the internal device storage or SD card,
      you need to ask for permission first! You can
      use [permission_handler](https://pub.dev/packages/permission_handler) to
      request the needed permission from the user.

```dart
// open as read-only
final mbtiles = MBTiles(
   mbtilesPath: 'path/to/your/mbtiles-file.mbtiles',
);
// open as writeable database
final mbtiles = MBTiles(
   mbtilesPath: 'path/to/your/file.mbtiles',
   editable: true,
);
```

3. Afterward you can request tiles, read the metadata, etc.

```dart
// get metadata
final metadata = mbtiles.getMetadata();
// get tile data
final tile = mbtiles.getTile(z: 0, x: 0, y: 0);
```

4. After you don't need the mbtiles file anymore, close its sqlite database
   connection.

```dart
void closeMbTiles() {
  mbtiles.dispose();
}
```

### dart-only

1. Open the mbtiles database.
   You need to provide the dart program with platform specific sqlite3
   libraries.
   Builds are available
   on [www.sqlite.org](https://www.sqlite.org/download.html)

```dart

final mbtiles = MBTiles(
  mbtilesPath: 'path/to/your/mbtiles-file.mbtiles',
  sqlitePath: 'path/to/sqlite3',
);
```

2. Afterward you can request tiles, read the metadata, etc.

```dart
// get metadata
final metadata = mbtiles.getMetadata();
// get tile data
final tile = mbtiles.getTile(z: 0, x: 0, y: 0);
```

3. After you don't need the mbtiles file anymore, close its sqlite database
   connection.

```dart
void closeMbTiles() {
  mbtiles.dispose();
}
```

See the [example program](https://pub.dev/packages/mbtiles/example) for more
information.

## Additional information

- [MBTiles specification](https://github.com/mapbox/mbtiles-spec)
- [Read about MBTiles in the OpenStreetMap Wiki](https://wiki.openstreetmap.org/wiki/MBTiles)