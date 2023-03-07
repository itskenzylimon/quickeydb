import 'package:quickeydb/quickeydb.dart'
    if (dart.library.html) 'package:quickeydb/quickeywebdb.dart';

abstract class Relation<T extends DataAccessObject> {
  DataAccessObject? get dao => QuickeyDB.getInstance!.dataAccessObjects![T];

  const Relation();
}
