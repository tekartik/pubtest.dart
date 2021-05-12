import 'dart:io';

import 'package:args/args.dart';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_pub/io.dart';
import 'package:tekartik_pubtest/bin/pubtest.dart';
import 'package:tekartik_pubtest/src/pubtest_version.dart';
import 'package:tekartik_sc/git.dart';

const String packageSourceOptionName = 'source';
const String sourceGit = 'git';
const String sourcePath = 'path';

List<String>? getFiles(ArgResults argResults) {
  if (argResults.rest.length > 1) {
    return argResults.rest.sublist(1);
  }
  return null;
}

///
/// Recursively update (pull) git folders
///
Future main(List<String> arguments) async {
  final app = PubTestApp();

  final parser = ArgParser(allowTrailingOptions: true);
  app.addArgs(parser);
  parser.addOption(packageSourceOptionName,
      abbr: 's', help: 'package source', allowed: [sourceGit, sourcePath]);
  parser.addFlag(getOptionName,
      help: 'Get dependencies first (for path dependencies only)',
      negatable: false);
  final argResults = parser.parse(arguments);

  final help = parseBool(argResults[helpOptionName])!;
  if (help) {
    stdout.writeln("'pub run test' on some packages");
    stdout.writeln();
    stdout.writeln(
        'Usage: $currentScriptName [<source>] [<test-files>] [<arguments>]');
    stdout.writeln(
        'Example: $currentScriptName -sgit git://github.com/tekartik/tekartik_common_utils.dart');
    stdout.writeln();
    stdout.writeln('Global options:');
    stdout.writeln(parser.usage);
    return;
  }

  if (parseBool(argResults['version'])!) {
    stdout.write('$currentScriptName $version');
    return;
  }

  final testOptions = TestOptions.fromArgResults(argResults);

  // Handle git package
  final source = argResults[packageSourceOptionName] as String?;
  if (source == sourceGit) {
    if (argResults.rest.isEmpty) {
      stderr.writeln('Missing git source information');
      exit(1);
    }
    final files = getFiles(argResults);
    // fix options
    if (testOptions.getBeforeOffline != true) {
      testOptions.getBefore = true;
    }

    final srcGit = argResults.rest[0];
    final dir =
        (await Directory.systemTemp.createTemp('$currentScriptName')).path;
    final git = GitProject(srcGit, path: dir);

    // Cloning
    await runCmd(git.cloneCmd(progress: true, depth: 1),
        verbose: testOptions.verbose);

    // Pkg dir, no need to look higher
    if (!await isPubPackageRoot(dir)) {
      stderr.writeln("Git project '$srcGit' is not a pub package in '$dir'");
      exit(1);
    }
    final pkg = PubPackage(dir);
    await app.testPackage(pkg, testOptions, files);
  } else if (source == sourcePath) {
    if (argResults.rest.isEmpty) {
      stderr.writeln('Missing path source information');
      exit(1);
    }
    final files = getFiles(argResults);

    final dir = argResults.rest[0];

    // Pkg dir, no need to look higher
    if (!await isPubPackageRoot(dir)) {
      stderr.writeln("Project in '$dir' is not a pub package");
      exit(1);
    }
    final pkg = PubPackage(dir);
    await app.testPackage(pkg, testOptions, files);
  } else {
    stderr.writeln('Missing source (path or git)');
    exit(1);
  }
}
