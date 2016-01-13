@TestOn("vm")
library tekartik_pub.test.pub_test;

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:dev_test/test.dart';
import 'package:tekartik_pub/pub_fs_io.dart';
import 'package:fs_shim_test/test_io.dart';
import 'package:pubtest/src/pubtest_version.dart';
import 'package:pub_semver/pub_semver.dart';

class TestScript extends Script {}

Directory get pkgDir => new File(getScriptPath(TestScript)).parent.parent;

void main() =>
    defineTests(newIoFileSystemContext(join(pkgDir.path, 'test_out')));

String get pubTestDependenciesDartScript {
  return join(pkgDir.path, 'bin', 'pubtestdependencies.dart');
}

void defineTests(FileSystemTestContext ctx) {
  //useVMConfiguration();
  group('pubtestdependencies', () {
    test('version', () async {
      ProcessResult result =
          await runCmd(dartCmd([pubTestDependenciesDartScript, '--version']));
      expect(result.stdout, contains("pubtestdependencies"));
      expect(new Version.parse(result.stdout.split(' ').last), version);
    });

    test('simple_dependencies', () async {
      Directory top = await ctx.prepare();
      IoFsPubPackage exampleSimplePkg =
          new IoFsPubPackage(childDirectory(pkgDir, join('example', 'simple')));
      IoFsPubPackage exampleSimpleDependencyPkg = new IoFsPubPackage(
          childDirectory(pkgDir, join('example', 'simple_dependency')));

      Directory dst = childDirectory(top, 'simple');
      Directory dstDependency = childDirectory(top, 'simple_dependency');
      IoFsPubPackage pkg = await exampleSimplePkg.clone(dst);
      await exampleSimpleDependencyPkg.clone(dstDependency);
      await pkg.runPub(pubGetArgs(offline: true),
          connectStderr: true, connectStdout: false);
      ProcessResult result = await pkg.runCmd(dartCmd(
          [pubTestDependenciesDartScript, '--get-offline', '-r', 'json'])
        // p', 'vm'])
        ..connectStderr = true
        ..connectStdout = false);

      // on 1.13, current windows is failing
      if (!Platform.isWindows) {
        expect(result.exitCode, 0);
      }

      //expect(result.stdout.contains("All tests passed"), isTrue);
      expect(pubRunTestJsonProcessResultIsSuccess(result), isTrue,
          reason: result.toString());
      expect(pubRunTestJsonProcessResultSuccessCount(result), 4,
          reason: result.toString());
      expect(pubRunTestJsonProcessResultFailureCount(result), 0,
          reason: result.toString());
    }); //, timeout: new Timeout(new Duration(minutes: 5)));

    test('simple_failed_dependencies', () async {
      Directory top = await ctx.prepare();
      IoFsPubPackage exampleSimplePkg = new IoFsPubPackage(
          childDirectory(pkgDir, join('example', 'simple_failed')));
      IoFsPubPackage exampleSimpleDependencyPkg = new IoFsPubPackage(
          childDirectory(pkgDir, join('example', 'simple_failed_dependency')));

      Directory dst = childDirectory(top, 'simple_failed');
      Directory dstDependency = childDirectory(top, 'simple_failed_dependency');
      IoFsPubPackage pkg = await exampleSimplePkg.clone(dst);
      await exampleSimpleDependencyPkg.clone(dstDependency);
      await pkg.runPub(pubGetArgs(offline: true),
          connectStderr: true, connectStdout: false);
      ProcessResult result = await pkg.runCmd(dartCmd(
          [pubTestDependenciesDartScript, '--get-offline', '-r', 'json'])
        // p', 'vm'])
        ..connectStderr = true
        ..connectStdout = false);

      // on 1.13, current windows is failing
      if (!Platform.isWindows) {
        expect(result.exitCode, 1);
      }

      //expect(result.stdout.contains("All tests passed"), isTrue);
      expect(pubRunTestJsonProcessResultIsSuccess(result), isFalse);
      /*
      expect(pubRunTestJsonProcessResultSuccessCount(result), );
      expect(pubRunTestJsonProcessResultFailureCount(result), 0);
      */
      /*
      Directory top = await ctx.prepare();
      IoFsPubPackage exampleSimplePkg =
      new IoFsPubPackage(childDirectory(pkgDir, join('example', 'simple_failed')));


      await runCmd(exampleSimplePkg.getCmd(offline: true));
      ProcessResult result =
          await runCmd(dartCmd([pubTestDependenciesDartScript, '--get-offline'])
            // p', 'vm'])
            ..connectStderr = false
            ..connectStdout = false
            ..workingDirectory = exampleSimplePkg.path);

      // on 1.13, current windows is failing
      if (!Platform.isWindows) {
        expect(result.exitCode, 1);
      }

      expect(result.stdout.contains("All tests passed"), isFalse);
      expect(result.stderr.contains("rrors in packages"), isTrue);
      expect(result.stderr.contains("pubtest_example_simple_failed_dependency"),
          isTrue);
          */
    }); //, timeout: new Timeout(new Duration(minutes: 5)));
  });
}
