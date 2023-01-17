import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

extension Uint8Pointer on Pointer<Uint8> {
  Uint8List toList(int length) {
    final builder = BytesBuilder();
    for (var i = 0; i < length; i++) {
      builder.addByte(this[i]);
    }
    return builder.takeBytes();
  }
}

extension Uint8ListExtensions on Uint8List {
  Pointer<Uint8> toPointer({int? size}) {
    final p = calloc<Uint8>(size ?? length);
    p.asTypedList(size ?? length).setAll(0, this);
    return p;
  }
}
