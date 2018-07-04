@TestOn("vm")
library tekartik_pub.test.pub_test;

import 'dart:io';

import 'package:dev_test/test.dart';
import 'package:path/path.dart';

import 'package:process_run/cmd_run.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubtest/src/pubtest_version.dart';
import 'package:tekartik_pub/io.dart';

String get pubTestDartScript =>
    normalize(absolute(join('bin', 'pubtest.dart')));

void main() {
  group('pubtest', () {
    test('version', () async {
      ProcessResult result =
          await runCmd(dartCmd([pubTestDartScript, '--version']));
      expect(result.stdout, contains("pubtest"));
      expect(new Version.parse((result.stdout as String).split(' ').last),
          version);
    });

    test('success', () async {
      var testPath = join('test', 'data', 'success_test.dart');
      try {
        await new File(join('test', 'data', 'success_test_.dart'))
            .copy(testPath);

        ProcessResult result =
            await runCmd(dartCmd([pubTestDartScript, '-p', 'vm', testPath]));

        // on 1.13, current windows is failing
        if (!Platform.isWindows) {
          expect(result.exitCode, 0);
        }

        expect(result.stdout.contains("All tests passed"), isTrue);
      } finally {
        try {
          await new File(testPath).delete();
        } catch (_) {}
      }
    });

    test('failure', () async {
      var testPath = join('test', 'data', 'fail_test.dart');
      try {
        await new File(join('test', 'data', 'fail_test_.dart')).copy(testPath);
        ProcessResult result = await runCmd(dartCmd([
          pubTestDartScript,
          '-p',
          'vm',
          testPath
        ])); // ..connectStderr=true..connectStdout=true);
        if (!Platform.isWindows) {
          expect(result.exitCode, 1);
        }
      } finally {
        try {
          await new File(testPath).delete();
        } catch (_) {}
      }
    });

    group('example', () {
      test('subdir', () async {
        String top = (await Directory.systemTemp.createTemp()).path;

        PubPackage exampleSuccessDir =
            new PubPackage(join('example', 'success'));
        PubPackage pkg = await exampleSuccessDir.clone(join(top, 'success'));

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
        expect(pubRunTestJsonIsSuccess(result.stdout as String), isTrue);
        expect(pubRunTestJsonSuccessCount(result.stdout as String), 1);
        expect(pubRunTestJsonFailureCount(result.stdout as String), 0);

        // run one level above
        result = await runCmd(pkg.dartCmd([
          pubTestDartScript,
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

        //print(result.stdout);
        //print(result.stderr);
        // on 1.13, current windows is failing
        if (!Platform.isWindows) {
          expect(result.exitCode, 0);
        }
        expect(pubRunTestJsonIsSuccess(result.stdout as String), isTrue);
        //expect(pubRunTestJsonProcessResultSuccessCount(result), 1);
        //expect(pubRunTestJsonProcessResultFailureCount(result), 0);
      });
    });

    // expect
  });
}
