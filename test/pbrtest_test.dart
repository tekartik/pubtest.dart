@TestOn('vm')
library;

import 'package:path/path.dart';
import 'package:test/test.dart';

import 'pubtest_test.dart';

var longTimeout = const Timeout(Duration(minutes: 2));

String get _pbrTestDartScript =>
    normalize(absolute(join(exampleBinPath, 'pbrtest.dart')));

void main() {
  group('pbrtest', () {
    defineTests(_pbrTestDartScript, suffix: 'pbr');
  });
}
