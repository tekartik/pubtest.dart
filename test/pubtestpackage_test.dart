@TestOn("vm")
library tekartik_pub.test.pub_test;

import 'dart:io';

import 'package:dev_test/test.dart';
import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubtest/src/pubtest_version.dart';

var longTimeout = new Timeout(new Duration(minutes: 2));

String get pubTestPackageDartScript =>
    normalize(absolute(join('bin', 'pubtestpackage.dart')));

void main() {
  //useVMConfiguration();

  checkErrorExitCode(result) {
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
      ProcessResult result =
          await runCmd(dartCmd([pubTestPackageDartScript, '--version']));
      expect(result.stdout, contains("pubtest"));
      expect(new Version.parse((result.stdout as String).split(' ').last),
          version);
    });

    group('path', () {
      test('success', () async {
        ProcessResult result = await runCmd(dartCmd([
          pubTestPackageDartScript,
          '-spath',
          '.',
          '-p',
          'vm',
          'test/data/success_test_.dart'
        ]));

        // on 1.13, current windows is failing
        if (!Platform.isWindows) {
          expect(result.exitCode, 0);
        }
        expect(result.stdout.contains("All tests passed"), isTrue);
      });

      test('failure', () async {
        ProcessResult result = await runCmd(dartCmd([
          pubTestPackageDartScript,
          '-spath',
          '.'
              '-p',
          'vm',
          'test/data/fail_test_.dart'
        ])); // ..connectStderr=true..connectStdout=true);
        checkErrorExitCode(result);
      });
    });

    group('git', () {
      test('success', () async {
        ProcessResult result = await runCmd(dartCmd([
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

        expect(result.stdout.contains("All tests passed"), isTrue);
      }, timeout: longTimeout);

      test('failure', () async {
        ProcessResult result = await runCmd(dartCmd([
          pubTestPackageDartScript,
          '-sgit',
          'https://github.com/tekartik/pubtest.dart'
              '-p',
          'vm',
          '--get-offline',
          'test/data/fail_test_.dart'
        ])); // ..connectStderr=true..connectStdout=true);
        checkErrorExitCode(result);
      }, timeout: longTimeout);
    });
  });
}
