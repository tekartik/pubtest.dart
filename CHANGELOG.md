# Changelog

## 0.7.2

* `pubtest <dir>` with a directory inside a package (i.e. `test/sub`) tests it (nothing was tested)
* flutter packages: the test files, platforms (vm, chrome) and reporter are passed to `flutter test`
* command output is printed once, also when not verbose (`dart test` output was hidden unless `-v`)
* `pubtestdependencies` finds dependencies from `.dart_tool/package_config.json` (nothing was found
  since Dart 3), `--dry-run` no longer clones, `--get-offline` is honored, failing packages are
  listed and the exit code is 1

## 0.7.1

* Add `tekartik-pubtest-cli` agent skill in `skills/`, installable with `dart run skills@ get`

## 0.6.3

* add `pbrtest`

## 0.4.0

* strong mode support
## 0.2.3

* Force upgrade in pubtestdependencies
* Allow filtering packages in pubtestdependencies

## 0.2.0

* add pubtestpackage

## 0.1.3

* add pubtestdependencies

## 0.1.0

* Initial version pubtest
