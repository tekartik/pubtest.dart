@TestOn("vm")
library tekartik_pub.test.pub_test;

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:dev_test/test.dart';
import 'package:tekartik_pub/pub.dart';
import 'package:tekartik_pub/script.dart';
import 'package:tekartik_pub/pubspec.dart';
import 'package:pubtest/src/pubtest_version.dart';
import 'package:pub_semver/pub_semver.dart';
import 'dart:io';

class TestScript extends Script {}

String get testScriptPath => getScriptPath(TestScript);

void main() => defineTests();

String get _pubPackageRoot => getPubPackageRootSync(testScriptPath);

String get pubTestDartScript {
  PubPackage pkg = new PubPackage(_pubPackageRoot);
  return join(pkg.path, 'bin', 'pubtest.dart');
}

void defineTests() {
  //useVMConfiguration();
  group('pubtest', () {
    test('src.version', () async {
      expect(version, await extractPubspecYamlVersion(_pubPackageRoot));
    });

    test('version', () async {
      ProcessResult result =
          await runCmd(dartCmd([pubTestDartScript, '--version']));
      expect(result.stdout, contains("pubtest"));
      expect(new Version.parse(result.stdout.split(' ').last), version);
    });

    test('success', () async {
      ProcessResult result = await runCmd(
          dartCmd([pubTestDartScript, 'test/data/success_test_.dart']));

      // on 1.13, current windows is failing
      if (!Platform.isWindows) {
        expect(result.exitCode, 0);
      }
    });

    test('failure', () async {
      ProcessResult result = await runCmd(dartCmd([
        pubTestDartScript,
        'test/data/fail_test_.dart'
      ])); // ..connectStderr=true..connectStdout=true);

      if (!Platform.isWindows) {
        expect(result.exitCode, 1);
      }
    });
  });
}
