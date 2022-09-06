// ignore: implementation_imports
import 'package:sqflite_common/src/sql_builder.dart';

extension QuickeyBuilder on SqlBuilder {
  String get fullSql {
    String sqArguments = sql;

    int lastIndex = 0;
    for (int i = 0; i < arguments!.length; i++) {
      lastIndex = sqArguments.indexOf('?', lastIndex + 1);
      sqArguments =
          sqArguments.replaceFirst('?', '${arguments![i]}', lastIndex);
    }

    return sqArguments;
  }
}
