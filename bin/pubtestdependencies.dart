#!/usr/bin/env dart

library tekartik_pubtest.bin.pubtestdependencies;

// Pull recursively
import 'dart:async';

import 'package:args/args.dart';
import 'package:path/path.dart';
import 'package:pool/pool.dart';
import 'package:tekartik_io_utils/io_utils_import.dart';
import 'package:tekartik_pubtest/bin/pubtest.dart';
import 'package:tekartik_pubtest/src/pubtest_utils.dart';
import 'package:tekartik_pubtest/src/pubtest_version.dart';
import 'package:tekartik_pub/io.dart';

String get currentScriptName => basenameWithoutExtension(Platform.script.path);

const String helpFlag = 'help';
//const String _LOG = 'log';
const String packageNameOption = 'package-name';

///
/// Recursively update (pull) git folders
///
Future main(List<String> arguments) async {
  final app = PubTestApp();
  final parser = ArgParser(allowTrailingOptions: true);
  app.addArgs(parser);
  parser.addMultiOption(
    packageNameOption,
    help: 'Filter dependencies by package name',
  );
  final argResults = parser.parse(arguments);

  final help = parseBool(argResults[helpFlag]);
  if (help) {
    stdout.writeln(
        "Call 'pub run test' recursively (default from current directory)");
    stdout.writeln();
    stdout.writeln(
        'Usage: ${currentScriptName} [<folder_paths...>] [<arguments>]');
    stdout.writeln();
    stdout.writeln('Global options:');
    stdout.writeln(parser.usage);
    return;
  }

  if (parseBool(argResults['version'])) {
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

  final testOptions = CommonTestOptions.fromArgResults(argResults);

  final packageNames = argResults[packageNameOption] as List<String>;

  // get dirs in parameters, default to current
  var dirsOrFiles = List<String>.from(argResults.rest);
  if (dirsOrFiles.isEmpty) {
    dirsOrFiles = [Directory.current.path];
  }
  final dirs = <Directory>[];

  //PubTest pubTest = new PubTest();
  final list = NewTestList();

  final packagePoolSize = parseInt(argResults[packageConcurrencyOptionName]);

  final errors = <PubPackage>[];
  Future _handleProject(DependencyTestPackage dependency,
      [List<String> files]) async {
    if (packageNames?.isNotEmpty == true) {
      if (!packageNames.contains(dependency.package.name)) {
        return;
      }
    }
    // Clone the project

    //await emptyOrCreateDirSync(pkg.path);

    final dst = join(
        dependency.parent.dir.path, 'build', 'test', dependency.package.name);

    //print(dependency);
    //print(dst);
    final pkg = await dependency.package.clone(dst);

    print(
        '[pubtestdependencies] test on ${pkg}${files != null ? ' ${files}' : ''}');

    // fix options - get needed
    testOptions.upgradeBefore = true;
    await app.testPackage(pkg, testOptions, files);
  }

  final packagePool = Pool(packagePoolSize);

  Future _parseDirectory(String packageDir) async {
    //int w; print('#parsing $packageDir');
    final parent = PubPackage(packageDir);

    // get the test_dependencies first
    final dependencies = pubspecYamlGetTestDependenciesPackageName(
            await parent.getPubspecYaml()) ??
        await parent.extractPubspecDependencies();

    //Map dotPackagesYaml = await getDotPackagesYaml(mainPackage.path);
    if (dependencies != null) {
      for (final dependency in dependencies) {
        final pkg = await parent.extractPackage(dependency);
        //print(parent);
        if (pkg != null &&
            pubspecYamlHasAnyDependencies(
                await pkg.getPubspecYaml(), ['test'])) {
          // add whole package
          list.add(DependencyTestPackage(parent, pkg));
        }
      }
    }
  }

  // Handle pub sub path
  for (final dirOrFile in dirsOrFiles) {
    if (FileSystemEntity.isDirectorySync(dirOrFile)) {
      dirs.add(Directory(dirOrFile));
    }

    final packageDir = await getPubPackageRoot(dirOrFile);
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
  for (final pkg in list.packages) {
    await packagePool.withResource(() async {
      await _handleProject(pkg as DependencyTestPackage, list.getTests(pkg));
    });
  }

  if (exitCode != 0) {
    stderr.writeln('errors in packages: ${errors}');
    await stderr.flush();
  }
}
