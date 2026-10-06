import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    await const RustBuilder(
      assetName: 'lib/gen/rust/frb_generated.dart',
      extraCargoEnvironmentVariables: {
        'CARGO_TARGET_AARCH64_APPLE_DARWIN_RUSTFLAGS': '-Clink-arg=-mmacosx-version-min=12.0',
        'CARGO_TARGET_X86_64_APPLE_DARWIN_RUSTFLAGS': '-Clink-arg=-mmacosx-version-min=12.0',
      },
    ).run(input: input, output: output);
  });
}
