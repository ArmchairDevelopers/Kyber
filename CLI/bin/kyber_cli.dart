import 'dart:async';
import 'dart:io';

import 'package:kyber_cli/command_runner.dart';
import 'package:kyber_cli/gen/frb_generated.dart';
import 'package:sentry/sentry.dart';

Future<void> main(List<String> args) async {
  await RustLib.init();
  await runZonedGuarded(() async {
    await Sentry.init(
      (options) {
        options.dsn = 'https://8e5fc54af41e8c9041609b1b7302da7d@o4510921032859648.ingest.de.sentry.io/4512221111648336';
      },
    );

    await _flushThenExit(await KyberCliCommandRunner().run(args));
  }, (exception, stackTrace) async {
    await Sentry.captureException(exception, stackTrace: stackTrace);
    print('An error occurred. Please try again later.\n${exception.toString()}\n${stackTrace.toString()}');
    exit(1);
  });
}

Future<void> _flushThenExit(int status) {
  return Future.wait<void>([stdout.close(), stderr.close()]).then<void>((_) => exit(status));
}
