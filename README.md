[QuickeyDB](https://github.com/itskenzylimon/quickeydb) is a simple ORM inspired from [ActiveRecord](https://github.com/rails/rails/tree/master/activerecord), built on-top of [Sqflite](https://pub.dev/packages/sqflite).

QuickeyDB Object-Relational Mapping (ORM) uses a coding technique with function descriptors connected to a relational database.

Apart from data access technique, QuickeyDB can benefit a developer in many ways including

* Requires Simplified development and Maintenance: this is because ORMs automate the object-to-table and table-to-object conversion
* QuickeyDB allow data caching /indexing improving database performance
* You get to write better queries in a Dart, Most developers are not the best at writing SQL statements.
* Lastly, QuickeyDB has incredibly lower code lines compared to embedded SQL Queries.


1. [Introduction to QuickeyDB](#introduction-to-quickeydb)
2. [Getting Started with QuickeyDB](#getting-started-with-quickeydb)
   1. [Add QuickeyDB dependency](#1-add-quickeydb-dependency)
   2. [Create Models](#2-create-user-model-and-task-model)
   3. [Create a Schema Dart File](#3-create-a-schema-dart-file)
   4. [Initialize database](#4-initialize-database)
   5. [Simple Example](#5-simple-example)
3. [Data Access Objects](#data-access-objects)
    1. [Building Queries](#building-queries)
    1. [Finder Queries](#finder-queries)
    1. [Data Persistence](#data-persistence)
    1. [Calculations Methods](#calculations-methods)
    1. [Helper Methods](#helper-methods)
    1. [Custom SQL Queries](#custom-sql-queries)
4. [Data Tables Relations](#data-tables-relations)
    1. [Belongs To](#belongs-to)
    1. [Has One](#has-one)
    1. [Has Many](#has-many)
5. [Database Migration](#database-migration)
6. [Import Local Database](#import-local-databases)
7. [Persist Data Storage](#persist-data-storage)
8. [Cool Color Logger](#cool-color-logger)
9. [Taskan Crud Example](#taskan-crud-example)
10. [Features Request & Bug Reports](#features-request-&-bug-reports)
11. [Contributing](#contributing)
12. [Articles and videos](#articles-and-videos)

# Introduction to QuickeyDB:

_QuickeyDB_ is an ORM inspired form [ActiveRecord](https://github.com/rails/rails/tree/master/activerecord) and depends on [_CREATE TABLE_](https://sqlite.org/lang_createtable.html) command which uses _Regular Expression_ ([RegExp](https://en.wikipedia.org/wiki/Regular_expression)) to analysis table defentions:

- Table name.
- Columns definition.
- Primary key.
- Foreign keys.

Note: _QuickeyDB_ is a runtime library so it dosen't depend on heavily generate code.

# Getting Started with QuickeyDB

### 1. Add QuickeyDB dependency

```yaml
dependencies:
  quickeydb: ^x.x.x
```

### 2. Create User Model and Task Model

```dart
// Database/Models/user.dart

import 'task.dart';

class User {
   int? id;
   String? name;
   String? email;
   String? phone;
   int? age;
   Task? task;

   User({
      this.id,
      required this.name,
      required this.email,
      required this.age,
      this.phone,
      this.task
   });

   Map<String, dynamic> toMap() => {
      'id': id,
      'name': name,
      'email': email,
      'age': age,
      'phone': phone,
      'task': task != null ? task!.toMap() : null,
   };

   Map<String, dynamic> toTableMap() => {
      'id': id,
      'name': name,
      'email': email,
      'age': age,
      'phone': phone,
   };

   User.fromMap(Map<String?, dynamic> map)
           : id = map['id'],
              name = map['name'],
              email = map['email'],
              age = map['age'],
              phone = map['phone'],
              task = map['task'] != null ? Task.fromMap(map['task']) : null;

}


```

```dart
// Database/Models/task.dart

import 'user.dart';

class Task {
   int? id;
   String name;
   String body;
   int? level;
   User? user;

   Task({
      this.id,
      required this.name,
      required this.body,
      required this.level,
      this.user,
   });

   Task.fromMap(Map<String?, dynamic> map)
           : id = map['id'],
              name = map['name'],
              body = map['body'],
              level = map['level'],
              user = map['user'] != null ? User.fromMap(map['user']) : null;

   Map<String, dynamic> toMap() => {
      'id': id,
      'name': name,
      'body': body,
      'level': level,
      'user': user != null ? user?.toMap() : null,
   };

   Map<String, dynamic> toTableMap() => {
      'id': id,
      'name': name,
      'body': body,
      'level': level,
   };

}


```

### 3. Create a Schema Dart File

```dart
// Database/schema.dart

import 'package:quickeydb/quickeydb.dart';
import 'Models/user.dart';
import 'Models/task.dart';

class UserSchema extends DataAccessObject<User> {
   UserSchema()
           : super(
      '''
          CREATE TABLE user (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
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
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            body TEXT,
            status TEXT,
            level INTEGER DEFAULT "1" NOT NULL,
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


```

### 4. Initialize database

```dart

  await QuickeyDB.initialize(
    persist: false,
    dbVersion: 1,
    dataAccessObjects: [
      UserSchema(),
      TaskSchema(),
    ],
    dbName: 'tascan_v1',
  );

```

### 5. Simple Example

```dart

  await QuickeyDB.getInstance!<UserTable>()?.create(
    User(
      name: 'Kenzy Limon',
      email: 'itskenzylimon@gmail.com',
      phone: '+254 712345678',
      task: Task(name: 'Create Package', body: 'Create a Flutter DB Package')
    ),
  );
```

# Data Access Objects

## Building Queries

```dart
/// SELECT * FROM user
QuickeyDB.getInstance!<UserSchema>()!.all; // | returns a list<T>

/// SELECT id FROM user
QuickeyDB.getInstance!<UserSchema>()!.select(['id']).toList(); // returns a list<T>

/// SELECT * FROM user WHERE name = 'Sam' OR name = 'Mike'
QuickeyDB.getInstance!<UserSchema>()!.where({'name': 'Kenzy Limon'}).or({'age': '21'}).toList();

/// To use any other operation just pass it after attribute
// SELECT * FROM user where age >= 18
QuickeyDB.getInstance!<UserSchema>()!.where({'age >= ?': 18}).toList();

// SELECT * FROM user ORDER BY name DESC
QuickeyDB.getInstance!<UserSchema>()!.order(['age']).toList();

// SELECT * FROM user GROUP BY name HAVING LENGTH(name) > 3
QuickeyDB.getInstance!<UserSchema>()!.group(['name']).having('LENGTH(name) > 5').toList();

// SELECT * FROM user LIMIT 50 OFFSET 100
QuickeyDB.getInstance!<UserSchema>()!.limit(1).offset(10).toList();

// SELECT DISTINCT * FROM user
QuickeyDB.getInstance!<UserSchema>()!.distinct().toList();
```

## Include Queries

```dart
// SELECT * FROM user
// SELECT * FROM task WHERE id IN (1)
QuickeyDB.getInstance!<UserSchema>()?.includes([TaskSchema]).toList()
// [User(id: 1, name: 'Kenzy Limon',... task: [Task(id: 1, name: 'Complete ORM', body: 'Do nice Documentation')])]
```

## Join Queries

```dart
// SELECT
//   task.*,
//   user.id AS user_id,
//   user.name AS user_name,
// FROM task
//   INNER JOIN user ON user.id = task.user_id
QuickeyDB.getInstance!<TaskSchema>()!.joins([UserSchema]).toList();
// [Task(id: 1, name: 'Complete ORM', body: 'Do nice Documentation',... user: User(id: 1, name: 'Kenzy Limon',...))]
```

## Finder Queries

```dart
// SELECT * FROM user WHERE name = 'Kenzy Limon' LIMIT 1
QuickeyDB.getInstance!<UserSchema>()!.isExists({'name': 'John Doe'}); // true

// SELECT * FROM user WHERE id = 1 LIMIT 1
QuickeyDB.getInstance!<UserSchema>()!.find(1); // User

// SELECT * FROM user WHERE name = 'Mike' LIMIT 1
QuickeyDB.getInstance!<UserSchema>()!.findBy({'name': 'Jane Doe'}); // User

// SELECT * FROM user
QuickeyDB.getInstance!<UserSchema>()!.first; // first item

// SELECT * FROM user
QuickeyDB.getInstance!<UserSchema>()!.last; // last item

//  SELECT * FROM user LIMIT 3
QuickeyDB.getInstance!<UserSchema>()!.take(10);
```

## Data Persistence

```dart
final user = User(id: 1, name: 'Kenzy Limon', age: 21,...);

// INSERT INTO user (id, name, age,...) VALUES (1, 'Kenzy Limon', 21,...)
QuickeyDB.getInstance!<UserSchema>()!.create(user); // | createAll

// Also you can use `insert` which accepts map
QuickeyDB.getInstance!<UserSchema>()!.insert(user.toMap()); // insertAll

// UPDATE user SET name = 'Kenzy Limon', age = 21 WHERE id = 1
QuickeyDB.getInstance!<UserSchema>()!.update(user..name = 'John Doe');

// DELETE FROM user WHERE id = 1
QuickeyDB.getInstance!<UserSchema>()!.delete(user);

// DELETE FROM user WHERE id = 1
QuickeyDB.getInstance!<UserSchema>()!.destroy(1); // (truncate)
```

## One to one

```dart
// INSERT INTO user (id, name, age,...) VALUES (NULL, 'Jane Doe', 25,...);
// INSERT INTO task (id, name, user_id,...) VALUES (NULL, 'Test Cases', 1);
QuickeyDB.getInstance!<TaskSchema>()!.create(
Task(
name: 'Test Cases',...
user: User(
            name: 'Jane Doe', age: 25
      ),
  ),
)
```

## One to many

```dart
// INSERT INTO user (id, name, age) VALUES (NULL, 'John Doe', 10);
// INSERT INTO task (id, name, user_id) VALUES (NULL, 'Write Documentation', 1);
QuickeyDB.getInstance!<UserSchema>()!.create(
User(
name: 'Jane Doe',
age: 25,...
task: [
  Task(name: 'Test Cases'),...
    ],
  ),
)
```

## Calculations Methods

```dart
/// SELECT COUNT(*) FROM user
QuickeyDB.getInstance!<UserSchema>()!.count(); // 1001

/// SELECT COUNT(email) FROM user
QuickeyDB.getInstance!<UserSchema>()!.count('email'); // 600

/// SELECT AVG(age) FROM user
QuickeyDB.getInstance!<UserSchema>()!.average('age'); // 35

/// SELECT id FROM user
QuickeyDB.getInstance!<UserSchema>()!.ids; // [1, 2, 3,...]

/// SELECT MAX(age) FROM user
QuickeyDB.getInstance!<UserSchema>()!.maximum('age'); // 69

/// SELECT MIN(age) FROM user
QuickeyDB.getInstance!<UserSchema>()!.minimum('age'); // 18

/// SELECT name, age FROM user LIMIT 1
QuickeyDB.getInstance!<UserSchema>()!.pick(['name', 'age']); // ['John Doe', 96]

/// SELECT name FROM user
QuickeyDB.getInstance!<UserSchema>()!.pluck(['name', 'age']); // [['John Doe', '96'],...]

/// SELECT SUM(age) FROM user
QuickeyDB.getInstance!<UserSchema>()!.sum('age'); // 404
```

## Helper Methods

```dart
/// convert query to list
QuickeyDB.getInstance!<UserSchema>()!.foo().bar().toList(); // [User,...]

/// convert query to map
QuickeyDB.getInstance!<UserSchema>()!.foo().bar().toMap(); // [{id: 1, name: 'Mike', age: 10}, ...]

/// alias [count] > 0
QuickeyDB.getInstance!<UserSchema>()!.foo().bar().isEmpty; // | false
```

## Data Tables Relations

Make sure to add `FOREIGN KEY` between tables.

### Belongs To

```dart
// Database/schema.dart
class TaskSchema extends DataAccessObject<Task> {
  TaskSchema()
      : super(
    '''
          CREATE TABLE tasks (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            body TEXT,
            status TEXT,
            level INTEGER DEFAULT "1" NOT NULL,
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
```

### Has One

```dart
// Database/schema.dart
class TaskSchema extends DataAccessObject<Task> {
  TaskSchema()
      : super(
    '''
          CREATE TABLE tasks (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            body TEXT,
            status TEXT,
            level INTEGER DEFAULT "1" NOT NULL,
            FOREIGN KEY (user_id) REFERENCES user (id)
          )
          ''',
    relations: [
      const HasOne<UserSchema>(),
    ],
    converter: Converter(
      encode: (task) => Task.fromMap(task),
      decode: (task) => task!.toMap(),
      decodeTable: (task) => task!.toTableMap(),
    ),
  );
}
```

### Has Many

```dart
// Database/schema.dart
class UserSchema extends DataAccessObject<User> {
  UserSchema()
      : super(
    '''
          CREATE TABLE user (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            phone TEXT,
            age INTEGER
          )
          ''',
    relations: [
      const HasMany<TaskSchema>(),
    ],
    converter: Converter(
      encode: (user) => User.fromMap(user),
      decode: (user) => user!.toMap(),
      decodeTable: (user) => user!.toTableMap(),
    ),
  );
}
```

## Custom SQL Queries

_QuickeyDB_ is scalable with custom and complex queries so for example let's say we want to filter old users we can add:

```dart
class UserSchema extends DataAccessObject<User> {

  ...
  
  Future<List<User?>> getOldUsers() {
  return where({'age >= ?': 18}).toList();
  }
  
  ...
  
}
```

You can also use more complex queries by accessing `database` object

```dart
class UserSchema extends DataAccessObject<User> {

  ...
  
  Future<List<User>> doRawQuery() async {
    // Use your custom query
    final results = await database!.rawQuery('SELECT * FROM user');

    // when returning result use converter
    return results.map((result) => converter.encode(result) as User).toList();
  }
  
  ...
  
}
```

# Persist Data Storage

To use persist database set `persist` property to `true`

```dart
final quickeyDB = QuickeyDB(
  persist: true',
)
```

# Import Local Database

To import exists database:

1. Copy exists database to `assets/database.db`
2. Add path to assets in `pubspec.yaml`

```diff
+ flutter:
+   assets:
+     - assets/database.db
```

3. Set `importDB` property to `true`

```dart
final quickeyDB = QuickeyDB(
  importDB: true,
)
```

4. Run

# Database Migration
Because we depend on CREATE TABLE command as explained, so one of the best solutions was to use force migration by creating a new table and moving all data:


1. Modify your SQL command by adding or removing some definitions like:

```dart
class UserSchema extends DataAccessObject<User> {
  UserSchema()
      : super(
    '''
          CREATE TABLE user (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            phone TEXT,
            address TEXT,
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
}
```

1. Dont forget to change the database version.

```dart

  final quickeyDB = QuickeyDB.initialize!(
     dbVersion: 2, // any version
  );

```


_Please Note That :: **Never** add `NOT NULL` columns while migrating unless you pass `DEFAULT` value._


# Cool Color Logger

Note: By default `logger` is _enabled_ while you're in debugging mode, if you want to disable it just set `debugging` property to `false`.

```dart

  final quickeyDB = QuickeyDB.initialize!(
     debugging: false, // any version
  );

```

# Taskan Crud Example

- [Taskan Crud Example](https://github.com/itskenzylimon/quickeydb/example)

# Features Request & Bug Reports

Feature requests and bugs at the [issue tracker](https://github.com/itskenzylimon/quickeydb/issues).

# Contributing
- Fork the repo on [GitHub](https://github.com/itskenzylimon/quickeydb)
- Clone the project
- Commit changes with a well explained details
- Push your work back up to your fork
- Submit a Pull request so that we can review / merge your changes

# Articles and videos

[Flutter Quickey Database ORM](https://medium.com/@itskenzylimon/flutter-quickey-database-orm-e1d4208f903a) - Medium Article