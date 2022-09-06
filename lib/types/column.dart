class Column {
  final String? name;
  final bool isNullable;
  final bool isUnique;
  final String? defaultValue;

  const Column({
    this.name,
    // TODO add regex
    this.defaultValue,
    // TODO add regex
    this.isNullable = false,
    // TODO add regex
    this.isUnique = false,
  });

  @override
  String toString() {
    return 'Column(name: $name, defaultValue: $defaultValue, isNullable: $isNullable, isUnique: $isUnique)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Column &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          isNullable == other.isNullable &&
          isUnique == other.isUnique &&
          defaultValue == other.defaultValue;

  @override
  int get hashCode =>
      name.hashCode ^
      isNullable.hashCode ^
      isUnique.hashCode ^
      defaultValue.hashCode;
}
