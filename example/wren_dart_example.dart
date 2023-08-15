import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:wren_dart/wren_dart.dart';
import 'package:path/path.dart' as path;
import 'package:ffi/ffi.dart';

void wrError(ffi.Pointer<WrenVM> vm, int type, ffi.Pointer<ffi.Char> module,
    int line, ffi.Pointer<ffi.Char> message) {
  stderr.write("==========WREN ERR=========\n");
  stderr.write(message.cast<Utf8>().toDartString() + "\n");
  stderr.write("line " + line.toString() + "\n");
}

void wrWrite(ffi.Pointer<WrenVM> vm, ffi.Pointer<ffi.Char> string) {
  print("==========WREN=========");
  print(string.cast<Utf8>().toDartString());
  print("=======================");
}

void main(List<String> args) {
  var libraryPath =
      path.join(Directory.current.path, 'bin', 'wren', 'libwren.so');
  if (Platform.isMacOS) {
    libraryPath =
        path.join(Directory.current.path, 'bin', 'wren', 'libwren.dylib');
  }
  if (Platform.isWindows) {
    libraryPath =
        path.join(Directory.current.path, 'bin', 'wren', 'wren_d.dll');
  }

  var vm = VM(
      ffi.DynamicLibrary.open(libraryPath),
      Configuration(
          writeFn: ffi.Pointer.fromFunction(wrWrite),
          errFn: ffi.Pointer.fromFunction(wrError)));

  var testScriptPath =
      path.join(Directory.current.path, 'example', 'wren_test.wren');
  File testScript = File(testScriptPath);

  vm.interpret('test', testScript.readAsStringSync());

  vm.free();
}
