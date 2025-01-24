import 'dart:typed_data';

import 'package:archive/archive.dart' as archive; // 用于gzip编码和解码
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// 扩展Uint8List，提供gzip编码和解码的方法
extension U8intListExtension on Uint8List {
  Uint8List gzipEncode() {
    final encoder = archive.GZipEncoder();
    final result = encoder.encode(this);
    return Uint8List.fromList(result ?? []); // 处理null值
  }

  Uint8List gzipDecode() {
    final decoder = archive.GZipDecoder();
    return Uint8List.fromList(decoder.decodeBytes(this));
  }
}

/// SqLite3类，使用sqflite库
class SqLite3 {
  const SqLite3();

  Future<Database> open(String mbtilesPath, {required int mode}) async {
    final String path = join(await getDatabasesPath(), mbtilesPath);
    return openDatabase(path, version: 1, onCreate: (db, version) {
      // 在这里创建表
    },);
  }
}
