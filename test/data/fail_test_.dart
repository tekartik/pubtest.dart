library failed_test_;

import 'package:test/test.dart';

void main() {
  test('failed', () async {
    fail('will fail');
  });
}
