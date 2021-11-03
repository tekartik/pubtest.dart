# pubtest.dart

Helper to run pub test

[![Build Status](https://travis-ci.org/tekartik/pubtest.dart.svg?branch=master)](https://travis-ci.org/tekartik/pubtest.dart)

## Setup

pubspec.yaml:

```yaml
  tekartik_pubtest:
    git:
      url: https://github.com/tekartik/pubtest.dart
      ref: dart2_3
    version: '>=0.7.0'
```
## pubtest command

    pubtest

Allow testing all tests in one or multiple packages.

By default, Recursively run all test in all packages found. Packages are tested simultaneously (number can be configured using the -j option)
default is to test on vm platform, you can define multiple platforms in an env variable

    export PUBTEST_PLATFORMS=content-shell,vm

Usage

````
Call 'pub run test' recursively (default from current directory)

Usage: pubtest [<folder_paths...>] [<arguments>]

Global options:
-h, --help                  Usage help
-r, --reporter              test result output
                            [compact, expanded]

-d, --dry-run               Do not run test, simple show packages to be tested
    --version               Display the version
-j, --concurrency           Number of concurrent tests in the same package tested
                            (defaults to "10")

-k, --packageConcurrency    Number of concurrent packages tested
                            (defaults to "10")

-n, --name                  A substring of the name of the test to run
-p, --platform              The platform(s) on which to run the tests.
                            [vm (default), content-shell, chrome, phantomjs, firefox, safari, ie]
````

## pubtestdependencies

Experimental. Execute all declared dependencies test

    pubtestdependencies

```
# Test a single dependency
pubtestdependencies.dart --package-name process_run -v
```
    
## pubtestpackage

You can directly test a package even if you don't have it yet.
To specify a git packages to run your tests on:

    pubtestpackage -sgit https://github.com/tekartik/common_utils.dart
    

