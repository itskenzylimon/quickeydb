import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_io.dart' as io;

IdbFactory memoryFactory(String path) => io.getIdbFactoryPersistent(path);
