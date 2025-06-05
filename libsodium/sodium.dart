// Copyright 2020 First Floor Software. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//    * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//    * Neither the name of First Floor Software nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import 'bindings/libsodium_bindings.dart';

import 'dart:ffi';
import "package:ffi/ffi.dart";
import 'dart:typed_data';

import '../extensions.dart';

class Sodium {
  static final _bindings = LibsodiumBindings();

  static int get cryptoBoxSealbytes => _bindings.crypto_box_sealbytes();
  static int get cryptoScalarmultCurve25519Bytes =>
      _bindings.crypto_scalarmult_curve25519_bytes();

  Uint8List cryptoSignEd25519PkToCurve25519(Uint8List ed25519Pk) {
    final _curve25519Pk = calloc<Uint8>(cryptoScalarmultCurve25519Bytes);
    final _ed25519Pk = ed25519Pk.toPointer();

    try {
      _bindings.crypto_sign_ed25519_pk_to_curve25519(_curve25519Pk, _ed25519Pk);
      return _curve25519Pk.toList(cryptoScalarmultCurve25519Bytes);
    } finally {
      calloc.free(_curve25519Pk);
      calloc.free(_ed25519Pk);
    }
  }

  Uint8List cryptoSignEd25519SkToCurve25519(Uint8List ed25519Sk) {
    final _curve25519Pk = calloc<Uint8>(cryptoScalarmultCurve25519Bytes);
    final _ed25519Sk = ed25519Sk.toPointer();

    try {
      _bindings.crypto_sign_ed25519_sk_to_curve25519(_curve25519Pk, _ed25519Sk);
      return _curve25519Pk.toList(cryptoScalarmultCurve25519Bytes);
    } finally {
      calloc.free(_curve25519Pk);
      calloc.free(_ed25519Sk);
    }
  }

  Uint8List cryptoBoxSeal(Uint8List m, Uint8List pk) {
    final _c = calloc<Uint8>(m.length + cryptoBoxSealbytes);
    final _m = m.toPointer();
    final _pk = pk.toPointer();

    try {
      _bindings.crypto_box_seal(_c, _m, m.length, _pk);
      return _c.toList(m.length + cryptoBoxSealbytes);
    } finally {
      calloc.free(_c);
      calloc.free(_m);
      calloc.free(_pk);
    }
  }

  Uint8List cryptoBoxSealOpen(Uint8List c, Uint8List pk, Uint8List sk) {
    final _m = calloc<Uint8>(c.length - cryptoBoxSealbytes);
    final _c = c.toPointer();
    final _pk = pk.toPointer();
    final _sk = sk.toPointer();

    try {
      _bindings.crypto_box_seal_open(_m, _c, c.length, _pk, _sk);
      return _m.toList(c.length - cryptoBoxSealbytes);
    } finally {
      calloc.free(_m);
      calloc.free(_c);
      calloc.free(_pk);
      calloc.free(_sk);
    }
  }
}
