import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:wren_dart/src/enums.dart';
import './generated_bindings.dart';

final FFI_NULL_PTR = Pointer.fromAddress(0);
late WrenBindings g_Bindings;
void loadWrenLib(DynamicLibrary lib) {
  g_Bindings = WrenBindings(lib);
}

typedef ManagedLoadModuleSourceFn = String? Function(DWrenVM dwvm, String name);
typedef ExternalDartFunctionResolverFn = WrenForeignMethodFn? Function(
    String moduleName, String className, String signiture);

class Configuration {
  ManagedLoadModuleSourceFn? managedloadModuleSourceFn;
  WrenWriteFn? writeFn;
  WrenErrorFn? errFn;

  Configuration({
    this.writeFn,
    this.errFn,
    this.managedloadModuleSourceFn,
  });
}

class DWrenVM {
  late Pointer<WrenVM> _ptrVm;
  Map<String, Pointer> _moduleLoadRespCache = {};

  ManagedLoadModuleSourceFn? _loadModuleSourceFn = null;
  List<ExternalDartFunctionResolverFn> _resolverList = [];

  DWrenVM(Configuration config) {
    var wrenConfig = calloc<WrenConfiguration>();
    g_Bindings.wrenInitConfiguration(wrenConfig);
    if (config.writeFn != null) {
      wrenConfig.ref.writeFn = config.writeFn!;
    }
    if (config.errFn != null) {
      wrenConfig.ref.errorFn = config.errFn!;
    }

    if (config.managedloadModuleSourceFn != null) {
      _loadModuleSourceFn = config.managedloadModuleSourceFn!;
    }
    wrenConfig.ref.loadModuleFn =
        Pointer.fromFunction(DWrenVM._managedLoadModule);

    wrenConfig.ref.bindForeignMethodFn =
        Pointer.fromFunction(DWrenVM._bindExternalFunc);

    _ptrVm = g_Bindings.wrenNewVM(wrenConfig);

    _instanceList[_ptrVm] = this;
    // safe to free config
    calloc.free(wrenConfig);
  }

  /// Runs [source], a string of Wren source code in a new fiber in this VM in the
  /// context of resolved [moduleName].
  int interpret(String moduleName, String source) {
    return g_Bindings.wrenInterpret(
        _ptrVm, moduleName.toNativeUtf8().cast(), source.toNativeUtf8().cast());
  }

  /// Frees the memory used by the VM. It shouldn't be used after this
  void free() {
    _instanceList.remove(_ptrVm);
    g_Bindings.wrenFreeVM(_ptrVm);
  }

  /// Immediately run the garbage collector to free unused memory.
  void collectGarbage() {
    g_Bindings.wrenCollectGarbage(_ptrVm);
  }

  ///Ensures that the foreign method stack has at least [numSlots] available for
  /// use, growing the stack if needed.
  ///
  /// Does not shrink the stack if it has more than enough slots.
  ///
  /// It is an error to call this from a finalizer.
  void ensureSlots(int numSlots) {
    g_Bindings.wrenEnsureSlots(_ptrVm, numSlots);
  }

  /// Returns the number of slots available to the current foreign method.
  int get slotCount => g_Bindings.wrenGetSlotCount(_ptrVm);

  /// Stores the [T] (double, bool or String) typed [value] in slot [index].
  void setSlot<T>(int index, T value) {
    if (T == double) {
      g_Bindings.wrenSetSlotDouble(_ptrVm, index, value as double);
    } else if (T == bool) {
      g_Bindings.wrenSetSlotBool(_ptrVm, index, value as bool);
    } else if (T == String) {
      g_Bindings.wrenSetSlotBytes(
          _ptrVm, index, (value as String).toNativeUtf8().cast(), value.length);
    } else {
      throw ArgumentError('Invalid type for setSlot');
    }
  }

  /// Sets the slot at [index] to null
  void setSlotNull(int index) {
    g_Bindings.wrenSetSlotNull(_ptrVm, index);
  }

  /// Stores a new empty list at [index].
  void setSlotNewList(int index) {
    g_Bindings.wrenSetSlotNewList(_ptrVm, index);
  }

  /// Stores a new empty map at [index].
  void setSlotNewMap(int index) {
    g_Bindings.wrenSetSlotNewMap(_ptrVm, index);
  }

  /// Gets the type of the slot at [index]
  WType getSlotType(int index) {
    return WType.values[g_Bindings.wrenGetSlotType(_ptrVm, index)];
  }

  /// Gets the value of the slot at [index] as a [T] (double, bool or String)
  T getSlot<T>(int index) {
    if (T == double) {
      if (getSlotType(index) != WType.number) {
        throw TypeError();
      }
      return g_Bindings.wrenGetSlotDouble(_ptrVm, index) as T;
    } else if (T == bool) {
      if (getSlotType(index) != WType.boolean) {
        throw TypeError();
      }
      return g_Bindings.wrenGetSlotBool(_ptrVm, index) as T;
    } else if (T == String) {
      if (getSlotType(index) != WType.string) {
        throw TypeError();
      }
      return g_Bindings
          .wrenGetSlotString(_ptrVm, index)
          .cast<Utf8>()
          .toDartString() as T;
    } else {
      throw ArgumentError('Invalid type for getSlot');
    }
  }

  /// Looks up the top level variable with [name] in resolved [module] and stores
  /// it in [variableOutSlot].
  void getVariable(String module, String name, int variableOutSlot) {
    g_Bindings.wrenGetVariable(_ptrVm, module.toNativeUtf8().cast(),
        name.toNativeUtf8().cast(), variableOutSlot);
  }

  void bindResolver(ExternalDartFunctionResolverFn r) {
    if (!_resolverList.contains(r)) {
      _resolverList.add(r);
    }
  }

  static Map<Pointer<WrenVM>, DWrenVM> _instanceList = {};
  static DWrenVM? fromPtr(Pointer<WrenVM> ptr) {
    if (_instanceList.containsKey(ptr)) {
      return _instanceList[ptr];
    }
    return null;
  }

  static WrenLoadModuleResult _managedLoadModule(
      Pointer<WrenVM> vm, Pointer<Char> name) {
    var dwvm = DWrenVM.fromPtr(vm)!;
    var mName = name.cast<Utf8>().toDartString();
    var out = calloc<WrenLoadModuleResult>();
    dwvm._moduleLoadRespCache[mName] = out;

    if (dwvm._loadModuleSourceFn != null) {
      var src = dwvm._loadModuleSourceFn!(dwvm, mName);
      if (src != null) {
        out.ref.source = src.toNativeUtf8().cast();
        out.ref.onComplete =
            Pointer.fromFunction(DWrenVM._managedLoadModuleCompleted);
      }
    }

    return out.ref;
  }

  static void _managedLoadModuleCompleted(
      Pointer<WrenVM> vm, Pointer<Char> name, WrenLoadModuleResult result) {
    var dwvm = DWrenVM.fromPtr(vm)!;
    var dstrname = name.cast<Utf8>().toDartString();

    // free src first
    calloc.free(result.source);
    // free result struct
    calloc.free(dwvm._moduleLoadRespCache[dstrname]!);
    dwvm._moduleLoadRespCache.remove(dstrname);
  }

  static WrenForeignMethodFn _bindExternalFunc(
      Pointer<WrenVM> vm,
      Pointer<Char> module,
      Pointer<Char> className,
      bool isStatic,
      Pointer<Char> signature) {
    var dwvm = DWrenVM.fromPtr(vm)!;
    var dart_moduleName = module.cast<Utf8>().toDartString();
    var dart_className = className.cast<Utf8>().toDartString();
    var dart_signature = signature.cast<Utf8>().toDartString();

    for (var reolver in dwvm._resolverList) {
      var out = reolver(dart_moduleName, dart_className, dart_signature);
      if (out != null && out.address != 0) return out;
    }

    return FFI_NULL_PTR.cast();
  }
}
