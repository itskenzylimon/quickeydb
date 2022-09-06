class Reference {
  final String? table;
  final String? primaryKey;

  const Reference({this.table, this.primaryKey});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Reference &&
          runtimeType == other.runtimeType &&
          table == other.table &&
          primaryKey == other.primaryKey;

  @override
  int get hashCode => table.hashCode ^ primaryKey.hashCode;

  @override
  String toString() {
    return 'Reference(table: $table, primaryKey: $primaryKey)';
  }
}
