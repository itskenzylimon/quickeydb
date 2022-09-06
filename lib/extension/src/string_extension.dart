extension StringExtension on String {
  String toCamelCase() => replaceAllMapped(
          RegExp(r'(?<=[a-z])[A-Z]'), (Match m) => ('_${m.group(0)!}'))
      .toLowerCase();
}
