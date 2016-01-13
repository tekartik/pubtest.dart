@TestOn("vm")
library tekartik_pub.test.pub_test;

import 'package:process_run/cmd_run.dart';
import 'package:dev_test/test.dart';
import 'package:tekartik_pub/pub_fs_io.dart';
import 'package:pubtest/src/pubtest_version.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:fs_shim_test/test_io.dart';

class TestScript extends Script {}

Directory get pkgDir => new File(getScriptPath(TestScript)).parent.parent;

void main() =>
    defineTests(newIoFileSystemContext(join(pkgDir.path, 'test_out')));

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

        IoFsPubPackage exampleSuccessDir = new IoFsPubPackage(
            childDirectory(pkgDir, join('example', 'success')));
        IoFsPubPackage pkg = await exampleSuccessDir.clone(successDir);

        // Filter test having "success" in the data dir
        ProcessResult result = await pkg.runCmd(dartCmd([
          pubTestDartScript,
          '-p',
          'vm',
          '${pkg.dir.path}',
          '-n',
          'success',
          '-r',
          'json',
          '--get-offline'
        ]));

        // on 1.13, current windows is failing
        if (!Platform.isWindows) {
          expect(result.exitCode, 0);
        }
        expect(pubRunTestJsonProcessResultIsSuccess(result), isTrue);
        expect(pubRunTestJsonProcessResultSuccessCount(result), 1);
        expect(pubRunTestJsonProcessResultFailureCount(result), 0);

        // run one level above
        result = await pkg.runCmd(dartCmd([
          pubTestDartScript,
          '-p',
          'vm',
          '${top.path}',
          '-n',
          'success',
          '-r',
          'json',
          '--get-offline',
          //'--dry-run', // dry run
        ]));

        //print(result.stdout);
        //print(result.stderr);
        // on 1.13, current windows is failing
        if (!Platform.isWindows) {
          expect(result.exitCode, 0);
        }
        expect(pubRunTestJsonProcessResultIsSuccess(result), isTrue);
        //expect(pubRunTestJsonProcessResultSuccessCount(result), 1);
        //expect(pubRunTestJsonProcessResultFailureCount(result), 0);
      });
    });

    // expect
  });
}
