@TestOn("vm")
library tekartik_pub.test.pub_test;

import 'dart:io' as io;

import 'package:dev_test/test.dart';
import 'package:fs_shim_test/test_io.dart';
import 'package:process_run/cmd_run.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubtest/src/pubtest_version.dart';

class TestScript extends Script {}

Directory get pkgDir =>
    new File(getScriptPath(TestScript)).parent.parent as Directory;

void main() => defineTests(newIoFileSystemContext(
    io.Directory.systemTemp.createTempSync('pubtest_test_').path));

String get pubTestPackageDartScript {
  return join(pkgDir.path, 'bin', 'pubtestpackage.dart');
}

void defineTests(FileSystemTestContext ctx) {
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
      });

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
      });
    });
  });
}
