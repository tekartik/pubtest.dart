@TestOn("vm")
library tekartik_pub.test.pub_test;

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:dev_test/test.dart';
import 'package:tekartik_pub/pub.dart';
import 'package:tekartik_pub/script.dart';
import 'package:pubtest/src/pubtest_version.dart';
import 'package:pub_semver/pub_semver.dart';
import 'dart:io';

class TestScript extends Script {}

String get testScriptPath => getScriptPath(TestScript);

void main() => defineTests();

String get _pubPackageRoot => getPubPackageRootSync(testScriptPath);

String get pubTestDependenciesDartScript {
  PubPackage pkg = new PubPackage(_pubPackageRoot);
  return join(pkg.path, 'bin', 'pubtestdependencies.dart');
}

void defineTests() {
  //useVMConfiguration();
  group('pubtest', () {
    test('version', () async {
      ProcessResult result =
          await runCmd(dartCmd([pubTestDependenciesDartScript, '--version']));
      expect(result.stdout, contains("pubtest"));
      expect(new Version.parse(result.stdout.split(' ').last), version);
    });

    test('our dependencies', () async {
      ProcessResult result =
          await runCmd(dartCmd([pubTestDependenciesDartScript])
            ..connectStderr = false
            ..connectStdout = false);

      // on 1.13, current windows is failing
      if (!Platform.isWindows) {
        expect(result.exitCode, 0);
      }

      expect(result.stdout.contains("All tests passed"), isTrue);
    });
  });
}
