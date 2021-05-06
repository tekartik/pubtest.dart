@TestOn('vm')
library tekartik_pub.test.pub_test;

import 'dart:io';

import 'package:dev_test/test.dart';
import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart' hide run;
import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:tekartik_pubtest/src/pubtest_version.dart';

import 'pubtest_test.dart';

var longTimeout = const Timeout(Duration(minutes: 2));

String get pubTestPackageDartScript =>
    normalize(absolute(join(exampleBinPath, 'pubtestpackage.dart')));

void main() {
  //useVMConfiguration();

  void checkErrorExitCode(ProcessResult result) {
    if (!Platform.isWindows) {
      try {
        expect(result.exitCode, 1);
      } catch (_) {
        expect(result.exitCode, 255);
      }
    }
  }

  group('pubtestpackage', () {
    test('version', () async {
      final result =
          await runCmd(DartCmd([pubTestPackageDartScript, '--version']));
      expect(result.stdout, contains('pubtest'));
      expect(Version.parse((result.stdout as String).split(' ').last), version);
    });

    group('path', () {
      test('success', () async {
        final result = (await run('dart run $pubTestPackageDartScript'
                ' -spath . -p vm test/data/success_test_.dart'))
            .first;

        // on 1.13, current windows is failing
        if (!Platform.isWindows) {
          expect(result.exitCode, 0);
        }
        expect(result.outText.contains('All tests passed'), isTrue,
            reason: result.outText);
      });

      test('failure', () async {
        final result = await runCmd(DartCmd([
          pubTestPackageDartScript,
          '-spath',
          '.',
          '-p',
          'vm',
          'test/data/fail_test_.dart'
        ])); // ..connectStderr=true..connectStdout=true);
        checkErrorExitCode(result);
      });
    });

    group('git', () {
      test('success', () async {
        final result = await runCmd(DartCmd([
          pubTestPackageDartScript,
          '-sgit',
          'https://github.com/tekartik/pubtest.dart',
          '--get-offline',
          '-p',
          'vm',
          'test/data/success_test_.dart'
        ]));

        // on 1.13, current windows is failing
        if (!Platform.isWindows) {
          expect(result.exitCode, 0);
        }

        expect(result.outText.contains('All tests passed'), isTrue);
      }, timeout: longTimeout);

      test('failure', () async {
        final result = await runCmd(DartCmd([
          pubTestPackageDartScript,
          '-sgit',
          'https://github.com/tekartik/pubtest.dart',
          '-p',
          'vm',
          '--get-offline',
          'test/data/fail_test_.dart'
        ])); // ..connectStderr=true..connectStdout=true);
        checkErrorExitCode(result);
      }, timeout: longTimeout);
    }, skip: true); // URL points to dart1
  });
}
