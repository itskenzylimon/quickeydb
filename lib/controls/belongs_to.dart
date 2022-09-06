import 'package:quickeydb/configs/data_access_object.dart';
import 'package:quickeydb/controls/relation.dart';

class BelongsTo<T extends DataAccessObject> extends Relation<T> {
  const BelongsTo();
}
