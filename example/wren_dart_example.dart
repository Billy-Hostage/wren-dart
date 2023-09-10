import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:wren_dart/wren_dart.dart';
import 'package:path/path.dart' as path;
import 'package:ffi/ffi.dart';

// pass in two numbers (double)
void DMath_subAbs(ffi.Pointer<WrenVM> vm) {
  var dwVM = DWrenVM.fromPtr(vm)!;
  dwVM.ensureSlots(3);

  var l = dwVM.getSlot<double>(1);
  var r = dwVM.getSlot<double>(2);
  print("DMath_subAbs => abs(" + l.toString() + " - " + r.toString() + ")");
  dwVM.setSlot<double>(0, (l - r).abs());
}

void DMath_mulAbs(ffi.Pointer<WrenVM> vm) {
  var dwVM = DWrenVM.fromPtr(vm)!;
  dwVM.ensureSlots(3);

  var l = dwVM.getSlot<double>(1);
  var r = dwVM.getSlot<double>(2);
  print("DMath_mulAbs => abs(" + l.toString() + " * " + r.toString() + ")");
  dwVM.setSlot<double>(0, (l * r).abs());
}

WrenForeignMethodFn? DMath_resolver(
    String moduleName, String className, String signiture) {
  if (className != "DMath") return null;

  if (signiture == "subAbs(_,_)") return ffi.Pointer.fromFunction(DMath_subAbs);
  if (signiture == "mulAbs(_,_)") return ffi.Pointer.fromFunction(DMath_mulAbs);

  return null;
}

String? wrLoadModuleSrc(DWrenVM dwvm, String name) {
  var moduleFile =
      File(path.join(Directory.current.path, 'example', name + '.wren'));
  if (moduleFile.existsSync()) return moduleFile.readAsStringSync();
  return null;
}

void wrError(ffi.Pointer<WrenVM> vm, int type, ffi.Pointer<ffi.Char> module,
    int line, ffi.Pointer<ffi.Char> message) {
  stderr.write("[WREN][ERRROR][" +
      type.toString() +
      "] " +
      message.cast<Utf8>().toDartString() +
      "\n");
  stderr.write("\tline " + line.toString() + "\n");
}

void wrWrite(ffi.Pointer<WrenVM> vm, ffi.Pointer<ffi.Char> string) {
  print("[WREN][INFO]" + string.cast<Utf8>().toDartString());
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
    managedloadModuleSourceFn: wrLoadModuleSrc,
  ));

  var testScriptPath =
      path.join(Directory.current.path, 'example', 'wren_test.wren');
  File testScript = File(testScriptPath);
  var test2ScriptPath =
      path.join(Directory.current.path, 'example', 'wren_call_to_outside.wren');
  File test2Script = File(test2ScriptPath);

  print("==TestBasic");
  vm.interpret("Basic", testScript.readAsStringSync());

  // bind dart func to wren
  print("==TestOutcall");
  vm.bindResolver(DMath_resolver);
  vm.interpret("Outcall", test2Script.readAsStringSync());

  vm.free();
}
