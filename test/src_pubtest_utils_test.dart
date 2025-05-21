@TestOn('vm')
library;

import 'dart:convert';

import 'package:tekartik_pubtest/src/pubtest_utils.dart';
import 'package:test/test.dart';

void main() {
  group('sec_pubtest_utils', () {
    test('pubspecYamlGetTestDependenciesPackageName', () async {
      expect(pubspecYamlGetTestDependenciesPackageName({}), isNull);
      expect(
        pubspecYamlGetTestDependenciesPackageName({'test_dependencies': null}),
        isEmpty,
      );
      expect(
        pubspecYamlGetTestDependenciesPackageName({
          'test_dependencies': ['one'],
        }),
        ['one'],
      );
      expect(
        pubspecYamlGetTestDependenciesPackageName(
          json.decode(
                json.encode({
                  'test_dependencies': ['one'],
                }),
              )
              as Map,
        ),
        ['one'],
      );
    });
  });
}
