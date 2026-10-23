import 'package:flutter_test/flutter_test.dart';
import 'package:quickeydb/security/value_encryption.dart';

void main() {
  test('invalid keys are rejected before encryption starts', () {
    expect(() => ValueEncryption([1, 2]), throwsArgumentError);
    expect(() => ValueEncryption(List.filled(32, 256)), throwsArgumentError);
  });
  test('strict encryption rejects plaintext and compares key configurations',
      () async {
    final key = await ValueEncryption.generateKey();
    final cipher = ValueEncryption(key, allowPlaintextReads: false);
    await expectLater(
        cipher.decrypt('plain', context: 'test'), throwsStateError);
    expect(
        await cipher
            .hasSameKey(ValueEncryption(key, allowPlaintextReads: false)),
        isTrue);
    expect(
        await cipher
            .hasSameKey(ValueEncryption(key, allowPlaintextReads: true)),
        isFalse);
  });
}
