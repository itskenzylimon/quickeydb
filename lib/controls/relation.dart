import 'package:quickeydb/quickeydb.dart';

abstract class Relation<T extends DataAccessObject> {
  DataAccessObject? get dao => QuickeyDB.getInstance!.dataAccessObjects![T];

  const Relation();
}
