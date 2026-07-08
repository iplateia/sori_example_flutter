import 'package:flutter_test/flutter_test.dart';
import 'package:sori_example_flutter/main.dart';

void main() {
  test('stringKeyedMap converts platform payload keys to strings', () {
    final result = stringKeyedMap(<Object, Object?>{
      'name': 'Summer Campaign',
      42: 'marker',
    });

    expect(result, <String, Object?>{
      'name': 'Summer Campaign',
      '42': 'marker',
    });
  });
}
