import 'dart:io';

import 'package:ffigen/ffigen.dart';

void main() {
  final packageRoot = Platform.script.resolve('../');

  FfiGenerator(
    enums: .includeAll,
    functions: .includeAll,
    globals: .includeAll,
    macros: .includeAll,
    typedefs: .includeAll,
    structs: .includeAll,
    unnamedEnums: .includeAll,
    unions: .includeAll,
    output: Output(
      style: const DynamicLibraryBindings(),
      dartFile: packageRoot.resolve('lib/gen/generated_bindings.dart'),
    ),
    headers: Headers(
      compilerOptions: [
        //TODO: figure out a better way to handle this
        if (!Platform.isLinux) ...[
          '-include',
          'stdbool.h',
          '-I${packageRoot.resolve('third_party/vivox').path.substring(1)}',
          ]
      ],
      entryPoints: [
        if (!Platform.isLinux) 
          packageRoot.resolve(
            'third_party/vivox/ffigen_vivox_shim.h',
          ),
        packageRoot.resolve('third_party/unrar.h'),
      ],
    ),
  ).generate();
}
