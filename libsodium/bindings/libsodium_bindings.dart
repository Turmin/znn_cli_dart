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

import 'dart:ffi';
import 'libsodium.dart';

class LibsodiumBindings {
  final int Function() crypto_box_sealbytes =
      libsodium.lookupSizet('crypto_box_sealbytes');

  final int Function() crypto_scalarmult_curve25519_bytes =
      libsodium.lookupSizet('crypto_scalarmult_curve25519_bytes');

  final int Function(
      Pointer<Uint8> curve25519_pk,
      Pointer<Uint8>
          ed25519_pk) crypto_sign_ed25519_pk_to_curve25519 = libsodium
      .lookup<NativeFunction<Int32 Function(Pointer<Uint8>, Pointer<Uint8>)>>(
          'crypto_sign_ed25519_pk_to_curve25519')
      .asFunction();

  final int Function(
      Pointer<Uint8> curve25519_sk,
      Pointer<Uint8>
          ed25519_sk) crypto_sign_ed25519_sk_to_curve25519 = libsodium
      .lookup<NativeFunction<Int32 Function(Pointer<Uint8>, Pointer<Uint8>)>>(
          'crypto_sign_ed25519_sk_to_curve25519')
      .asFunction();

  final int Function(
          Pointer<Uint8> c, Pointer<Uint8> m, int mlen, Pointer<Uint8> pk)
      crypto_box_seal = libsodium
          .lookup<
              NativeFunction<
                  Int32 Function(Pointer<Uint8>, Pointer<Uint8>, Uint64,
                      Pointer<Uint8>)>>('crypto_box_seal')
          .asFunction();

  final int Function(Pointer<Uint8> m, Pointer<Uint8> c, int clen,
          Pointer<Uint8> pk, Pointer<Uint8> sk) crypto_box_seal_open =
      libsodium
          .lookup<
              NativeFunction<
                  Int32 Function(Pointer<Uint8>, Pointer<Uint8>, Uint64,
                      Pointer<Uint8>, Pointer<Uint8>)>>('crypto_box_seal_open')
          .asFunction();
}
