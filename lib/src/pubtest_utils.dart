library pubtest.src.pubtest_utils;

import 'package:tekartik_pub/pub.dart';

class DependencyTestPackage extends TestPackage {
  PubPackage parent;
  DependencyTestPackage(this.parent, PubPackage package) : super(package);
}

class TestPackage {
  PubPackage package;
  TestPackage(this.package);

  int get hashCode => package.hashCode;

  bool operator==(o) {
    return o is TestPackage && o.package == package;
  }
}

class TestList {
  // empty list means all!
  Map<PubPackage, List<String>> all = {};
  add(PubPackage pkg, [String test]) {
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

  Iterable<PubPackage> get packages => all.keys;

  List<String> getTests(PubPackage pkg) {
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
