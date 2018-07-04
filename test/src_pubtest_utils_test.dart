@TestOn("vm")
library tekartik_pubtest.test.src_pubtest_utils_test;

import 'dart:convert';

import 'package:dev_test/test.dart';
import 'package:pubtest/src/pubtest_utils.dart';

void main() {
  group('sec_pubtest_utils', () {
    test('pubspecYamlGetTestDependenciesPackageName', () async {
      expect(pubspecYamlGetTestDependenciesPackageName({}), isNull);
      expect(
          pubspecYamlGetTestDependenciesPackageName(
              {'test_dependencies': null}),
          []);
      expect(
          pubspecYamlGetTestDependenciesPackageName({
            'test_dependencies': ['one']
          }),
          ['one']);
      expect(
          pubspecYamlGetTestDependenciesPackageName(json.decode(json.encode({
            'test_dependencies': ['one']
          })) as Map),
          ['one']);
    });
  });
}
