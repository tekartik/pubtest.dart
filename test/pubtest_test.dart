@TestOn("vm")
library tekartik_pub.test.pub_test;

import 'dart:io' as io;

import 'package:dev_test/test.dart';
import 'package:fs_shim_test/test_io.dart';
import 'package:process_run/cmd_run.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubtest/src/pubtest_version.dart';
import 'package:tekartik_pub/io.dart';

class TestScript extends Script {}

Directory get pkgDir => new File(getScriptPath(TestScript)).parent.parent;

void main() => defineTests(newIoFileSystemContext(
    io.Directory.systemTemp.createTempSync('pubtest_test_').path));

String get pubTestDartScript {
  return join(pkgDir.path, 'bin', 'pubtest.dart');
}

void defineTests(FileSystemTestContext ctx) {
  //useVMConfiguration();
  group('pubtest', () {
    test('version', () async {
      ProcessResult result =
          await runCmd(dartCmd([pubTestDartScript, '--version']));
      expect(result.stdout, contains("pubtest"));
      expect(new Version.parse(result.stdout.split(' ').last), version);
    });

    test('success', () async {
      ProcessResult result = await runCmd(dartCmd(
          [pubTestDartScript, '-p', 'vm', 'test/data/success_test_.dart']));

      // on 1.13, current windows is failing
      if (!Platform.isWindows) {
        expect(result.exitCode, 0);
      }

      expect(result.stdout.contains("All tests passed"), isTrue);
    });

    test('failure', () async {
      ProcessResult result = await runCmd(dartCmd([
        pubTestDartScript,
        '-p',
        'vm',
        'test/data/fail_test_.dart'
      ])); // ..connectStderr=true..connectStdout=true);
      if (!Platform.isWindows) {
        expect(result.exitCode, 1);
      }
    });

    group('example', () {
      test('subdir', () async {
        Directory top = await ctx.prepare();

        Directory successDir = childDirectory(top, 'success');

        PubPackage exampleSuccessDir = new PubPackage(
            childDirectory(pkgDir, join('example', 'success')).path);
        PubPackage pkg = await exampleSuccessDir.clone(successDir.path);

        // Filter test having "success" in the data dir
        ProcessResult result = await runCmd(pkg.dartCmd([
          pubTestDartScript,
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

        // on 1.13, current windows is failing
        if (!Platform.isWindows) {
          expect(result.exitCode, 0);
        }
        //print(result.stdout);
        expect(pubRunTestJsonIsSuccess(result.stdout), isTrue);
        expect(pubRunTestJsonSuccessCount(result.stdout), 1);
        expect(pubRunTestJsonFailureCount(result.stdout), 0);

        // run one level above
        result = await runCmd(pkg.dartCmd([
          pubTestDartScript,
          '-p',
          'vm',
          '${top.path}',
          '-n',
          'success',
          '-r',
          'json',
          '--get',
          //'--dry-run', // dry run
        ]));

        //print(result.stdout);
        //print(result.stderr);
        // on 1.13, current windows is failing
        if (!Platform.isWindows) {
          expect(result.exitCode, 0);
        }
        expect(pubRunTestJsonIsSuccess(result.stdout), isTrue);
        //expect(pubRunTestJsonProcessResultSuccessCount(result), 1);
        //expect(pubRunTestJsonProcessResultFailureCount(result), 0);
      });
    });

    // expect
  });
}
