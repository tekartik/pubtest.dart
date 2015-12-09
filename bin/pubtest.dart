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
import 'package:pool/pool.dart';

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

class TestList {
  // empty list means all!
  Map<PubPackage, List<String>> all = {};
  add(PubPackage pkg, [String test]) {
    //print("$pkg $test");
    if (all.containsKey(pkg)) {
      List<String> tests = all[pkg];
      // if either is null, keep it null
      if (tests == null || test == null) {
        all[pkg] = null;
      } else {
        if (tests == null) {
          tests = [test];
        } else {
          tests.add(test);
        }
      }
    } else {
      if (test == null) {
        all[pkg] = null;
      } else {
        all[pkg] = [test];
      }
    }
  }

  Iterable<PubPackage> get packages => all.keys;

  List<String> getTests(PubPackage pkg) {
    return all[pkg];
  }

  @override
  String toString() => all.toString();
}

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
  parser.addFlag("version", help: 'Display the script version', negatable: false);
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

  TestList list = new TestList();

  int poolSize = int.parse(_argsResult[_CONCURRENCY]);
  int packagePoolSize = int.parse(_argsResult[_PACKAGE_CONCURRENCY]);

  Future _handleProject(PubPackage pkg, [List<String> files]) async {
    // if no file is given make sure the test/folder exists
    if (files == null) {
      // no tests found
      if (!(await FileSystemEntity.isDirectory(join(pkg.path, "test")))) {
        return;
      }
    }
    if (dryRun) {
      print('test on ${pkg.path}${files != null ? " ${files}": ""}');
    } else {
      try {
        List<String> args = [];
        if (files != null) {
          args.addAll(files);
        }
        ProcessResult result = await runCmd(pkg.testCmd(args,
            concurrency: poolSize,
            reporter: reporter,
            platforms: platforms,
            name: name)
          ..connectStderr = true
          ..connectStdout = true);
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

  // Handle pub sub path
  for (String dirOrFile in dirsOrFiles) {
    if (FileSystemEntity.isDirectorySync(dirOrFile)) {
      dirs.add(dirOrFile);
    }
    if (!isPubPackageRootSync(dirOrFile)) {
      String packageDir;
      try {
        packageDir = getPubPackageRootSync(dirOrFile);
      } catch (_) {}
      if (packageDir != null) {
        // if it is the test dir, assume testing the package instead

        if (yamlHasAnyDependencies(getPackageYaml(packageDir), ['test'])) {
          dirOrFile = relative(dirOrFile, from: packageDir);
          PubPackage pkg = new PubPackage(packageDir);
          if (dirOrFile == "test") {
            // add whole package
            list.add(pkg);
          } else {
            list.add(pkg, dirOrFile);
          }
        }
      }
    }
  }

  // Also Handle recursive projects
  await recursivePubPath(dirs, dependencies: ['test']).listen((String path) {
    list.add(new PubPackage(path));
  }).asFuture();

  //print(list.packages);
  for (PubPackage pkg in list.packages) {
    await packagePool.withResource(() async {
      await _handleProject(pkg, list.getTests(pkg));
    });
  }

  exit(exitCode);
}
