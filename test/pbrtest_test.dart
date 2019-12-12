@TestOn('vm')
library tekartik_pub.test.pub_test;

import 'package:path/path.dart';
import 'package:test/test.dart';

import 'pubtest_test.dart';

var longTimeout = const Timeout(Duration(minutes: 2));

String get _pbrTestDartScript =>
    normalize(absolute(join('bin', 'pbrtest.dart')));

void main() {
  group('pbrtest', () {
    run(_pbrTestDartScript);
  });
}
