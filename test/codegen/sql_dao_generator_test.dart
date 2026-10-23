import 'package:flutter_test/flutter_test.dart';
import 'sql_generator_contract.dart';

void main() {
  group('SQL to DAO', () {
    for (final entry in generatorContractCases().entries) {
      test(entry.key, entry.value);
    }
  });
}
