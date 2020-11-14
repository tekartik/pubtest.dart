@TestOn('vm')
library tekartik_pub.test.pub_test;

import 'dart:io';

import 'package:process_run/shell_run.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:test/test.dart';
import 'package:path/path.dart';

import 'package:process_run/cmd_run.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:tekartik_pubtest/src/pubtest_version.dart';
import 'package:tekartik_pub/io.dart';

var longTimeout = const Timeout(Duration(minutes: 2));
var exampleBinPath = join('example', 'bin');
String get _pubTestDartScript =>
    normalize(absolute(join(exampleBinPath, 'pubtest.dart')));

void main() {
  group('pubtest', () {
    run(_pubTestDartScript);
  });
}

String getReason(ProcessResult result) {
  return 'OUT:\n${result.stdout}\nERR:\n${{result.stderr}}';
}

void run(String script) {
  // we use a prefix, needed since this can be called during pubtest_test and pbrtest_test
  var prefix = basenameWithoutExtension(script);
  test('version', () async {
    final result = await runCmd(DartCmd([script, '--version']));
    expect(result.stdout, contains(basenameWithoutExtension(script)));
    expect(Version.parse((result.stdout as String).split(' ').last), version);
  });

  test('success1', () async {
    var testPath = join('test', 'data', 'success_test_.dart');
    try {
      final result = await runCmd(DartCmd([script, '-p', 'vm', testPath]));

      // on 1.13, current windows is failing
      if (!Platform.isWindows) {
        expect(result.exitCode, 0, reason: result.stderr?.toString());
      }

      //expect(result.stdout.contains('All tests passed'), isTrue, reason: getReason(result));
    } finally {}
  }, timeout: longTimeout);

  test('success2', () async {
    var testPath = join('test', 'data', '${prefix}_success_test.dart');
    try {
      await File(join('test', 'data', 'success_test_.dart')).copy(testPath);

      var result = await runCmd(DartCmd([script, '-p', 'vm', testPath]));
      // devPrint('reason: ${getReason(result)}');
      result =
          (await Shell(verbose: true).run('pub run test -j 10 -p vm $testPath'))
              .first;

      // on 1.13, current windows is failing
      if (!Platform.isWindows) {
        expect(result.exitCode, 0, reason: result.stderr?.toString());
      }

      // No longer sent when executed like this
      await Shell(verbose: true)
          .run('pub run test -j 10 -p vm test/data/success_test_.dart');
      // expect(result.stdout.contains('All tests passed'), isTrue, reason: getReason(result));
    } finally {
      // cleanup
      try {
        await File(testPath).delete();
      } catch (_) {}
    }
  }, timeout: longTimeout);

  test('failure', () async {
    var testPath = join('test', 'data', '${prefix}_fail_test.dart');
    try {
      await File(join('test', 'data', 'fail_test_.dart')).copy(testPath);
      final result = await runCmd(DartCmd([
        script,
        '-p',
        'vm',
        testPath
      ])); // ..connectStderr=true..connectStdout=true);
      if (!Platform.isWindows) {
        expect(result.exitCode, 255);
      }
    } finally {
      // cleanup
      try {
        await File(testPath).delete();
      } catch (_) {}
    }
  }, timeout: longTimeout);

  group('example', () {
    test('subdir', () async {
      final top = (await Directory.systemTemp.createTemp()).path;

      final exampleSuccessDir = PubPackage(join('example', 'success'));
      final pkg = await exampleSuccessDir.clone(join(top, 'success'));

      // Filter test having 'success' in the data dir
      var result = await runCmd(pkg.dartCmd([
        script,
        '-p',
        'vm',
        '${pkg.dir.path}',
        '-n',
        'success',
        '-r',
        'json',
        // '--get-offline' - this is causin an error
        '--get'
      ]));
      result = await Shell(verbose: true).runExecutableArguments('dart', [
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
        script,
        '-p',
        'vm',
        '${top}',
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
