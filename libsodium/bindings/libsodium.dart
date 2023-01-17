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
import 'dart:io';

final libsodium = _load();

DynamicLibrary _load() {
  if (Platform.isMacOS) {
    // For Mac use Brew to install: brew install libsodium
    return DynamicLibrary.open('/usr/local/lib/libsodium.dylib');
  }

  if (Platform.isWindows) {
    // For Windows copy paste libsodium.dll into the program's folder.
    // Pre-built libraries: https://download.libsodium.org/libsodium/releases/
    return DynamicLibrary.open(Platform.script
        .resolve('/${Directory.current.path}/libsodium.dll')
        .toFilePath());
  }

  throw Exception('platform not supported');
}

// Extension helper for functions returning size_t
// this is a workaround for size_t not being properly supported in ffi. IntPtr
// almost works, but is sign extended.
extension Bindings on DynamicLibrary {
  int Function() lookupSizet(String symbolName) => sizeOf<IntPtr>() == 4
      ? this.lookup<NativeFunction<Uint32 Function()>>(symbolName).asFunction()
      : this.lookup<NativeFunction<Uint64 Function()>>(symbolName).asFunction();
}
