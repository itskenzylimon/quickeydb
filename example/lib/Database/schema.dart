import 'package:quickeydb/quickeydb.dart'
    if (dart.library.html) 'package:quickeydb/quickeywebdb.dart';

import 'Models/demo.dart';
import 'Models/user.dart';
import 'Models/task.dart';

class UserSchema extends DataAccessObject<User> {
  UserSchema()
      : super(
          '''
          CREATE TABLE user (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            phone TEXT,
            age INTEGER
          )
          ''',
          relations: [
            const HasOne<TaskSchema>(),
          ],
          converter: Converter(
            encode: (user) => User.fromMap(user),
            decode: (user) => user!.toMap(),
            decodeTable: (user) => user!.toTableMap(),
          ),
        );

  Future<List<User?>> getOldUsers() {
    return where({'age >= ?': 18}).toList();
  }

  Future<List<User>> doRawQuery() async {
    // Use your custom query
    final results = await database!.rawQuery('SELECT * FROM user');

    // when returning result use converter
    return results.map((result) => converter.encode(result) as User).toList();
  }
}

class TaskSchema extends DataAccessObject<Task> {
  TaskSchema()
      : super(
          '''
          CREATE TABLE tasks (
            id TEXT NOT NULL PRIMARY KEY,
            user_id TEXT NOT NULL,
            name TEXT NOT NULL,
            slug TEXT,
            body TEXT,
            status TEXT,
            level INTEGER DEFAULT "1",
            FOREIGN KEY (user_id) REFERENCES user (id)
          )
          ''',
          relations: [
            const BelongsTo<UserSchema>(),
          ],
          converter: Converter(
            encode: (task) => Task.fromMap(task),
            decode: (task) => task!.toMap(),
            decodeTable: (task) => task!.toTableMap(),
          ),
        );
}

class DemoSchema extends DataAccessObject<Demo> {
  DemoSchema()
      : super(
          '''
          CREATE TABLE demo (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            body TEXT
          )
          ''',
          relations: [],
          converter: Converter(
            encode: (demo) => Demo.fromMap(demo),
            decode: (demo) => demo!.toMap(),
            decodeTable: (demo) => demo!.toTableMap(),
          ),
        );
}
