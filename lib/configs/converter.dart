class Converter<T> {
  final T Function(Map<String?, dynamic>) encode;
  final Map<String?, dynamic> Function(T) decode;
  final Map<String?, dynamic> Function(T) decodeTable;

  const Converter(
      {required this.encode, required this.decode, required this.decodeTable});
}
