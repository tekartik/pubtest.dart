# tekartik_pubtest

Command line tools running `dart test` (or `flutter test`) across packages:

* `pubtest`: every package under the given folders that depends on `test` or
  `flutter_test`.
* `pubtestpackage`: one package, from a git url or a path.
* `pubtestdependencies`: the dependencies of a package (experimental).

Dart VM only (`dart:io`).

## Getting started

Not on pub.dev, add it as a git dev dependency:

```yaml
dev_dependencies:
  tekartik_pubtest:
    git:
      url: https://github.com/tekartik/pubtest.dart
```

```bash
# Every package of the current folder and below, on the vm
dart run tekartik_pubtest:pubtest
# One folder, two platforms, tests whose name contains 'sync'
dart run tekartik_pubtest:pubtest -p vm -p chrome -n sync packages
# One test file (its package is found)
dart run tekartik_pubtest:pubtest packages/db/test/sync_test.dart
# What would run, without running it
dart run tekartik_pubtest:pubtest --dry-run packages
```

Or activate it globally:
`dart pub global activate -s git https://github.com/tekartik/pubtest.dart`
(`pubtestpackage` and `pubtestdependencies` are then on the `PATH`, `pubtest`
runs with `dart pub global run tekartik_pubtest:pubtest`).

## pubtest

```text
Usage: pubtest [<folder_paths...>] [<arguments>]

Global options:
-h, --help                    Usage help
-r, --reporter                test result output
                              [compact, expanded, json]
-d, --dry-run                 Do not run test, simple show packages to be tested
    --version                 Display the script version
-v, --verbose                 Verbose mode
-j, --concurrency             Number of concurrent tests in the same package tested
                              (defaults to "10")
-k, --packageConcurrency      Number of concurrent packages tested
                              (defaults to "1")
-n, --name                    A substring of the name of the test to run
-p, --platform                The platform(s) on which to run the tests.
                              [vm (default), content-shell, chrome, phantomjs, firefox, safari, ie, node]
    --get-offline             Get dependencies first in offline mode
-f, --[no-]force-recursive    Force going recursive even in dart project
                              (defaults to on)
    --get                     Get dependencies first
```

* A folder is scanned recursively for packages depending on `test` or
  `flutter_test`. A test file, or a folder inside a package (`test/sub`),
  selects its package and that path.
* Without `-p`, the platforms can come from the environment:
  `PUBTEST_PLATFORMS=vm,chrome`.
* A Flutter package runs `flutter test --no-pub`, once per platform it
  supports (`vm`, `chrome`).
* The output of each package is printed once it is done (streamed with
  `-v`).
* Exit code: the first failing package stops the run, with a non zero exit
  code.
* `-k` and `-f` have no effect today: packages are tested one after the
  other, folders are always scanned recursively.

## pubtestpackage

```bash
# A package at the root of a git repository (shallow clone in a temp folder)
pubtestpackage -s git https://github.com/tekartik/common_utils.dart
# A local package, one test file
pubtestpackage -s path ../other_pkg test/a_test.dart
```

## pubtestdependencies

```bash
# The dependencies of the current package that have tests
pubtestdependencies
# Only one of them
pubtestdependencies --package-name process_run
```

Each dependency (or only those listed under a top level `test_dependencies:`
key of the `pubspec.yaml`) is copied to `build/test/<name>` (replacing the
previous copy), upgraded (`--get-offline` for an offline get instead) and
tested. The failing packages are listed and the exit code is 1.

## Common pitfalls

* Flutter packages are skipped (a message on stderr, exit code 0) when
  `flutter` is not found, or when no requested platform is supported by
  `flutter test` (`-p node`).
* `--version` prints an old internal version constant, not the package
  version.
* `pbrtest` (`build_runner test`) is no longer supported.

Agent skill: [skills/tekartik-pubtest-cli](skills/tekartik-pubtest-cli/SKILL.md).
