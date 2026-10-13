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

var longTimeout = const Timeout(Duration(minutes: 2));
var exampleBinPath = join('example', 'bin');
String get _pubTestDartScript =>
    normalize(absolute(join(exampleBinPath, 'pubtest.dart')));

void main() {
  group('pubtest', () {
    defineTests(_pubTestDartScript);
  });
}

String getReason(ProcessResult result) {
  return 'OUT:\n${result.stdout}\nERR:\n${result.stderr}';
}

void defineTests(String script, {String suffix = 'pub'}) {
  // we use a prefix, needed since this can be called during pubtest_test and pbrtest_test
  test('version', () async {
    final result = await runCmd(DartCmd(['run', script, '--version']));
    expect(result.stdout, contains(basenameWithoutExtension(script)));
    expect(Version.parse((result.stdout as String).split(' ').last), version);
  });

  String fileWithSuffix(String srcPath) {
    return '${withoutExtension(srcPath)}${suffix}_test${extension(srcPath)}';
  }

  /// Use suffix
  Future<String> copyFile(String srcPath) async {
    var dstPath = fileWithSuffix(srcPath);
    await File(srcPath).copy(dstPath);
    return dstPath;
  }

  test('success', () async {
    var testPath = join('test', 'data', 'success_test.dart');

    try {
      final result = await runCmd(
        DartCmd(['run', script, '-p', 'vm', testPath]),
      );

      // on 1.13, current windows is failing
      if (!Platform.isWindows) {
        expect(result.exitCode, 0, reason: result.stderr?.toString());
      }

      //expect(result.stdout.contains('All tests passed'), isTrue, reason: getReason(result));
    } finally {}
  }, timeout: longTimeout);

  test('failure', () async {
    var testSrcPath = join('test', 'data', 'fail_test_.dart');
    var testPath = await copyFile(testSrcPath);
    try {
      final result = await runCmd(
        DartCmd(['run', script, '-p', 'vm', testPath]),
      ); // ..connectStderr=true..connectStdout=true);
      if (!Platform.isWindows) {
        expect(
          result.exitCode,
          isNot(0),
        ); // sometimes 1, sometimes 255, don't know why
      }
    } finally {
      // cleanup
      await File(testPath).delete();
    }
  }, timeout: longTimeout);

  group('example', () {
    test('subdir', () async {
      final top = (await Directory.systemTemp.createTemp()).path;

      final exampleSuccessDir = PubPackage(join('example', 'success'));
      final pkg = await exampleSuccessDir.clone(join(top, 'success'));

      // Filter test having 'success' in the data dir
      var result = await runCmd(
        pkg.dartCmd([
          'run',
          script,
          '-p',
          'vm',
          (pkg.dir.path),
          '-n',
          'success',
          '-r',
          'json',
          '--get-offline',
        ]),
      );

      // on 1.13, current windows is failing
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

      // run one level above
      result = await runCmd(
        pkg.dartCmd([
          'run',
          script,
          '-p',
          'vm',
          top,
          '-n',
          'success',
          '-r',
          'json',
          '--get-offline',
        ]),
      );

      if (!Platform.isWindows) {
        expect(result.exitCode, 0, reason: getReason(result));
      }
      expect(
        pubRunTestJsonIsSuccess(result.stdout as String),
        isTrue,
        reason: getReason(result),
      );
    });
  }, timeout: longTimeout);

  group('dry-run', () {
    late String top;
    setUp(() async {
      top = (await Directory.systemTemp.createTemp()).path;
    });
    tearDown(() async {
      await Directory(top).delete(recursive: true);
    });

    Future<String> createPackage({bool flutter = false}) async {
      var dir = join(top, 'pkg');
      await Directory(join(dir, 'test', 'sub')).create(recursive: true);
      await File(join(dir, 'pubspec.yaml')).writeAsString(
        [
          'name: pubtest_dry_run_pkg',
          'environment:',
          '  sdk: ^3.12.0',
          if (flutter) ...['dependencies:', '  flutter:', '    sdk: flutter'],
          'dev_dependencies:',
          '  test: any',
          if (flutter) ...['  flutter_test:', '    sdk: flutter'],
          '',
        ].join('\n'),
      );
      await File(
        join(dir, 'test', 'sub', 'a_test.dart'),
      ).writeAsString('void main() {}\n');
      return dir;
    }

    test('directory inside a package', () async {
      var dir = await createPackage();
      var result = await runCmd(
        DartCmd(['run', script, '--dry-run', join(dir, 'test', 'sub')]),
      );
      expect(result.exitCode, 0, reason: getReason(result));
      expect(
        result.stdout,
        contains('[dryRun] test on ${Directory(dir)} [${join('test', 'sub')}]'),
        reason: getReason(result),
      );
    });

    test('flutter files, platforms and reporter', () async {
      var dir = await createPackage(flutter: true);
      var result = await runCmd(
        DartCmd([
          'run',
          script,
          '--dry-run',
          '-p',
          'vm',
          '-p',
          'chrome',
          '-r',
          'json',
          '-n',
          'foo',
          join(dir, 'test', 'sub', 'a_test.dart'),
        ]),
      );
      var testFile = join('test', 'sub', 'a_test.dart');
      expect(result.exitCode, 0, reason: getReason(result));
      expect(
        result.stdout,
        contains('test --no-pub -j 10 -n foo -r json $testFile'),
        reason: getReason(result),
      );
      expect(
        result.stdout,
        contains(
          'test --no-pub --platform chrome -j 10 -n foo -r json $testFile',
        ),
        reason: getReason(result),
      );
    }, skip: isFlutterSupportedSync ? null : 'flutter not found');
  });

  test('runCmd prints the output once', () async {
    var result = await runCmd(
      DartCmd(['run', join('test', 'src', 'run_cmd_main.dart')]),
    );
    expect(result.exitCode, 0, reason: getReason(result));
    expect(
      'Dart SDK version'.allMatches(result.stdout as String).length,
      1,
      reason: getReason(result),
    );
    expect(result.stdout, contains('exitCode: '), reason: getReason(result));
  }, timeout: longTimeout);
}
