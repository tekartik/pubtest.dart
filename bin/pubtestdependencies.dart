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
const String packageOptionName = 'packageName';
const String _PLATFORM = 'platform';
const String _NAME = 'name';

bool _debug = false;

///
/// Recursively update (pull) git folders
///
Future main(List<String> arguments) async {
  ArgParser parser = new ArgParser(allowTrailingOptions: true);
  addArgs(parser);
  parser.addOption(packageOptionName,
      abbr: 'f',
      help: 'Filter dependencies by package name',
      allowMultiple: true);
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

  List<String> packageNames = argResults[packageOptionName];

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
    if (packageNames?.isNotEmpty == true) {
      if (!packageNames.contains(dependency.package.name)) {
        return;
      }
    }
    // Clone the project

    //await emptyOrCreateDirSync(pkg.path);

    String dst = join(
        dependency.parent.dir.path, 'build', 'test', dependency.package.name);

    //print(dependency);
    //print(dst);
    PubPackage pkg = await dependency.package.clone(dst);

    print('[pubtestdependencies] test on ${pkg}${files != null
            ? " ${files}"
            : ""}');

    // fix options - get needed
    testOptions.upgradeBefore = true;
    await testPackage(pkg, testOptions, files);
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
        if (pkg != null && pubspecYamlHasAnyDependencies(
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
