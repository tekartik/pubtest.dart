#!/usr/bin/env dart
library pubtest.bin.pubtest;

// Pull recursively

import 'dart:io';

import 'package:args/args.dart';
import 'package:process_run/cmd_run.dart';
import 'package:pubtest/src/pubtest_version.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_pub/io.dart';
import 'package:tekartik_sc/git.dart';

import 'pubtest.dart';

const String packageSourceOptionName = 'source';
const String sourceGit = "git";
const String sourcePath = "path";

List<String> getFiles(ArgResults argResults) {
  if (argResults.rest.length > 1) {
    return argResults.rest.sublist(1);
  }
  return null;
}

///
/// Recursively update (pull) git folders
///
Future main(List<String> arguments) async {
  ArgParser parser = new ArgParser(allowTrailingOptions: true);
  addArgs(parser);
  parser.addOption(packageSourceOptionName,
      abbr: 's',
      help: "package source",
      allowed: [sourceGit, sourcePath],
      allowMultiple: false);
  parser.addFlag(getOptionName,
      help: 'Get dependencies first (for path dependencies only)',
      negatable: false);
  ArgResults argResults = parser.parse(arguments);

  bool help = argResults[helpOptionName];
  if (help) {
    stdout.writeln("'pub run test' on some packages");
    stdout.writeln();
    stdout.writeln(
        'Usage: ${currentScriptName} [<source>] [<test-files>] [<arguments>]');
    stdout.writeln(
        'Example: ${currentScriptName} -sgit git://github.com/tekartik/tekartik_common_utils.dart');
    stdout.writeln();
    stdout.writeln("Global options:");
    stdout.writeln(parser.usage);
    return;
  }

  if (argResults['version']) {
    stdout.write('${currentScriptName} ${version}');
    return;
  }

  TestOptions testOptions = new TestOptions.fromArgResults(argResults);

  // Handle git package
  String source = argResults[packageSourceOptionName];
  if (source == sourceGit) {
    if (argResults.rest.length < 1) {
      stderr.writeln("Missing git source information");
      exit(1);
    }
    List<String> files = getFiles(argResults);
    // fix options
    if (testOptions.getBeforeOffline != true) {
      testOptions.getBefore = true;
    }

    String srcGit = argResults.rest[0];
    String dir =
        (await Directory.systemTemp.createTemp('${currentScriptName}')).path;
    GitProject git = new GitProject(srcGit, path: dir);

    // Cloning
    await runCmd(git.cloneCmd(progress: true), verbose: testOptions.verbose);

    // Pkg dir, no need to look higher
    if (!await isPubPackageRoot(dir)) {
      stderr.writeln("Git project '$srcGit' is not a pub package in '$dir'");
      exit(1);
    }
    PubPackage pkg = new PubPackage(dir);
    await testPackage(pkg, testOptions, files);
  } else if (source == sourcePath) {
    if (argResults.rest.length < 1) {
      stderr.writeln("Missing path source information");
      exit(1);
    }
    List<String> files = getFiles(argResults);

    String dir = argResults.rest[0];

    // Pkg dir, no need to look higher
    if (!await isPubPackageRoot(dir)) {
      stderr.writeln("Project in '$dir' is not a pub package");
      exit(1);
    }
    PubPackage pkg = new PubPackage(dir);
    await testPackage(pkg, testOptions, files);
  } else {
    stderr.writeln("Missing source (path or git)");
    exit(1);
  }
}
