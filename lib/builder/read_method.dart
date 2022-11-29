// ignore_for_file: slash_for_doc_comments
abstract class ReaderMethod<T> {

  /**
   * [isExists] checks if arg exist
   */
  Future<bool> isExists(Map<String, dynamic> args);

  /**
   * [findBy] looks for an entry based on map
   */
  Future<T> findBy(Map<String, dynamic> args);

  /**
   * [find] gets an entry based by id
   */
  Future<T> find(var id);

  /**
   * [first] gets the first entry on database
   */
  Future<T> get first;

  /**
   * [last] gets the last entry on database
   */
  Future<T> get last;

  /**
   * [take] limits result based on passed int value
   */
  Future<List<T>> take([int limit = 1]);
}
