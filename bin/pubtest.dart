#!/usr/bin/env dart
library pubtest.bin.pubtest;

// Pull recursively

import 'dart:async';
import 'package:path/path.dart';
import 'package:args/args.dart';
import 'package:tekartik_pub/pub_fs_io.dart';

import 'package:tekartik_pub/pub_fs.dart';
import 'package:fs_shim/utils/entity.dart';
import 'package:fs_shim/fs.dart' as fs;
import 'package:tekartik_pub/src/rpubpath_fs.dart';
import 'package:pubtest/src/pubtest_version.dart';
import 'package:pubtest/src/pubtest_utils.dart';
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

void addArgs(ArgParser parser) {
  parser.addFlag(_HELP, abbr: 'h', help: 'Usage help', negatable: false);
  //parser.addOption(_LOG, abbr: 'l', help: 'Log level (fine, debug, info...)');
  parser.addOption(_reporterOption,
      abbr: _reporterOptionAbbr,
      help: 'test result output',
      allowed: pubRunTestReporters);
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
  parser.addFlag("get-offline",
      help: 'Get dependencies first in offline mode', negatable: false);
}

///
/// Recursively update (pull) git folders
///
Future main(List<String> arguments) async {
  //setupQuickLogging();
  int exitCode = 0;

  ArgParser parser = new ArgParser(allowTrailingOptions: true);
  addArgs(parser);
  parser.addFlag("get", help: 'Get dependencies first', negatable: false);
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
  String reporter = _argsResult[_reporterOption];

  String name = _argsResult[_NAME];

  bool getBeforeOffline = _argsResult['get-offline'];
  bool getBefore = _argsResult['get'];
  // get dirs in parameters, default to current
  List<String> dirsOrFiles = new List.from(_argsResult.rest);
  if (dirsOrFiles.isEmpty) {
    dirsOrFiles = [Directory.current.path];
  }
  List<Directory> dirs = [];

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

  Future _handleProject(IoFsPubPackage pkg, [List<String> files]) async {
    // if no file is given make sure the test/folder exists
    if (files == null) {
      // no tests found
      if (!(await pkg.fs.isDirectory(childDirectory(pkg.dir, "test").path))) {
        return;
      }
    }
    if (dryRun) {
      print('test on ${pkg.dir}${files != null ? " ${files}": ""}');
    } else {
      try {
        List<String> args = [];
        if (files != null) {
          args.addAll(files);
        }
        if (getBefore || getBeforeOffline) {
          await pkg.runPub(pubGetArgs(offline: getBeforeOffline),
              connectStderr: true, connectStdout: true);
        }
        ProcessResult result = await pkg.runPub(
            pubRunTestArgs(
                args: args,
                concurrency: poolSize,
                reporter: reporter,
                platforms: platforms,
                name: name),
            connectStderr: true,
            connectStdout: true);
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
    Directory dir;
    if (await FileSystemEntity.isDirectory(dirOrFile)) {
      dir = new Directory(dirOrFile);
      dirs.add(dir);

      // Pkg dir, no need to look higher
      if (await isPubPackageDir(dir)) {
        continue;
      }
    } else {
      dir = new File(dirOrFile).parent;
    }

    Directory packageDir;
    try {
      packageDir = await getPubPackageDir(dir);
    } catch (_) {}
    if (packageDir != null) {
      // if it is the test dir, assume testing the package instead

      if (pubspecYamlHasAnyDependencies(
          await getPubspecYaml(packageDir), ['test'])) {
        dirOrFile = relative(dirOrFile, from: packageDir.path);
        IoFsPubPackage pkg = new IoFsPubPackage(packageDir);
        if (dirOrFile == "test") {
          // add whole package
          list.add(pkg);
        } else {
          list.add(pkg, dirOrFile);
        }
      }
    }
  }

  // Also Handle recursive projects
  await recursivePubDir(dirs, dependencies: ['test'])
      .listen((fs.Directory dir) {
    list.add(new IoFsPubPackage(dir));
  }).asFuture();

  //print(list.packages);
  for (FsPubPackage pkg in list.packages) {
    await packagePool.withResource(() async {
      await _handleProject(pkg, list.getTests(pkg));
    });
  }

  exit(exitCode);
}
