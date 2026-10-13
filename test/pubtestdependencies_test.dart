@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:process_run/shell_run.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_pub/io.dart';
import 'package:tekartik_pubtest/src/pubtest_version.dart';
import 'package:test/test.dart';

import 'pubtest_test.dart';

String get pubTestDependenciesDartScript =>
    normalize(absolute(join('bin', 'pubtestdependencies.dart')));

void main() {
  //useVMConfiguration();
  group('pubtestdependencies', () {
    test('version', () async {
      final result = await runCmd(
        DartCmd(['run', pubTestDependenciesDartScript, '--version']),
      );
      expect(result.stdout, contains('pubtestdependencies'));
      expect(Version.parse(result.outText.split(' ').last), version);
    });

    test('synchronized dependency', () async {
      // print(userEnvironment);
      final result = await Shell(verbose: true).runExecutableArguments('dart', [
        'run',
        pubTestDependenciesDartScript,
        '--package-name',
        'synchronized',
        '-v',
        '-n',
        'BasicLock',
      ]);
      expect(
        result.stdout,
        contains('All tests passed'),
        reason: getReason(result),
      );
      //expect(Version.parse(result.stdout.split(' ').last as String), version);
    }, skip: true);

    /// Copy [name] and its dependency to a temp dir, get offline
    Future<PubPackage> setUpExample(String name) async {
      final top = (await Directory.systemTemp.createTemp()).path;
      addTearDown(() => Directory(top).delete(recursive: true));
      final pkg = await PubPackage(
        join('example', name),
      ).clone(join(top, name));
      await PubPackage(
        join('example', '${name}_dependency'),
      ).clone(join(top, '${name}_dependency'));
      await runCmd(pkg.pubCmd(pubGetArgs(offline: true)), stderr: stderr);
      return pkg;
    }

    Future<ProcessResult> runPubTestDependencies(
      PubPackage pkg,
      List<String> args,
    ) => runCmd(
      pkg.dartCmd([
        'run',
        pubTestDependenciesDartScript,
        '-r',
        'json',
        '-p',
        'vm',
        '--get-offline',
        ...args,
      ]),
      stderr: stderr,
    );

    test('simple_dependencies', () async {
      final pkg = await setUpExample('simple');
      final result = await runPubTestDependencies(pkg, []);
      // on 1.13, current windows is failing
      if (!Platform.isWindows) {
        expect(result.exitCode, 0, reason: getReason(result));
      }
      expect(
        pubRunTestJsonIsSuccess(result.stdout as String),
        isTrue,
        reason: getReason(result),
      );
      expect(
        pubRunTestJsonSuccessCount(result.stdout as String),
        1,
        reason: getReason(result),
      );
      expect(
        pubRunTestJsonFailureCount(result.stdout as String),
        0,
        reason: getReason(result),
      );
    }, timeout: longTimeout);

    test('simple_filter_dependencies', () async {
      final pkg = await setUpExample('simple');

      // filtering on a dummy package, nothing is tested
      var result = await runPubTestDependencies(pkg, [
        '--package-name',
        'dummy',
      ]);
      if (!Platform.isWindows) {
        expect(result.exitCode, 0, reason: getReason(result));
      }
      expect(
        pubRunTestJsonIsSuccess(result.stdout as String),
        isFalse,
        reason: getReason(result),
      );
      expect(pubRunTestJsonSuccessCount(result.stdout as String), 0);
      expect(pubRunTestJsonFailureCount(result.stdout as String), 0);

      // filtering on the only package it has
      result = await runPubTestDependencies(pkg, [
        '--package-name',
        'pubtest_example_simple_dependency',
      ]);
      if (!Platform.isWindows) {
        expect(result.exitCode, 0, reason: getReason(result));
      }
      expect(
        pubRunTestJsonIsSuccess(result.stdout as String),
        isTrue,
        reason: getReason(result),
      );
      expect(pubRunTestJsonSuccessCount(result.stdout as String), 1);
      expect(pubRunTestJsonFailureCount(result.stdout as String), 0);
    }, timeout: longTimeout);

    test('simple_failed_dependencies', () async {
      final pkg = await setUpExample('simple_failed');
      final result = await runPubTestDependencies(pkg, []);
      if (!Platform.isWindows) {
        expect(result.exitCode, 1, reason: getReason(result));
      }
      expect(
        pubRunTestJsonIsSuccess(result.stdout as String),
        isFalse,
        reason: getReason(result),
      );
      expect(
        pubRunTestJsonFailureCount(result.stdout as String),
        1,
        reason: getReason(result),
      );
    }, timeout: longTimeout);

    test('dry-run', () async {
      final pkg = await setUpExample('simple');
      final result = await runPubTestDependencies(pkg, ['--dry-run']);
      expect(result.exitCode, 0, reason: getReason(result));
      expect(
        result.stdout,
        contains('[dryRun] clone '),
        reason: getReason(result),
      );
      // Nothing cloned
      expect(Directory(join(pkg.path, 'build')).existsSync(), isFalse);
    }, timeout: longTimeout);
  });
}
