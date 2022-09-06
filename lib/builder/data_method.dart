// ignore_for_file: slash_for_doc_comments
import 'package:quickeydb/builder/return_method.dart';

abstract class DataMethods<T> implements QueryableReturn<T> {
  /**
   * Method [create] adds entry to database
   */
  Future<dynamic> create(T item);

  /**
   * Method [createAll] but add a list of entries
   */
  Future createAll(List<T> items);

  /**
   * Method [insert] same as create but expects a map entry
   */
  Future<dynamic> insert(Map<String?, dynamic> item);

  /**
   * Method [insert] same as insert but expects a map entry List
   */
  Future insertAll(List<Map<String, dynamic>> items);

  // Future upsert(Map<String, dynamic> item);

  /**
   * Method [update] updates entry on database
   */
  Future<int> update(T item);

  /**
   * Method [delete] deletes entry on database
   */
  Future<int> delete(T item);

  /**
   * Method [destroy] deletes entry on database based on id
   */
  Future<int> destroy(int id);

  /**
   * Method [destroyAll] deletes all entries on database
   */
  Future<int> destroyAll();
}
