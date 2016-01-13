library pubtest.src.pubtest_utils;

import 'package:tekartik_pub/pub_fs_io.dart';

class DependencyTestPackage extends TestPackage {
  IoFsPubPackage parent;
  DependencyTestPackage(this.parent, IoFsPubPackage package) : super(package);
}

class TestPackage {
  FsPubPackage package;
  TestPackage(this.package);

  int get hashCode => package.hashCode;

  bool operator ==(o) {
    return o is TestPackage && o.package == package;
  }

  @override
  String toString() => package.toString();
}

class TestList {
  // empty list means all!
  Map<FsPubPackage, List<String>> all = {};
  add(FsPubPackage pkg, [String test]) {
    //print("$pkg $test");
    if (all.containsKey(pkg)) {
      List<String> tests = all[pkg];
      // if either is null, keep it null
      if (tests == null || test == null) {
        all[pkg] = null;
      } else {
        if (tests == null) {
          tests = [test];
        } else {
          tests.add(test);
        }
      }
    } else {
      if (test == null) {
        all[pkg] = null;
      } else {
        all[pkg] = [test];
      }
    }
  }

  Iterable<FsPubPackage> get packages => all.keys;

  List<String> getTests(FsPubPackage pkg) {
    return all[pkg];
  }

  @override
  String toString() => all.toString();
}

class NewTestList {
  // empty list means all!
  Map<TestPackage, List<String>> all = {};
  add(TestPackage pkg, [String test]) {
    //print("$pkg $test");
    if (all.containsKey(pkg)) {
      List<String> tests = all[pkg];
      // if either is null, keep it null
      if (tests == null || test == null) {
        all[pkg] = null;
      } else {
        if (tests == null) {
          tests = [test];
        } else {
          tests.add(test);
        }
      }
    } else {
      if (test == null) {
        all[pkg] = null;
      } else {
        all[pkg] = [test];
      }
    }
  }

  Iterable<TestPackage> get packages => all.keys;

  List<String> getTests(TestPackage pkg) {
    return all[pkg];
  }

  @override
  String toString() => all.toString();
}

class PubTest {
  TestList list;
  int poolSize;
  bool dryRun;
  var reporter;
  List<String> platforms;
  String name;

  /*
  Future _handleProject(PubPackage pkg, [List<String> files]) async {
    // if no file is given make sure the test/folder exists
    if (files == null) {
      // no tests found
      if (!(await FileSystemEntity.isDirectory(join(pkg.path, "test")))) {
        return;
      }
    }
    if (dryRun) {
      print('test on ${pkg.path}${files != null ? " ${files}": ""}');
    } else {
      try {
        List<String> args = [];
        if (files != null) {
          args.addAll(files);
        }
        ProcessResult result = await runCmd(pkg.testCmd(args,
            concurrency: poolSize,
            reporter: reporter,
            platforms: platforms,
            name: name)
          ..connectStderr = true
          ..connectStdout = true);
        if (result.exitCode != 0) {
          stderr.writeln('test error in ${pkg}');
          if (exitCode == 0) {
            exitCode = result.exitCode;
          }
        }
      } catch (e) {
        stderr.writeln('error thrown in ${pkg}');
        stderr.flush();
        throw e;
      }
    }
  }
  */
}

Iterable<String> pubspecYamlGetTestDependenciesPackageName(Map yaml) {
  if (yaml.containsKey('test_dependencies')) {
    Iterable<String> list = yaml['test_dependencies'] as Iterable<String>;
    if (list == null) {
      list = [];
    }
    return list;
  }
  return null;
}
