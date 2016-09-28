#!/usr/bin/env dart
library pubtest.bin.pubtest;

// Pull recursively

import 'package:fs_shim/fs_io.dart';
import 'dart:async';
import 'package:path/path.dart';
import 'package:args/args.dart';
import 'package:tekartik_pub/io.dart';
import 'package:pubtest/src/pubtest_version.dart';
import 'package:pubtest/src/pubtest_utils.dart';
import 'package:pool/pool.dart';
import 'pubtest.dart';
import 'package:process_run/cmd_run.dart';

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

///
/// Recursively update (pull) git folders
///
Future main(List<String> arguments) async {
  //setupQuickLogging();
  int exitCode = 0;

  ArgParser parser = new ArgParser(allowTrailingOptions: true);
  /*
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
  parser.addFlag("get-offline",
      help: 'Get dependencies in offline mode', negatable: false);
  parser.addOption(_PLATFORM,
      abbr: 'p',
      help: 'The platform(s) on which to run the tests.',
      allowed: allPlatforms,
      defaultsTo: 'vm',
      allowMultiple: true);*/
  addArgs(parser);
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

  //PubTest pubTest = new PubTest();
  NewTestList list = new NewTestList();

  bool getOffline = _argsResult['get-offline'];
  int poolSize = int.parse(_argsResult[_CONCURRENCY]);
  int packagePoolSize = int.parse(_argsResult[_PACKAGE_CONCURRENCY]);

  List<PubPackage> errors = [];
  Future _handleProject(DependencyTestPackage dependency,
      [List<String> files]) async {
    // Clone the project

    //await emptyOrCreateDirSync(pkg.path);

    String dst = join(
        dependency.parent.dir.path, 'build', 'test', dependency.package.name);
    /*
    try {
      await dst.delete(recursive: true);
    } catch (_) {}
    try {
      await dst.create(recursive: true);
    } catch (_) {}
    /*
    await cloneFiles(dependency.package.path, pkg.path,
        but: ['packages', '.packages', '.pub', 'pubspec.lock', 'build'],
        copy: true);
        */
    await copyFileSystemEntity(
        fs.ioFileSystem.newDirectory(dependency.package.path), dst,
        options: new CopyOptions(
            recursive: true,
            exclude: [
              'packages',
              '.packages',
              '.pub',
              'pubspec.lock',
              'build'
            ]));
    */

    //print(dependency);
    //print(dst);
    PubPackage pkg = await dependency.package.clone(dst);

    await runCmd(pkg.pubCmd(pubGetArgs(offline: getOffline)));

    // if no file is given make sure the test/folder exists
    if (files == null) {
      // no tests found
      if (!(await FileSystemEntity.isDirectory(join(pkg.dir.path, "test")))) {
        return;
      }
    }
    print('test on ${pkg}${files != null ? " ${files}": ""}');
    if (dryRun) {
      //print('test on ${pkg}${files != null ? " ${files}": ""}');
    } else {
      try {
        List<String> args = [];
        if (files != null) {
          args.addAll(files);
        }

        ProcessResult result = await runCmd(pkg.pubCmd(
            pubRunTestArgs(
                args: args,
                concurrency: poolSize,
                reporter: reporter,
                platforms: platforms,
                name: name)), verbose: true);
        if (result.exitCode != 0) {
          errors.add(pkg);
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

  Future _parseDirectory(String packageDir) async {
    //int w; print("#parsing $packageDir");
    PubPackage parent = new PubPackage(packageDir);

    // get the test_dependencies first
    Iterable<String> dependencies = pubspecYamlGetTestDependenciesPackageName(
        await parent.getPubspecYaml());

    if (dependencies == null) {
      dependencies = await parent.extractPubspecDependencies();
    }

    //Map dotPackagesYaml = await getDotPackagesYaml(mainPackage.path);
    if (dependencies != null) {
      for (String dependency in dependencies) {
        PubPackage pkg = await parent.extractPackage(dependency);
        //print(parent);
        if (pubspecYamlHasAnyDependencies(
            await pkg.getPubspecYaml(), ['test'])) {
          // add whole package
          list.add(new DependencyTestPackage(parent, pkg));
        }
      }
    }
  }
  // Handle pub sub path
  for (String dirOrFile in dirsOrFiles) {
    if (await FileSystemEntity.isDirectory(dirOrFile)) {
      dirs.add(new Directory(dirOrFile));
    }

    String packageDir = await getPubPackageRoot(dirOrFile);
    if (packageDir != null) {
      await _parseDirectory(packageDir);
    }
  }

  /*
  // Also Handle recursive projects
  List<Future> futures = [];
  int w;
  print('#1 ${list.packages}');
  void _add(fs.Directory dir) {
    print('adding $dir'); int warn;
    futures.add(_parseDirectory(dir));
  }
  await recursivePubDir(dirs, dependencies: ['pubtest'])
      .listen(_add)
      .asFuture();
  await Future.wait(futures);
int _w2;
*/
  //int _w2; print('#2 ${list.packages}');
  for (TestPackage pkg in list.packages) {
    await packagePool.withResource(() async {
      await _handleProject(pkg, list.getTests(pkg));
    });
  }

  if (exitCode != 0) {
    stderr.writeln('errors in packages: ${errors}');
    stderr.flush();
  }
  exit(exitCode);
}
