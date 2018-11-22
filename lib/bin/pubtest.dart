#!/usr/bin/env dart
library tekartik_pubtest.bin.pubtest;

// Pull recursively

import 'dart:io';

import 'package:args/args.dart';
import 'package:fs_shim/utils/io/entity.dart';
import 'package:path/path.dart';
import 'package:pool/pool.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_pubtest/src/pubtest_utils.dart';
import 'package:tekartik_pubtest/src/pubtest_version.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_io_utils/io_utils_import.dart';
import 'package:tekartik_pub/io.dart';

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
const String reporterOptionName = "reporter";
const String reporterOptionAbbr = "r";
const String versionOptionName = "version";

const List<String> allPlatforms = const [
  "vm",
  "dartium",
  "content-shell",
  "chrome",
  "phantomjs",
  "firefox",
  "safari",
  "ie",
  "node"
];

class CommonTestOptions {
  bool verbose;
  bool getBeforeOffline;

  bool dryRun;
  RunTestReporter reporter;

  String name;

  List<String> platforms;

  int poolSize;

  // set by upper class
  bool getBefore;
  bool upgradeBefore;

  CommonTestOptions.fromArgResults(ArgResults argResults) {
    dryRun = argResults[dryRunOptionName] as bool;
    reporter =
        runTestReporterFromString(argResults[reporterOptionName] as String);

    name = argResults[nameOptionName] as String;

    getBeforeOffline = parseBool(argResults[getOfflineOptionName]);
    platforms = getPlatforms(argResults);
    poolSize = parseInt(argResults[concurrencyOptionName]);
    verbose = parseBool(argResults[verboseOptionName]);
  }
}

class TestOptions extends CommonTestOptions {
  TestOptions.fromArgResults(ArgResults argResults)
      : super.fromArgResults(argResults) {
    getBefore = parseBool(argResults[getOptionName]);
  }
}

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
  parser.addFlag("version",
      help: 'Display the script version', negatable: false);
  parser.addFlag("verbose", abbr: 'v', help: 'Verbose mode', negatable: false);
  parser.addOption(concurrencyOptionName,
      abbr: 'j',
      help: 'Number of concurrent tests in the same package tested',
      defaultsTo: '10');
  parser.addOption(packageConcurrencyOptionName,
      abbr: 'k', help: 'Number of concurrent packages tested', defaultsTo: '1');
  parser.addOption(nameOptionName,
      abbr: 'n', help: 'A substring of the name of the test to run');
  parser.addMultiOption(platformOptionName,
      abbr: 'p',
      help: 'The platform(s) on which to run the tests.',
      allowed: allPlatforms,
      defaultsTo: ['vm']);
  parser.addFlag(getOfflineOptionName,
      help: 'Get dependencies first in offline mode', negatable: false);
}

///
/// Recursively update (pull) git folders
///
Future main(List<String> arguments) async {
  //setupQuickLogging();

  ArgParser parser = new ArgParser(allowTrailingOptions: true);
  addArgs(parser);
  parser.addFlag(getOptionName,
      help: 'Get dependencies first', negatable: false);
  ArgResults argResults = parser.parse(arguments);

  bool help = parseBool(argResults[helpOptionName]);
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

  if (parseBool(argResults[versionOptionName])) {
    stdout.write('${currentScriptName} ${version}');
    return;
  }

  // get dirs in parameters, default to current
  List<String> dirsOrFiles = new List.from(argResults.rest);
  if (dirsOrFiles.isEmpty) {
    dirsOrFiles = [Directory.current.path];
  }
  List<String> dirs = [];

  TestList list = new TestList();

  TestOptions testOptions = new TestOptions.fromArgResults(argResults);

  int packagePoolSize = parseInt(argResults[packageConcurrencyOptionName]);

  Pool packagePool = new Pool(packagePoolSize);

  // Handle pub sub path
  for (String dirOrFile in dirsOrFiles) {
    Directory dir;
    if (await FileSystemEntity.isDirectory(dirOrFile)) {
      dirs.add(dirOrFile);

      // Pkg dir, no need to look higher
      if (await isPubPackageRoot(dirOrFile)) {
        continue;
      }
    } else {
      dir = new File(dirOrFile).parent;
    }

    String packageDir;
    try {
      packageDir = await getPubPackageRoot(dir.path);
    } catch (_) {}
    if (packageDir != null) {
      // if it is the test dir, assume testing the package instead

      if (pubspecYamlHasAnyDependencies(
          await getPubspecYaml(packageDir), ['test'])) {
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

  // Also Handle recursive projects
  await recursivePubPath(dirs, dependencies: ['test']).listen((String dir) {
    list.add(new PubPackage(dir));
  }).asFuture();

  //print(list.packages);
  for (PubPackage pkg in list.packages) {
    await packagePool.withResource(() async {
      await testPackage(pkg, testOptions, list.getTests(pkg));
    });
  }

  //devErr("exitCode: $exitCode");
}

List<String> getPlatforms(ArgResults _argsResult) {
  List<String> platforms;
  if (_argsResult.wasParsed(platformOptionName)) {
    platforms = _argsResult[platformOptionName] as List<String>;
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
  return platforms;
}

Future testPackage(PubPackage pkg, CommonTestOptions testOptions,
    [List<String> files]) async {
  // if no file is given make sure the test/folder exists
  if (files == null) {
    // no tests found
    if (!(await FileSystemEntity.isDirectory(
        childDirectory(pkg.dir, "test").path))) {
      return;
    }
  }
  if (testOptions.dryRun) {
    print('[dryRun] test on ${pkg.dir}${files != null ? " ${files}" : ""}');
  }
  try {
    List<String> args = [];
    if (files != null) {
      args.addAll(files);
    }

    if (testOptions.upgradeBefore == true) {
      ProcessCmd cmd = pkg.pubCmd(pubUpgradeArgs());
      if (testOptions.dryRun) {
        print('\$ $cmd');
      } else {
        await runCmd(cmd, verbose: testOptions.verbose);
      }
    } else if (testOptions.getBefore || testOptions.getBeforeOffline) {
      ProcessCmd cmd =
          pkg.pubCmd(pubGetArgs(offline: testOptions.getBeforeOffline));
      if (testOptions.dryRun) {
        print('\$ $cmd');
      } else {
        await runCmd(cmd, verbose: testOptions.verbose);
      }
    }

    ProcessCmd testCmd = pkg.pubCmd(pubRunTestArgs(
        args: args,
        concurrency: testOptions.poolSize,
        reporter: testOptions.reporter,
        platforms: testOptions.platforms,
        name: testOptions.name));
    if (testOptions.dryRun) {
      print('\$ $testCmd');
    } else {
      ProcessResult result =
          await runCmd(testCmd, stdout: stdout, stderr: stderr);
      if (result.exitCode != 0) {
        stderr.writeln('test error in ${pkg}');
        if (exitCode == 0) {
          exitCode = result.exitCode;
        }
      }
    }
  } catch (e) {
    stderr.writeln('error thrown in ${pkg}');
    stderr.flush();
    throw e;
  }
}
