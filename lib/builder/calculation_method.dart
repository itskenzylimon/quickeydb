// ignore_for_file: slash_for_doc_comments

abstract class CalculationMethod<T> {

  /**
   * [average] average of a num column
   */
  Future<double?> average(String column);

  /**
   * [count] count of all num column
   */
  Future<int?> count([String column = '*']);

  /**
   * [ids] gets id list of a table
   */
  Future<List<dynamic>> get ids;

  /**
   * [maximum] gets maximum value of a num column in table
   */
  Future<dynamic> maximum(String column);

  /**
   * [minimum] gets minimum value of a num column in table
   */
  Future<dynamic> minimum(String column);

  /**
   * [pick] pick
   */
  Future<List<dynamic>> pick(List<String> columns);

  /**
   * [pluck] pluck
   */
  Future<List<dynamic>> pluck(List<String> columns);

  /**
   * [sum] gets sum value of a num column in table
   */
  Future<int?> sum(String column);
}
