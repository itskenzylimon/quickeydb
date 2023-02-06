import 'package:quickeydb/controls/relation.dart';
import 'package:quickeydb/quickeydb.dart';

class ProxyHasMany<T extends DataAccessObject, R extends DataAccessObject>
    extends Relation<T> {
  List<DataAccessObject?> get includes =>
      [QuickeyDB.getInstance!.dataAccessObjects![R]];

  const ProxyHasMany();
}

class Proxy0HasMany<T extends DataAccessObject, R1 extends DataAccessObject,
    R2 extends DataAccessObject> extends ProxyHasMany<T, R1> {
  @override
  List<DataAccessObject?> get includes =>
      super.includes..add(QuickeyDB.getInstance!.dataAccessObjects![R2]);

  const Proxy0HasMany();
}

class Proxy1HasMany<
    T extends DataAccessObject,
    R1 extends DataAccessObject,
    R2 extends DataAccessObject,
    R3 extends DataAccessObject> extends Proxy0HasMany<T, R1, R2> {
  @override
  List<DataAccessObject?> get includes =>
      super.includes..add(QuickeyDB.getInstance!.dataAccessObjects![R3]);

  const Proxy1HasMany();
}

class HasMany<T extends DataAccessObject> extends Relation<T> {
  const HasMany();
}
