import 'package:quickeydb/controls/relation.dart';
import 'package:quickeydb/quickeydb.dart';

class ProxyInclude<T extends DataAccessObject, R extends DataAccessObject>
    extends Relation<T> {
  DataAccessObject? get parent => QuickeyDB.getInstance!.dataAccessObjects![T];
  List<DataAccessObject?> get children =>
      [QuickeyDB.getInstance!.dataAccessObjects![R]];

  const ProxyInclude();

  @override
  String toString() {
    return 'ProxyInclude(parent: ${parent.runtimeType}, children: ${children.map((child) => child.runtimeType).toList()})';
  }
}

class ProxyInclude0<T extends DataAccessObject, R1 extends DataAccessObject,
    R2 extends DataAccessObject> extends ProxyInclude<T, R1> {
  @override
  List<DataAccessObject?> get children =>
      [...super.children, QuickeyDB.getInstance!.dataAccessObjects![R2]];

  const ProxyInclude0();
}

class ProxyInclude1<
    T extends DataAccessObject,
    R1 extends DataAccessObject,
    R2 extends DataAccessObject,
    R3 extends DataAccessObject> extends ProxyInclude0<T, R1, R2> {
  @override
  List<DataAccessObject?> get children =>
      [...super.children, QuickeyDB.getInstance!.dataAccessObjects![R3]];

  const ProxyInclude1();
}
