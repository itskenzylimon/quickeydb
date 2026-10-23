import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_browser.dart' as browser;

IdbFactory memoryFactory(String path) => browser.getIdbFactory()!;
