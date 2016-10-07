#!/usr/bin/env dart
library pubtest.bin.pubtest;

// Pull recursively
import 'dart:async';

import 'package:args/args.dart';
import 'package:path/path.dart';
import 'package:pool/pool.dart';
import 'package:pubtest/src/pubtest_utils.dart';
import 'package:pubtest/src/pubtest_version.dart';
import 'package:tekartik_pub/io.dart';

import 'pubtest.dart';

String get currentScriptName => basenameWithoutExtension(Platform.script.path);

const String _HELP = 'help';
//const String _LOG = 'log';
const String _DRY_RUN = 'dry-run';
const String _CONCURRENCY = 'concurrency';
const String packageConcurrencyOptionName = 'packageConcurrency';
const String _PLATFORM = 'platform';
const String _NAME = 'name';
const String _reporterOption = "reporter";
const String _reporterOptionAbbr = "r";

bool _debug = false;

///
/// Recursively update (pull) git folders
///
Future main(List<String> arguments) async {
  ArgParser parser = new ArgParser(allowTrailingOptions: true);
  addArgs(parser);
  ArgResults argResults = parser.parse(arguments);

  bool help = argResults[_HELP];
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

  if (argResults['version']) {
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

  CommonTestOptions testOptions =
  new CommonTestOptions.fromArgResults(argResults);

  // get dirs in parameters, default to current
  List<String> dirsOrFiles = new List.from(argResults.rest);
  if (dirsOrFiles.isEmpty) {
    dirsOrFiles = [Directory.current.path];
  }
  List<Directory> dirs = [];

  //PubTest pubTest = new PubTest();
  NewTestList list = new NewTestList();

  int packagePoolSize = int.parse(argResults[packageConcurrencyOptionName]);

  List<PubPackage> errors = [];
  Future _handleProject(DependencyTestPackage dependency,
      [List<String> files]) async {
    // Clone the project

    //await emptyOrCreateDirSync(pkg.path);

    String dst = join(
        dependency.parent.dir.path, 'build', 'test', dependency.package.name);

    //print(dependency);
    //print(dst);
    PubPackage pkg = await dependency.package.clone(dst);

    print(
        '[pubtestdependencies] test on ${pkg}${files != null
            ? " ${files}"
            : ""}');

    // fix options - get needed
    testOptions.getBefore = true;
    await testPackage(pkg, testOptions, files);

    /*
    await runCmd(pkg.pubCmd(pubGetArgs(offline: testOptions.getBeforeOffline)));

    // if no file is given make sure the test/folder exists
    if (files == null) {
      // no tests found
      if (!(await FileSystemEntity.isDirectory(join(pkg.dir.path, "test")))) {
        return;
      }
    }
    print('test on ${pkg}${files != null ? " ${files}": ""}');
    if (testOptions.dryRun) {
      //print('test on ${pkg}${files != null ? " ${files}": ""}');
    } else {
      try {
        List<String> args = [];
        if (files != null) {
          args.addAll(files);
        }

        ProcessResult result = await runCmd(
            pkg.pubCmd(pubRunTestArgs(
                args: args,
                concurrency: testOptions.poolSize,
                reporter: testOptions.reporter,
                platforms: platforms,
                name: testOptions.name)),
            verbose: true);
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
    */
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
}
