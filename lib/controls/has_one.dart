import 'package:quickeydb/controls/relation.dart';
import 'package:quickeydb/quickeydb.dart';

class HasOne<T extends DataAccessObject> extends Relation<T> {
  const HasOne();
}
