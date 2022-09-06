// ignore_for_file: slash_for_doc_comments
abstract class QueryableReturn<T> {
  /**
   * alias for [toList]
   */
  Future<List<T>> get all;

  /**
   *  [toList] returns items list
   */
  Future<List<T>> toList();

  /**
   * [toMap] returns a map
   */
  Future<List<Map<String?, dynamic>>> toMap();
}
