@TestOn("vm")
library tekartik_pubtest.test.pubtestdependencies;

import 'dart:io';

import 'package:dev_test/test.dart';
import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:tekartik_pubtest/src/pubtest_version.dart';
import 'package:tekartik_pub/io.dart';

String get pubTestDependenciesDartScript =>
    normalize(absolute(join('bin', 'pubtestdependencies.dart')));

void main() {
  //useVMConfiguration();
  group('pubtestdependencies', () {
    test('version', () async {
      ProcessResult result =
          await runCmd(DartCmd([pubTestDependenciesDartScript, '--version']));
      expect(result.stdout, contains("pubtestdependencies"));
      expect(Version.parse(result.stdout.split(' ').last as String), version);
    });

    test('simple_dependencies', () async {
      String top = (await Directory.systemTemp.createTemp()).path;

      PubPackage exampleSimplePkg = PubPackage(join('example', 'simple'));
      PubPackage exampleSimpleDependencyPkg =
          PubPackage(join('example', 'simple_dependency'));

      String dst = join(top, 'simple');
      String dstDependency = join(top, 'simple_dependency');
      PubPackage pkg = await exampleSimplePkg.clone(dst);
      await exampleSimpleDependencyPkg.clone(dstDependency);
      await runCmd(pkg.pubCmd(pubGetArgs(/*offline: true*/)), stderr: stderr);
      ProcessResult result = await runCmd(
          pkg.dartCmd([
            pubTestDependenciesDartScript,
            /*'--get',*/ '-r',
            /* -r requires 0.12.+*/
            'json',
            '-p',
            'vm'
          ]) // --get-offline failed using 1.16
          // p', 'vm'])
          ,
          stderr: stderr);

      // on 1.13, current windows is failing
      if (!Platform.isWindows) {
        expect(result.exitCode, 0);
      }

      //expect(result.stdout.contains("All tests passed"), isTrue);
      expect(pubRunTestJsonIsSuccess(result.stdout as String), isTrue,
          reason: result.toString());
      expect(pubRunTestJsonSuccessCount(result.stdout as String), 1,
          reason: result.stdout.toString());
      expect(pubRunTestJsonFailureCount(result.stdout as String), 0,
          reason: result.stdout.toString());
    }, timeout: Timeout(Duration(minutes: 2)));

    test('simple_filter_dependencies', () async {
      String top = (await Directory.systemTemp.createTemp()).path;
      PubPackage exampleSimplePkg = PubPackage(join('example', 'simple'));
      PubPackage exampleSimpleDependencyPkg =
          PubPackage(join('example', 'simple_dependency'));

      String dst = join(top, 'simple');
      String dstDependency = join(top, 'simple_dependency');
      PubPackage pkg = await exampleSimplePkg.clone(dst);
      await exampleSimpleDependencyPkg.clone(dstDependency);
      await runCmd(pkg.pubCmd(pubGetArgs(offline: true)), stderr: stderr);

      // filtering on a dummy package
      ProcessResult result = await runCmd(
          pkg.dartCmd([
            pubTestDependenciesDartScript,
            '-r',
            'json',
            '-p',
            'vm',
            '--package-name',
            'dummy'
          ]) // --get-offline failed using 1.16
          // p', 'vm'])
          ,
          stderr: stderr);

      // on 1.13, current windows is failing
      if (!Platform.isWindows) {
        expect(result.exitCode, 0);
      }

      //expect(result.stdout.contains("All tests passed"), isTrue);
      expect(pubRunTestJsonIsSuccess(result.stdout as String), isFalse,
          reason: result.toString());
      expect(pubRunTestJsonSuccessCount(result.stdout as String), 0,
          reason: result.stdout.toString());
      expect(pubRunTestJsonFailureCount(result.stdout as String), 0,
          reason: result.stdout.toString());

      // filtering on the only package it has
      result = await runCmd(
          pkg.dartCmd([
            pubTestDependenciesDartScript,
            '-r',
            'json',
            '-p',
            'vm',
            '-f',
            'pubtest_example_simple_dependency'
          ]) // --get-offline failed using 1.16
          // p', 'vm'])
          ,
          stderr: stderr);

      // on 1.13, current windows is failing
      if (!Platform.isWindows) {
        expect(result.exitCode, 0);
      }

      //expect(result.stdout.contains("All tests passed"), isTrue);
      expect(pubRunTestJsonIsSuccess(result.stdout as String), isTrue,
          reason: result.toString());
      expect(pubRunTestJsonSuccessCount(result.stdout as String), 1,
          reason: result.stdout.toString());
      expect(pubRunTestJsonFailureCount(result.stdout as String), 0,
          reason: result.stdout.toString());
    }, timeout: Timeout(Duration(minutes: 2)));

    test('simple_failed_dependencies', () async {
      String top = (await Directory.systemTemp.createTemp()).path;
      PubPackage exampleSimplePkg =
          PubPackage(join('example', 'simple_failed'));
      PubPackage exampleSimpleDependencyPkg =
          PubPackage(join('example', 'simple_failed_dependency'));

      String dst = join(top, 'simple_failed');
      String dstDependency = join(top, 'simple_failed_dependency');
      PubPackage pkg = await exampleSimplePkg.clone(dst);
      await exampleSimpleDependencyPkg.clone(dstDependency);
      await runCmd(pkg.pubCmd(pubGetArgs(/*offline: true*/)), stderr: stderr);
      ProcessResult result = await runCmd(
          pkg.dartCmd([pubTestDependenciesDartScript, '-r', 'json', '-p', 'vm'])
          // '--get-offline' failed on sdk 1.16
          // p', 'vm'])
          ,
          stderr: stderr);

      // on 1.13, current windows is failing
      if (!Platform.isWindows) {
        expect(result.exitCode, 1);
      }

      //expect(result.stdout.contains("All tests passed"), isTrue);
      expect(pubRunTestJsonIsSuccess(result.stdout as String), isFalse);
    }, timeout: Timeout(Duration(minutes: 2)));
  });
}
