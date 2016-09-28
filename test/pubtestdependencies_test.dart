@TestOn("vm")
library tekartik_pub.test.pub_test;

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:dev_test/test.dart';
import 'package:tekartik_pub/io.dart';
import 'package:fs_shim_test/test_io.dart';
import 'package:pubtest/src/pubtest_version.dart';
import 'package:pub_semver/pub_semver.dart';
import 'dart:io' as io;

class TestScript extends Script {}

String get pkgDir => new File(getScriptPath(TestScript)).parent.parent.path;

void main() =>
    defineTests(newIoFileSystemContext(io.Directory.systemTemp
        .createTempSync('pubtestdependencies_test_')
        .path));

String get pubTestDependenciesDartScript {
  return join(pkgDir, 'bin', 'pubtestdependencies.dart');
}

void defineTests(FileSystemTestContext ctx) {
  //useVMConfiguration();
  group('pubtestdependencies', () {
    test('version', () async {
      ProcessResult result =
      await runCmd(dartCmd([pubTestDependenciesDartScript, '--version']));
      expect(result.stdout, contains("pubtestdependencies"));
      expect(new Version.parse(result.stdout
          .split(' ')
          .last), version);
    });

    test('simple_dependencies', () async {
      String top = (await ctx.prepare()).path;
      PubPackage exampleSimplePkg =
      new PubPackage(join(pkgDir, 'example', 'simple'));
      PubPackage exampleSimpleDependencyPkg = new PubPackage(
          join(pkgDir, 'example', 'simple_dependency'));

      String dst = join(top, 'simple');
      String dstDependency = join(top, 'simple_dependency');
      PubPackage pkg = await exampleSimplePkg.clone(dst);
      await exampleSimpleDependencyPkg.clone(dstDependency);
      await runCmd(pkg.pubCmd(pubGetArgs(/*offline: true*/)),
          stderr: stderr);
      ProcessResult result = await runCmd(pkg.dartCmd([
        pubTestDependenciesDartScript, /*'--get',*/ '-r',
        'json',
        '-p',
        'vm'
      ]) // --get-offline failed using 1.16
      // p', 'vm'])
      , stderr: stderr);

      // on 1.13, current windows is failing
      if (!Platform.isWindows) {
        expect(result.exitCode, 0);
      }

      //expect(result.stdout.contains("All tests passed"), isTrue);
      expect(pubRunTestJsonIsSuccess(result.stdout), isTrue,
          reason: result.toString());
      expect(pubRunTestJsonSuccessCount(result.stdout), 1,
          reason: result.stdout.toString());
      expect(pubRunTestJsonFailureCount(result.stdout), 0,
          reason: result.stdout.toString());
    }); //, timeout: new Timeout(new Duration(minutes: 5)));

    test('simple_failed_dependencies', () async {
      String top = (await ctx.prepare()).path;
      PubPackage exampleSimplePkg = new PubPackage(
          join(pkgDir, 'example', 'simple_failed'));
      PubPackage exampleSimpleDependencyPkg = new PubPackage(
          join(pkgDir, 'example', 'simple_failed_dependency'));

      String dst = join(top, 'simple_failed');
      String dstDependency = join(top, 'simple_failed_dependency');
      PubPackage pkg = await exampleSimplePkg.clone(dst);
      await exampleSimpleDependencyPkg.clone(dstDependency);
      await runCmd(pkg.pubCmd(pubGetArgs(/*offline: true*/)),
          stderr: stderr);
      ProcessResult result = await runCmd(
          pkg.dartCmd([pubTestDependenciesDartScript, '-r', 'json', '-p', 'vm'])
      // '--get-offline' failed on sdk 1.16
      // p', 'vm'])
      , stderr: stderr);

      // on 1.13, current windows is failing
      if (!Platform.isWindows) {
        expect(result.exitCode, 1);
      }

      //expect(result.stdout.contains("All tests passed"), isTrue);
      expect(pubRunTestJsonIsSuccess(result.stdout), isFalse);

    }); //, timeout: new Timeout(new Duration(minutes: 5)));
  });
}
