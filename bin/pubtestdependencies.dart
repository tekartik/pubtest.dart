#!/usr/bin/env dart
library pubtest.bin.pubtest;

// Pull recursively

import 'dart:io';
import 'dart:async';
import 'package:path/path.dart';
import 'package:args/args.dart';
import 'package:tekartik_pub/pub.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_pub/src/rpubpath.dart';
import 'package:pubtest/src/pubtest_version.dart';
import 'package:pubtest/src/pubtest_utils.dart';
import 'package:pubtest/src/file_clone.dart';
import 'package:pool/pool.dart';
import 'package:tekartik_pub/pubspec.dart';

String get currentScriptName => basenameWithoutExtension(Platform.script.path);

const String _HELP = 'help';
//const String _LOG = 'log';
const String _DRY_RUN = 'dry-run';
const String _CONCURRENCY = 'concurrency';
const String _PACKAGE_CONCURRENCY = 'packageConcurrency';
const String _PLATFORM = 'platform';
const String _NAME = 'name';
const String _reporterOption = "reporter";
const String _reporterOptionAbbr = "r";

bool _debug = false;

const List<String> allPlatforms = const [
  "vm",
  "dartium",
  "content-shell",
  "chrome",
  "phantomjs",
  "firefox",
  "safari",
  "ie"
];

///
/// Recursively update (pull) git folders
///
Future main(List<String> arguments) async {
  //setupQuickLogging();
  int exitCode = 0;

  ArgParser parser = new ArgParser(allowTrailingOptions: true);
  parser.addFlag(_HELP, abbr: 'h', help: 'Usage help', negatable: false);
  //parser.addOption(_LOG, abbr: 'l', help: 'Log level (fine, debug, info...)');
  parser.addOption(_reporterOption,
      abbr: _reporterOptionAbbr,
      help: 'test result output',
      allowed: testReporterStrings);
  parser.addFlag(_DRY_RUN,
      abbr: 'd',
      help: 'Do not run test, simple show packages to be tested',
      negatable: false);
  parser.addFlag("version",
      help: 'Display the script version', negatable: false);
  parser.addOption(_CONCURRENCY,
      abbr: 'j',
      help: 'Number of concurrent tests in the same package tested',
      defaultsTo: '10');
  parser.addOption(_PACKAGE_CONCURRENCY,
      abbr: 'k',
      help: 'Number of concurrent packages tested',
      defaultsTo: '10');
  parser.addOption(_NAME,
      abbr: 'n', help: 'A substring of the name of the test to run');
  parser.addOption(_PLATFORM,
      abbr: 'p',
      help: 'The platform(s) on which to run the tests.',
      allowed: allPlatforms,
      defaultsTo: 'vm',
      allowMultiple: true);
  ArgResults _argsResult = parser.parse(arguments);

  bool help = _argsResult[_HELP];
  if (help) {
    stdout.writeln(
        "Call 'pub run test' recursively (default from current directory)");
    stdout.writeln();
    stdout.writeln(
        'Usage: ${currentScriptName} [<folder_paths...>] [<arguments>]');
    stdout.writeln();
    stdout.writeln("Global options:");
    stdout.writeln(parser.usage);
    return;
  }

  if (_argsResult['version']) {
    stdout.write('${currentScriptName} ${version}');
    return;
  }
  /*
  String logLevel = _argsResult[_LOG];
  if (logLevel != null) {
    Logger.root.level = parseLogLevel(logLevel);
    Logger.root.info('Log level ${Logger.root.level}');
  }
  */
  bool dryRun = _argsResult[_DRY_RUN];
  TestReporter reporter;
  String reporterString = _argsResult[_reporterOption];
  if (reporterString != null) {
    reporter = testReporterFromString(reporterString);
  }

  String name = _argsResult[_NAME];

  // get dirs in parameters, default to current
  List<String> dirsOrFiles = new List.from(_argsResult.rest);
  if (dirsOrFiles.isEmpty) {
    dirsOrFiles = [Directory.current.path];
  }
  List<String> dirs = [];

  List<String> platforms;
  if (_argsResult.wasParsed(_PLATFORM)) {
    platforms = _argsResult[_PLATFORM] as List<String>;
  } else {
    // Allow platforms in env variable
    String envPlatforms = Platform.environment["PUBTEST_PLATFORMS"];
    if (envPlatforms != null) {
      stdout.writeln("Using platforms: ${envPlatforms}");
      platforms = envPlatforms.split(",");
    }
    // compatiblity with previous rpubtest
    envPlatforms = Platform.environment["TEKARTIK_RPUBTEST_PLATFORMS"];
    if (envPlatforms != null) {
      stdout.writeln("Using platforms: ${envPlatforms}");
      platforms = envPlatforms.split(",");
    }
  }

  //PubTest pubTest = new PubTest();
  NewTestList list = new NewTestList();

  int poolSize = int.parse(_argsResult[_CONCURRENCY]);
  int packagePoolSize = int.parse(_argsResult[_PACKAGE_CONCURRENCY]);

  Future _handleProject(DependencyTestPackage dependency,
      [List<String> files]) async {
    // Clone the project
    PubPackage pkg = new PubPackage(
        join(dependency.parent.path, 'build', 'test', dependency.package.name));

    await emptyOrCreateDirSync(pkg.path);
    await cloneFiles(dependency.package.path, pkg.path);

    ProcessCmd cmd = pkg.getCmd(offline: true);
    if (_debug) {
      print('on: ${cmd.workingDirectory}');
      print('before: $cmd');
    }
    await runCmd(cmd..connectStderr = true..connectStdout);
    if (_debug) {
      print('after: $cmd');
    }
    // if no file is given make sure the test/folder exists
    if (files == null) {
      // no tests found
      if (!(await FileSystemEntity.isDirectory(join(pkg.path, "test")))) {
        return;
      }
    }
    print('test on ${pkg.path}${files != null ? " ${files}": ""}');
    if (dryRun) {
      //print('test on ${pkg.path}${files != null ? " ${files}": ""}');
    } else {
      try {
        List<String> args = [];
        if (files != null) {
          args.addAll(files);
        }
        ProcessCmd cmd = pkg.testCmd(args,
            concurrency: poolSize,
            reporter: reporter,
            platforms: platforms,
            name: name
        );
        if (_debug) {
          print('on: ${cmd.workingDirectory}');
          print('before: $cmd');
        }

        ProcessResult result = await runCmd(cmd..connectStderr = true
..connectStdout = true);
        if (_debug) {
          print('after: $cmd');
        }
        if (result.exitCode != 0) {
          stderr.writeln('test error in ${pkg}');
          if (exitCode == 0) {
            exitCode = result.exitCode;
          }
        }
      } catch (e) {
        stderr.writeln('error thrown in ${pkg}');
        stderr.flush();
        throw e;
      }
    }
  }

  Pool packagePool = new Pool(packagePoolSize);

  _parseDirectory(String packageDir) async {
    //print(packageDir);
    PubPackage parent = new PubPackage(packageDir);
    Iterable<String> dependencies =
        await extractPubspecDependencies(packageDir);
    //Map dotPackagesYaml = await getDotPackagesYaml(mainPackage.path);
    for (String dependency in dependencies) {
      PubPackage pkg = await extractPackage(dependency, packageDir);
      if (yamlHasAnyDependencies(getPackageYamlSync(pkg.path), ['test'])) {
        // add whole package
        list.add(new DependencyTestPackage(parent, pkg));
      }
    }
  }
  // Handle pub sub path
  for (String dirOrFile in dirsOrFiles) {
    if (FileSystemEntity.isDirectorySync(dirOrFile)) {
      dirs.add(dirOrFile);
    }

    String packageDir = getPubPackageRootSync(dirOrFile);
    if (packageDir != null) {
      await _parseDirectory(packageDir);
    }
  }

  // Also Handle recursive projects
  List<Future> futures = [];
  await recursivePubPath(dirs, dependencies: ['pubtest']).listen((String path) {
    //list.add(new PubPackage(path));
    futures.add(_parseDirectory(path));
  }).asFuture();
  await Future.wait(futures);

  //print(list.packages);
  for (TestPackage pkg in list.packages) {
    await packagePool.withResource(() async {
      await _handleProject(pkg, list.getTests(pkg));
    });
  }

  exit(exitCode);
}
