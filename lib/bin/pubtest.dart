import 'package:args/args.dart';
import 'package:fs_shim/utils/io/entity.dart';
import 'package:path/path.dart';
import 'package:pool/pool.dart';
import 'package:process_run/cmd_run.dart' hide runCmd;
import 'package:process_run/shell_run.dart';
import 'package:tekartik_io_utils/io_utils_import.dart';
//import 'package:tekartik_io_utils/process_cmd_utils.dart';
import 'package:tekartik_pub/io.dart';
import 'package:tekartik_pubtest/src/pubtest_utils.dart';
import 'package:tekartik_pubtest/src/pubtest_version.dart';
import 'package:tekartik_pubtest/src/run_cmd.dart';

export 'package:tekartik_io_utils/io_utils_import.dart';

String get currentScriptName => basenameWithoutExtension(Platform.script.path);

const String helpOptionName = 'help';
const String verboseOptionName = 'verbose';
//const String _LOG = 'log';
const String dryRunOptionName = 'dry-run';
const String concurrencyOptionName = 'concurrency';
const String packageConcurrencyOptionName = 'packageConcurrency';
const String platformOptionName = 'platform';
const String nameOptionName = 'name';
const String getOptionName = 'get';
const String getOfflineOptionName = 'get-offline';
const String reporterOptionName = 'reporter';
const String reporterOptionAbbr = 'r';
const String versionOptionName = 'version';
const String argForceRecursiveFlag = 'force-recursive';

const List<String> allPlatforms = [
  'vm',
  'content-shell',
  'chrome',
  'phantomjs',
  'firefox',
  'safari',
  'ie',
  'node'
];

class CommonTestOptions {
  bool? forceRecursive;
  bool? verbose;
  bool? getBeforeOffline;

  bool? dryRun;
  RunTestReporter? reporter;

  String? name;

  List<String>? platforms;

  int? poolSize;

  // set by upper class
  bool? getBefore;
  bool? upgradeBefore;

  CommonTestOptions.fromArgResults(ArgResults argResults) {
    dryRun = argResults[dryRunOptionName] as bool?;
    reporter = argResults[reporterOptionName] == null
        ? null
        : runTestReporterFromString(argResults[reporterOptionName] as String);

    name = argResults[nameOptionName] as String?;

    getBeforeOffline = parseBool(argResults[getOfflineOptionName]);
    platforms = getPlatforms(argResults);
    poolSize = parseInt(argResults[concurrencyOptionName]);
    verbose = parseBool(argResults[verboseOptionName], false);
  }

  Map<String, dynamic> toDebugMap() =>
      <String, dynamic>{if (verbose ?? false) 'verbose': verbose};
  @override
  String toString() => toDebugMap().toString();
}

class TestOptions extends CommonTestOptions {
  TestOptions.fromArgResults(ArgResults argResults)
      : super.fromArgResults(argResults) {
    getBefore = parseBool(argResults[getOptionName]);
    forceRecursive = parseBool(argResults[argForceRecursiveFlag], false);
  }
}

List<String>? getPlatforms(ArgResults argsResult) {
  List<String>? platforms;
  if (argsResult.wasParsed(platformOptionName)) {
    platforms = argsResult[platformOptionName] as List<String>?;
  } else {
    // Allow platforms in env variable
    var envPlatforms = Platform.environment['PUBTEST_PLATFORMS'];
    if (envPlatforms != null) {
      stdout.writeln('Using platforms: $envPlatforms');
      platforms = envPlatforms.split(',');
    }
    // compatiblity with previous rpubtest
    envPlatforms = Platform.environment['TEKARTIK_RPUBTEST_PLATFORMS'];
    if (envPlatforms != null) {
      stdout.writeln('Using platforms: $envPlatforms');
      platforms = envPlatforms.split(',');
    }
  }
  return platforms;
}

class PubTestApp extends App {
  @override
  Future runTest(
      PubPackage pkg, List<String> args, CommonTestOptions testOptions) async {
    if (await isFlutterPackageRoot(pkg.path)) {
      if (!isFlutterSupported) {
        stderr.writeln('flutter not supported for package in $pkg');
        return;
      }
      // Flutter way
      var args = ['test', '--no-pub'];
      if (testOptions.poolSize != null) {
        args.addAll(['-j', '${testOptions.poolSize}']);
      }
      if (testOptions.name != null) {
        args.addAll(['-n', testOptions.name!]);
      }
      var cmd = FlutterCmd(args)..workingDirectory = pkg.path;

      await runCmd(cmd,
          dryRun: testOptions.dryRun, verbose: testOptions.verbose);
    } else {
      var testCmd = ProcessCmd('dart', [
        'test',
        ...pubRunTestRunnerArgs(TestRunnerArgs(
            args: args,
            concurrency: testOptions.poolSize,
            reporter: testOptions.reporter,
            platforms: testOptions.platforms,
            name: testOptions.name))
      ]);
      if (testOptions.dryRun ?? false) {
        await runCmd(testCmd,
            dryRun: testOptions.dryRun, verbose: testOptions.verbose);
      } else {
        var shell = Shell(
            workingDirectory: pkg.path,
            commandVerbose: true,
            verbose: testOptions.verbose!);
        stdout.writeln('[${pkg.path}]');
        await shell.runExecutableArguments(
            testCmd.executable, testCmd.arguments);
      }
    }
  }

  @override
  String get commandText => 'pub run test';
}

abstract class App {
  void addArgs(ArgParser parser) {
    parser.addFlag(helpOptionName,
        abbr: 'h', help: 'Usage help', negatable: false);
    //parser.addOption(_LOG, abbr: 'l', help: 'Log level (fine, debug, info...)');
    parser.addOption(reporterOptionName,
        abbr: reporterOptionAbbr,
        help: 'test result output',
        allowed: pubRunTestReporters);
    parser.addFlag(dryRunOptionName,
        abbr: 'd',
        help: 'Do not run test, simple show packages to be tested',
        negatable: false);
    parser.addFlag('version',
        help: 'Display the script version', negatable: false);
    parser.addFlag(verboseOptionName,
        abbr: 'v', help: 'Verbose mode', negatable: false);
    parser.addOption(concurrencyOptionName,
        abbr: 'j',
        help: 'Number of concurrent tests in the same package tested',
        defaultsTo: '10');
    parser.addOption(packageConcurrencyOptionName,
        abbr: 'k',
        help: 'Number of concurrent packages tested',
        defaultsTo: '1');
    parser.addOption(nameOptionName,
        abbr: 'n', help: 'A substring of the name of the test to run');
    parser.addMultiOption(platformOptionName,
        abbr: 'p',
        help: 'The platform(s) on which to run the tests.',
        allowed: allPlatforms,
        defaultsTo: ['vm']);
    parser.addFlag(getOfflineOptionName,
        help: 'Get dependencies first in offline mode', negatable: false);
    parser.addFlag(argForceRecursiveFlag,
        abbr: 'f',
        help: 'Force going recursive even in dart project',
        defaultsTo: true);
  }

  /// different for pubtest and pbrtest
  String get commandText;

  ///
  /// Recursively update (pull) git folders
  ///
  Future main(List<String> arguments) async {
    //setupQuickLogging();

    final parser = ArgParser(allowTrailingOptions: true);
    addArgs(parser);
    parser.addFlag(getOptionName,
        help: 'Get dependencies first', negatable: false);
    final argResults = parser.parse(arguments);

    final help = parseBool(argResults[helpOptionName])!;
    if (help) {
      stdout.writeln(
          "Call '$commandText' recursively (default from current directory)");
      stdout.writeln();
      stdout.writeln(
          'Usage: $currentScriptName [<folder_paths...>] [<arguments>]');
      stdout.writeln();
      stdout.writeln('Global options:');
      stdout.writeln(parser.usage);
      return;
    }

    if (parseBool(argResults[versionOptionName])!) {
      stdout.write('$currentScriptName $version');
      return;
    }

    // get dirs in parameters, default to current
    var dirsOrFiles = List<String>.from(argResults.rest);
    if (dirsOrFiles.isEmpty) {
      dirsOrFiles = [Directory.current.path];
    }
    final dirs = <String>[];

    final list = TestList();

    final testOptions = TestOptions.fromArgResults(argResults);

    final packagePoolSize = parseInt(argResults[packageConcurrencyOptionName])!;

    final packagePool = Pool(packagePoolSize);

    if (testOptions.verbose!) {
      stdout.writeln('Scanning $dirsOrFiles');
    }
    // Handle pub sub path
    for (var dirOrFile in dirsOrFiles) {
      late Directory dir;
      if (FileSystemEntity.isDirectorySync(dirOrFile)) {
        dirs.add(dirOrFile);

        // Pkg dir, no need to look higher
        if (await isPubPackageRoot(dirOrFile)) {
          continue;
        }
      } else {
        dir = File(dirOrFile).parent;
      }

      String? packageDir;
      try {
        packageDir = await getPubPackageRoot(dir.path);
      } catch (_) {}
      if (packageDir != null) {
        // if it is the test dir, assume testing the package instead

        if (pubspecYamlHasAnyDependencies(
            (await getPubspecYaml(packageDir))!, ['test'])) {
          dirOrFile = relative(dirOrFile, from: packageDir);
          final pkg = PubPackage(packageDir);
          if (dirOrFile == 'test') {
            // add whole package
            list.add(pkg);
          } else {
            list.add(pkg, dirOrFile);
          }
        }
      }
    }

    // Also Handle recursive projects
    await recursivePubPath(dirs,
            dependencies: ['test', 'flutter_test'],
            forceRecursive: testOptions.forceRecursive)
        .listen((String dir) {
      // devPrint('adding $dir');
      list.add(PubPackage(dir));
    }).asFuture<void>();

    // devPrint(list.packages);
    for (final pkg in list.packages) {
      // devPrint(pkg);
      await packagePool.withResource(() async {
        try {
          await testPackage(pkg, testOptions, list.getTests(pkg));
        } catch (e) {
          stderr.writeln('ERROR $e in $pkg');
          rethrow;
        }
      });
    }

    //devErr('exitCode: $exitCode');
  }

  Future testPackage(PubPackage pkg, CommonTestOptions testOptions,
      [List<String>? files]) async {
    // if no file is given make sure the test/folder exists
    if (files == null) {
      // no tests found
      if (!(FileSystemEntity.isDirectorySync(
          childDirectory(pkg.dir, 'test').path))) {
        return;
      }
    }
    if (testOptions.dryRun!) {
      print('[dryRun] test on ${pkg.dir}${files != null ? ' $files' : ''}');
    }
    try {
      final args = <String>[];
      if (files != null) {
        args.addAll(files);
      }

      if (testOptions.upgradeBefore == true) {
        if (await isFlutterPackageRoot(pkg.path)) {
          if (!isFlutterSupported) {
            stderr.writeln('flutter not supported for package in $pkg');
            return;
          }
          // Flutter way
          var cmd = FlutterCmd(['packages', 'pub', 'upgrade'])
            ..workingDirectory = pkg.path;
          await runCmd(cmd,
              dryRun: testOptions.dryRun, verbose: testOptions.verbose);
        } else {
          // Regular dart
          var cmd = pkg.pubCmd(pubUpgradeArgs());
          await runCmd(cmd,
              dryRun: testOptions.dryRun, verbose: testOptions.verbose);
        }
      } else if (testOptions.getBefore! || testOptions.getBeforeOffline!) {
        if (await isFlutterPackageRoot(pkg.path)) {
          if (!isFlutterSupported) {
            stderr.writeln('flutter not supported for package in $pkg');
            return;
          }
          // Flutter way
          var args = ['packages', 'pub', 'get'];
          if (testOptions.getBeforeOffline!) {
            args.add('--offline');
          }
          var cmd = FlutterCmd(args)..workingDirectory = pkg.path;
          await runCmd(cmd,
              dryRun: testOptions.dryRun, verbose: testOptions.verbose);
        } else {
          // Regular dart
          var cmd =
              pkg.pubCmd(pubGetArgs(offline: testOptions.getBeforeOffline));

          await runCmd(cmd,
              dryRun: testOptions.dryRun, verbose: testOptions.verbose);
        }
      }

      await runTest(pkg, args, testOptions);
    } catch (e) {
      stderr.writeln('error thrown in $pkg');
      await stderr.flush();
      rethrow;
    }
  }

  Future runTest(
      PubPackage pkg, List<String> args, CommonTestOptions testOptions);
}

///
/// Recursively update (pull) git folders
///
Future main(List<String> arguments) async {
  final app = PubTestApp();
  return app.main(arguments);
}
