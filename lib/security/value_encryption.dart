import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Authenticated encryption for selected values, not the SQLite file structure.
/// Keep this key in platform secure storage, never beside the database.
class ValueEncryption {
  static const prefix = 'qdb:aesgcm:1:';
  final SecretKey _key;
  final bool allowPlaintextReads;
  final _algorithm = AesGcm.with256bits();

  ValueEncryption(List<int> key, {this.allowPlaintextReads = false})
      : _key = SecretKey(List<int>.from(key)) {
    if (key.length != 32 || key.any((n) => n < 0 || n > 255)) {
      throw ArgumentError('Encryption requires exactly 32 key bytes.');
    }
  }

  /// Compare configurations without exposing key material.
  Future<bool> hasSameKey(ValueEncryption other) async {
    final left = await _key.extractBytes(),
        right = await other._key.extractBytes();
    var difference = 0;
    for (var i = 0; i < 32; i++) {
      difference |= left[i] ^ right[i];
    }
    return difference == 0 && allowPlaintextReads == other.allowPlaintextReads;
  }

  static Future<List<int>> generateKey() async =>
      (await AesGcm.with256bits().newSecretKey()).extractBytes();

  bool isEncrypted(Object? value) =>
      value is String && value.startsWith(prefix);

  Future<String> encrypt(Object? value, {required String context}) async {
    final box = await _algorithm.encrypt(utf8.encode(jsonEncode(value)),
        secretKey: _key, aad: utf8.encode(context));
    return '$prefix${base64Encode(box.concatenation())}';
  }

  Future<dynamic> decrypt(Object? value, {required String context}) async {
    if (value is String &&
        value.startsWith('qdb:aesgcm:') &&
        !isEncrypted(value)) {
      throw const FormatException('Unsupported encrypted value version.');
    }
    if (!isEncrypted(value)) {
      if (!allowPlaintextReads && value != null) {
        throw StateError('Unencrypted value in protected storage.');
      }
      return value;
    }
    final bytes = base64Decode((value as String).substring(prefix.length));
    final box =
        SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16);
    final plain = await _algorithm.decrypt(box,
        secretKey: _key, aad: utf8.encode(context));
    return jsonDecode(utf8.decode(plain));
  }
}
