import 'package:quickeydb/controls/relation.dart';
import 'package:quickeydb/quickeydb.dart'
    if (dart.library.html) 'package:quickeydb/quickeywebdb.dart';

class HasOne<T extends DataAccessObject> extends Relation<T> {
  const HasOne();
}
