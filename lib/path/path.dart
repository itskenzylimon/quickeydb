import 'package:path_provider/path_provider.dart';

class PathProviderHelpers {
  /// This is the path where the application may place cache files.
  /// use this method to get the temporary path of the device.
  Future<String> temporaryPath() async {
    final directory = await getTemporaryDirectory();
    return directory.path;
  }

  /// This is the path where the application may place data that is user-generated,
  /// or that cannot otherwise be recreated by your application.
  Future<String> applicationDocumentsPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// This is the path where the application may place files that are persistent,
  /// backed up, and not visible to the user, such as sqlite.db.
  /// it will return an empty string if directory is not available.
  /// and it will return the path string if directory is available.
  Future<String> eExternalStoragePath() async {
    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      return '';
    }
    return directory.path;
  }
}