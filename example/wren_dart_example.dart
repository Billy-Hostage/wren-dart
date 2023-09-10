import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:wren_dart/wren_dart.dart';
import 'package:path/path.dart' as path;
import 'package:ffi/ffi.dart';

final FFI_NULL_PTR = ffi.Pointer.fromAddress(0);

// pass in two numbers (double)
void DMath_subAbs(ffi.Pointer<WrenVM> vm) {
  var dwVM = DWrenVM.fromPtr(vm)!;
  dwVM.ensureSlots(3);

  var l = dwVM.getSlot<double>(1);
  var r = dwVM.getSlot<double>(2);
  print("DMath_subAbs => abs(" + l.toString() + " - " + r.toString() + ")");
  dwVM.setSlot<double>(0, (l - r).abs());
}

WrenForeignMethodFn wrBindForeignMethodFn(
    ffi.Pointer<WrenVM> vm,
    ffi.Pointer<ffi.Char> module,
    ffi.Pointer<ffi.Char> className,
    bool isStatic,
    ffi.Pointer<ffi.Char> signature) {
  //var dart_moduleName = module.cast<Utf8>().toDartString();
  var dart_className = className.cast<Utf8>().toDartString();
  var dart_signature = signature.cast<Utf8>().toDartString();
  if (dart_className == "DMath") {
    if (dart_signature == "subAbs(_,_)") {
      return ffi.Pointer.fromFunction(DMath_subAbs);
    }
  }
  return FFI_NULL_PTR.cast();
}

void wrError(ffi.Pointer<WrenVM> vm, int type, ffi.Pointer<ffi.Char> module,
    int line, ffi.Pointer<ffi.Char> message) {
  stderr.write("==========WREN ERR TYPE " + type.toString() + " =========\n");
  stderr.write(message.cast<Utf8>().toDartString() + "\n");
  stderr.write("line " + line.toString() + "\n");
}

void wrWrite(ffi.Pointer<WrenVM> vm, ffi.Pointer<ffi.Char> string) {
  print("[WREN]" + string.cast<Utf8>().toDartString());
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
  loadWrenLib(ffi.DynamicLibrary.open(libraryPath));

  var vm = DWrenVM(Configuration(
    writeFn: ffi.Pointer.fromFunction(wrWrite),
    errFn: ffi.Pointer.fromFunction(wrError),
    bindForeignMethodFn: ffi.Pointer.fromFunction(wrBindForeignMethodFn),
  ));

  var testScriptPath =
      path.join(Directory.current.path, 'example', 'wren_test.wren');
  File testScript = File(testScriptPath);
  var test2ScriptPath =
      path.join(Directory.current.path, 'example', 'wren_call_to_outside.wren');
  File test2Script = File(test2ScriptPath);

  print("==TestBasic");
  vm.interpret("", testScript.readAsStringSync());

  // bind dart func to wren
  print("==TestOutcall");

  vm.interpret("", test2Script.readAsStringSync());

  vm.free();
}
