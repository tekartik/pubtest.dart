# Sample commands

## pubtestpackage

```bash
# Dry run on a git package (shallow clone in a temp folder)
dart run bin/pubtestpackage.dart -sgit https://github.com/tekartik/common_utils.dart -d
# Dry run on the current package
dart run bin/pubtestpackage.dart -spath . -d
```
