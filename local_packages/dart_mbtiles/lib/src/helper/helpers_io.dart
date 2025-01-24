import 'dart:typed_data';
import 'package:archive/archive.dart' as archive; // 用于gzip编码和解码

/// 扩展Uint8List，提供gzip编码和解码的方法
extension U8intListExtension on Uint8List {
  Uint8List gzipEncode() {
    final encoder = archive.GZipEncoder();
    final result = encoder.encode(this);
    return Uint8List.fromList(result ?? []); // 添加空值检查
  }

  Uint8List gzipDecode() {
    final decoder = archive.GZipDecoder();
    final result = decoder.decodeBytes(this);
    return Uint8List.fromList(result); // 不会返回null
  }
}
