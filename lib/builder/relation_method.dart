// ignore_for_file: slash_for_doc_comments

abstract class RelationMethod<T> {
  /**
   * [isEmpty] checks if an entry exist in a table
   */
  // Future<bool> get isEmpty;

  /**
   * [deleteBy] deletes all records based on user
   */
  // Future deleteBy({Map<String, dynamic> args});

  /**
   * [toSql] gets the sequel value of a query
   */
  String toSql();

  /**
   * [updateAll] updates all entries in a DB based on a map
   */
  Future updateAll(Map<String, dynamic> args);
}
