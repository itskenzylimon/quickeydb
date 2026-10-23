import '../configs/sql_builder.dart';

extension QuickeyBuilder on SqlBuilder {
  /// SQL and argument count only. Bound values may contain secrets.
  String get fullSql => '$sql /* ${arguments?.length ?? 0} bound arguments */';
}
