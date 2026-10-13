import 'dart:io';

import 'package:process_run/cmd_run.dart' hide runCmd;
import 'package:tekartik_pubtest/src/run_cmd.dart';

/// Used by pubtest_test: runs `dart --version` through runCmd, then a failing
/// command
Future<void> main() async {
  await runCmd(DartCmd(['--version']));
  try {
    await runCmd(DartCmd(['--no-such-dart-option']));
    stdout.writeln('no error');
  } catch (e) {
    stdout.writeln(e);
  }
}
