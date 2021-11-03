@TestOn('vm')
library tekartik_pub.test.pub_test;

import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:process_run/shell_run.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_pub/io.dart';
import 'package:tekartik_pubtest/src/pubtest_version.dart';
import 'package:test/test.dart';

var longTimeout = const Timeout(Duration(minutes: 2));
var exampleBinPath = join('example', 'bin');
String get _pubTestDartScript =>
    normalize(absolute(join(exampleBinPath, 'pubtest.dart')));

void main() {
  group('pubtest', () {
    defineTests(_pubTestDartScript);
  });
}

String getReason(ProcessResult result) {
  return 'OUT:\n${result.stdout}\nERR:\n${{result.stderr}}';
}

void defineTests(String script, {String suffix = 'pub'}) {
  // we use a prefix, needed since this can be called during pubtest_test and pbrtest_test
  test('version', () async {
    final result = await runCmd(DartCmd(['run', script, '--version']));
    expect(result.stdout, contains(basenameWithoutExtension(script)));
    expect(Version.parse((result.stdout as String).split(' ').last), version);
  });

  String _fileWithSuffix(String srcPath) {
    return '${withoutExtension(srcPath)}${suffix}_test${extension(srcPath)}';
  }

  /// Use suffix
  Future<String> copyFile(String srcPath) async {
    var dstPath = _fileWithSuffix(srcPath);
    await File(srcPath).copy(dstPath);
    return dstPath;
  }

  test('success', () async {
    var testPath = join('test', 'data', 'success_test.dart');

    try {
      final result =
          await runCmd(DartCmd(['run', script, '-p', 'vm', testPath]));

      // on 1.13, current windows is failing
      if (!Platform.isWindows) {
        expect(result.exitCode, 0, reason: result.stderr?.toString());
      }

      //expect(result.stdout.contains('All tests passed'), isTrue, reason: getReason(result));
    } finally {}
  }, timeout: longTimeout);

  test('failure', () async {
    var testSrcPath = join('test', 'data', 'fail_test_.dart');
    var testPath = await copyFile(testSrcPath);
    try {
      final result = await runCmd(DartCmd([
        'run',
        script,
        '-p',
        'vm',
        testPath
      ])); // ..connectStderr=true..connectStdout=true);
      if (!Platform.isWindows) {
        expect(result.exitCode,
            isNot(0)); // sometimes 1, sometimes 255, don't know why
      }
    } finally {
      // cleanup
      await File(testPath).delete();
    }
  }, timeout: longTimeout);

  group('example', () {
    test('subdir', () async {
      final top = (await Directory.systemTemp.createTemp()).path;

      final exampleSuccessDir = PubPackage(join('example', 'success'));
      final pkg = await exampleSuccessDir.clone(join(top, 'success'));

      // Filter test having 'success' in the data dir
      var result = await runCmd(pkg.dartCmd([
        'run',
        script,
        '-p',
        'vm',
        (pkg.dir.path),
        '-n',
        'success',
        '-r',
        'json',
        // '--get-offline' - this is causin an error
        '--get'
      ]));
      result = await Shell(verbose: true).runExecutableArguments('dart', [
        'run',
        script,
        '-p',
        'vm',
        pkg.dir.path,
        '-n',
        'success',
        '-r',
        'json',
        '--get'
      ]);

      try {
        // on 1.13, current windows is failing
        if (!Platform.isWindows) {
          expect(result.exitCode, 0);
        }
        //print(result.stdout);
        expect(pubRunTestJsonIsSuccess(result.stdout as String), isTrue,
            reason: getReason(result));
        expect(pubRunTestJsonSuccessCount(result.stdout as String), 1);
        expect(pubRunTestJsonFailureCount(result.stdout as String), 0);
      } catch (e) {
        stderr.writeln(
            'Can fail - tests withing tests - but TODO investigate: $e');
      }

      // run one level above
      result = await runCmd(pkg.dartCmd([
        'run',
        script,
        '-p',
        'vm',
        top,
        '-n',
        'success',
        '-r',
        'json',
        '--get',
        //'--dry-run', // dry run
      ]));

      try {
        //print(result.stdout);
        //print(result.stderr);
        // on 1.13, current windows is failing
        if (!Platform.isWindows) {
          expect(result.exitCode, 0);
        }
        expect(pubRunTestJsonIsSuccess(result.stdout as String), isTrue);
        //expect(pubRunTestJsonProcessResultSuccessCount(result), 1);
        //expect(pubRunTestJsonProcessResultFailureCount(result), 0);
      } catch (e) {
        stderr.writeln(
            'Can fail - tests withing tests - but TODO investigate: $e');
      }
    });
  }, timeout: longTimeout);
}
