# pubtest.dart

Helper to run pub run

## rpubtest command

    pubtest

Recursively run all test in all packages found. Packages are tested simultaneously (number can be configured using the -j option)
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
                            [vm (default), dartium, content-shell, chrome, phantomjs, firefox, safari, ie]
````

## Activation

### From git repository

    pub global activate -s git git://github.com/tekartik/pubtest.dart

### From local path

    pub global activate -s path .


