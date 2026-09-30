---
name: tekartik-pubtest-cli
description: >-
  Use when running the tests of one or many Dart or Flutter packages from the
  command line with package:tekartik_pubtest (the pubtest, pubtestpackage and
  pubtestdependencies executables, dart run tekartik_pubtest:pubtest, dart pub
  global activate from git, -p/--platform, PUBTEST_PLATFORMS, -n/--name,
  -r/--reporter json, -j/--concurrency, -v/--verbose, -d/--dry-run, --get,
  --get-offline, -s git / -s path, --package-name, test_dependencies in
  pubspec.yaml), or when embedding or extending the runner in Dart (App,
  PubTestApp, CommonTestOptions, TestOptions, testPackage, runTest,
  commandText from package:tekartik_pubtest/bin/pubtest.dart). Covers package
  discovery, flutter packages, output visibility, exit codes and json output.
---

# pubtest: run `dart test` across packages

`tekartik_pubtest` (git only, not on pub.dev) ships three executables built
on `tekartik_pub` and `process_run`. `pubtest` finds every package that
depends on `test` or `flutter_test` under the given folders and runs
`dart test` (or `flutter test`) in each; `pubtestpackage` tests one package
fetched from a git url or taken from a path; `pubtestdependencies` copies
and tests the dependencies of a package. VM only.

```bash
dart run tekartik_pubtest:pubtest -v -p vm packages    # every package under packages/
```

## Guidelines

### Install

* Git dev dependency, then `dart run tekartik_pubtest:<executable>`:
  ```yaml
  dev_dependencies:
    tekartik_pubtest:
      git:
        url: https://github.com/tekartik/pubtest.dart
  ```
* `dart pub global activate -s git https://github.com/tekartik/pubtest.dart`
  puts `pubtestpackage` and `pubtestdependencies` on the `PATH` only: the
  `pubtest` entry of `executables:` is commented out. Run it globally with
  `dart pub global run tekartik_pubtest:pubtest`.
* `pbrtest` (`pub run build_runner test`) is still in `bin/` but no longer
  supported (its test is skipped). `--version` prints an internal constant
  (`pubtest 0.2.1`), not the pubspec version.

### pubtest: discovery and what runs

* Arguments are folders and/or test files, default the current directory.
  A folder is scanned recursively for packages whose `pubspec.yaml` depends
  on `test` or `flutter_test`, the folder itself included when it is a
  package; nested packages (`example/`) are found too, use `-d` to check
  the list. A test file selects its package and that file; `<pkg>/test`
  selects the whole package. Files of one package are grouped in a single
  `dart test` call. A package without `test/` is skipped unless files are
  given.
* Dart package: `dart test -j <concurrency> [-r <reporter>] [-p <platform>
  ...] [-n <name>] [files]`, run in the package directory. Flutter package
  (`flutter` dependency): `flutter test --no-pub [-j] [-n]`, platform and
  reporter ignored, skipped with a message on stderr when `flutter` is not
  installed.
* `-p/--platform` is repeatable (`-p vm -p chrome`), default `vm`; allowed
  values are the historical list (vm, content-shell, chrome, phantomjs,
  firefox, safari, ie, node), the obsolete ones fail inside `dart test`.
  Without `-p`, `PUBTEST_PLATFORMS=vm,chrome` in the environment is used
  (the legacy `TEKARTIK_RPUBTEST_PLATFORMS` wins when both are set).
* `--get` runs `dart pub get` (`flutter packages pub get`) in each package
  first, `--get-offline` the same with `--offline`; neither is the default.
* `-j/--concurrency` (default 10) is passed to `dart test -j`.
  `-k/--packageConcurrency` (default 1) and `-f/--force-recursive`
  (default on) are accepted but have no effect today: packages are always
  tested one after the other.
* Always pass `-v/--verbose`: without it the test runner output is captured
  and never shown, only `[<package dir>]` and the `$ dart test ...` line
  appear, for `-r json` as well. `-v` also prints `Scanning [...]`.
* `-d/--dry-run` prints `[dryRun] test on <dir> [files]` and the exact
  `$ dart test ...` line per package without running anything.
* Exit code: the first package whose `dart test` exits non-zero stops the
  run: `error thrown in <dir>`, `ERROR ShellException(...) in <dir>`, then
  the exception is unhandled and the process exits with 255. Later
  packages are not tested, so fix in order or narrow with paths and `-n`.
* `-r json` with `-v` streams the `dart test` json reporter lines;
  `pubRunTestJsonIsSuccess`, `pubRunTestJsonSuccessCount` and
  `pubRunTestJsonFailureCount` of `package:tekartik_pub/io.dart` parse that
  output.

### pubtestpackage: one package from git or a path

* `pubtestpackage -s git <url> [test files...] [options]`: shallow clone
  (`--depth 1`) into a temporary directory, `dart pub get` (offline with
  `--get-offline`), then the same test run as `pubtest`. The clone must be
  a pub package at its root (no `--git-path`), otherwise `Git project ...
  is not a pub package` and exit 1.
* `pubtestpackage -s path <dir> [test files...]`: tests the package in
  `dir`; nothing is fetched unless `--get` or `--get-offline`.
* Test files are relative to the package root. A missing `-s` prints
  `Missing source (path or git)` and exits 1.

### pubtestdependencies: test what you depend on

* `pubtestdependencies [<package dir>] [--package-name <name> ...]`: for
  each dependency declared in the package's `pubspec.yaml` (or only the
  names listed under a top level `test_dependencies:` list of that file)
  that itself depends on `test`, the resolved package is copied to
  `<package dir>/build/test/<name>`, `dart pub upgrade` is run there and
  its tests are executed. `--package-name` (repeatable) keeps only those
  names; an unknown name simply tests nothing.
* `test_dependencies: []` disables it for a package; the key absent means
  all dependencies. Experimental: a dependency is tested with an upgraded
  resolution, not the one locked by your package.

### Dart API: embed or extend the runner

* `package:tekartik_pubtest/bin/pubtest.dart` exports `main(arguments)`,
  the abstract `App` (`addArgs(parser)`, `main(arguments)`,
  `testPackage(pkg, options, [files])`, `runTest(pkg, args, options)`,
  `commandText`), `PubTestApp`, `CommonTestOptions.fromArgResults`,
  `TestOptions.fromArgResults`, `getPlatforms`, `allPlatforms` and the
  option name constants (`platformOptionName`, `getOptionName`...). It also
  re-exports `dart:io` (through `tekartik_io_utils`).
  `package:tekartik_pubtest/bin/pubtestpackage.dart` and
  `.../pubtestdependencies.dart` export their `main` only.
* Ship your own executable by re-exporting the library from
  `bin/pubtest.dart` (that is what `example/bin/pubtest.dart` does), or
  wrap `main` to inject arguments.
* To change what runs per package, subclass `App` and implement
  `commandText` and `runTest`; `App.main` keeps the argument parsing,
  discovery and `--get` handling, `testPackage` calls `runTest` once per
  package with the selected files (`null` files means the whole `test/`
  folder). `PbrTestApp` in `bin/pbrtest.dart` is the template. Honour
  `testOptions.dryRun` yourself.
* `TestOptions.fromArgResults` reads the `get` flag, which `App.main` adds
  after `addArgs`: a parser built by hand needs
  `parser.addFlag(getOptionName, negatable: false)` too, or it throws an
  `ArgumentError`.

## Examples

### Command line

```bash
dart run tekartik_pubtest:pubtest -v                         # this package and the ones below
dart run tekartik_pubtest:pubtest -v -p vm -p chrome packages
dart run tekartik_pubtest:pubtest -v -n sync packages/db/test/sync_test.dart
dart run tekartik_pubtest:pubtest -d packages                # list what would run
dart run tekartik_pubtest:pubtest -v --get -j 4 .
PUBTEST_PLATFORMS=vm,chrome dart run tekartik_pubtest:pubtest -v
dart run tekartik_pubtest:pubtestpackage -v -s git https://github.com/tekartik/common_utils.dart
dart run tekartik_pubtest:pubtestpackage -v -s path ../other_pkg test/a_test.dart
dart run tekartik_pubtest:pubtestdependencies -v --package-name synchronized
```

### bin/pubtest.dart: ship the runner in your own package

```dart
export 'package:tekartik_pubtest/bin/pubtest.dart';
```

### Run one package programmatically

```dart
import 'package:args/args.dart';
import 'package:tekartik_pub/io.dart';
import 'package:tekartik_pubtest/bin/pubtest.dart';

Future<void> main() async {
  var app = PubTestApp();
  var parser = ArgParser(allowTrailingOptions: true);
  app.addArgs(parser);
  // Added by App.main, TestOptions.fromArgResults reads it.
  parser.addFlag(getOptionName, negatable: false);
  var options = TestOptions.fromArgResults(
    parser.parse(['-v', '-p', 'vm', '-j', '4']),
  );
  // Files are relative to the package, null means the whole test/ folder.
  await app.testPackage(PubPackage('packages/my_pkg'), options, [
    'test/a_test.dart',
  ]);
}
```

### A runner that adds coverage to every package

```dart
import 'package:process_run/shell.dart';
import 'package:tekartik_pub/io.dart';
import 'package:tekartik_pubtest/bin/pubtest.dart';

class CoverageTestApp extends App {
  @override
  String get commandText => 'dart test --coverage';

  @override
  Future<void> runTest(
    PubPackage pkg,
    List<String> args,
    CommonTestOptions testOptions,
  ) async {
    var line = 'dart test --coverage=coverage ${shellArguments(args)}';
    if (testOptions.dryRun ?? false) {
      stdout.writeln('[dryRun] $line in ${pkg.path}');
      return;
    }
    await Shell(workingDirectory: pkg.path).run(line);
  }
}

// dart run tool/coverage_test.dart -v packages
Future<void> main(List<String> arguments) => CoverageTestApp().main(arguments);
```

### Parse the json reporter output

```dart
import 'package:process_run/shell.dart';
import 'package:tekartik_pub/io.dart';

Future<void> main() async {
  var shell = Shell(verbose: false, throwOnError: false);
  var results = await shell.run(
    'dart run tekartik_pubtest:pubtest -v -r json -p vm packages/my_pkg',
  );
  // Keep the json lines, drop the `[dir]` and `$ dart test` lines.
  var json = results.outLines.where((line) => line.startsWith('{')).join('\n');
  print('success: ${pubRunTestJsonIsSuccess(json)}');
  print(
    '${pubRunTestJsonSuccessCount(json)} passed, '
    '${pubRunTestJsonFailureCount(json)} failed',
  );
}
```

## Common mistakes

* Forgetting `-v`: the run looks silent and a failure only shows as
  `ShellException(... exitCode 1 ...)`, without the failing test names.
* Expecting `pubtest` on the `PATH` after `dart pub global activate`: only
  `pubtestpackage` and `pubtestdependencies` are exposed.
* Reading `pubtest --version` as the package version: it is a stale
  internal constant.
* Passing `-p chrome` to a Flutter package: platforms are ignored there,
  `flutter test` runs on the VM.
* Running `pubtestpackage -s git` on a mono repository url: the package
  must be at the repository root.
* Assuming `-k` runs packages in parallel: they are sequential; run several
  `pubtest` processes on disjoint folders instead.

## More

* Package README for the git dependency snippet and the original usage
  notes of the three executables.
