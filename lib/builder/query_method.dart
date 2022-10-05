// ignore_for_file: slash_for_doc_comments
import 'package:quickeydb/builder/calculation_method.dart';
import 'package:quickeydb/builder/read_method.dart';
import 'package:quickeydb/builder/return_method.dart';
import 'relation_method.dart';


abstract class QueryMethod<T>
    implements RelationMethod<T>, ReaderMethod<T>, CalculationMethod<T>, QueryableReturn<T> {
  /**
   * [select] method
   */
  QueryMethod<T> select(List<String> args);

  /**
   * [where] method
   */
  QueryMethod<T> where(Map<String, dynamic> args);

  /**
   * [or] method
   */
  QueryMethod<T> or(Map<String, dynamic> args);

  /**
   * [not] method
   */
  QueryMethod<T> not(Map<String, dynamic> args);

  /**
   * [includes] method
   */
  QueryMethod<T> includes(List<Type> args);

  /**
   * [joins] method
   */
  QueryMethod<T> joins(List<Type> args);

  /**
   * [limit] method
   */
  QueryMethod<T> limit(int value);

  /**
   * [offset] method
   */
  QueryMethod<T> offset(int value);

  /**
   * [group] method
   */
  QueryMethod<T> group(List<String> args);

  /**
   * [having] method
   */
  QueryMethod<T> having(String args);

  /**
   * [distinct] method
   */
  QueryMethod<T> distinct([bool value = true]);

  /**
   * [order] method
   */
  QueryMethod<T> order(List<String> args, String type);
}
