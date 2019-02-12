#!/usr/bin/env dart
library tekartik_pubtest.bin.pbrtest;

import 'dart:io';

import 'package:process_run/cmd_run.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_io_utils/io_utils_import.dart';
import 'package:tekartik_pub/io.dart';
import 'package:tekartik_pubtest/bin/pubtest.dart';

export 'package:tekartik_io_utils/io_utils_import.dart';

class PbrTestApp extends App {
  @override
  String get commandText => 'pub run build_runner test';

  @override
  Future runTest(
      PubPackage pkg, List<String> args, CommonTestOptions testOptions) async {
    var testArgs = pubRunTestRunnerArgs(TestRunnerArgs(
        args: args,
        concurrency: testOptions.poolSize,
        reporter: testOptions.reporter,
        platforms: testOptions.platforms,
        name: testOptions.name));
    var pbrArgs = ['test', '--']..addAll(testArgs);
    ProcessCmd testCmd = pkg.pbrCmd(pbrArgs)..includeParentEnvironment = false;
    if (testOptions.dryRun) {
      print('\$ $testCmd');
    } else {
      ProcessResult result =
          await runCmd(testCmd, stdout: stdout, stderr: stderr);
      if (result.exitCode != 0) {
        stderr.writeln('test error in ${pkg}');
        if (exitCode == 0) {
          exitCode = result.exitCode;
        }
      }
    }
  }
}

///
/// Recursively update (pull) git folders
///
Future main(List<String> arguments) async {
  final app = PbrTestApp();
  return app.main(arguments);
}
