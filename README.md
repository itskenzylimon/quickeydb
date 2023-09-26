<p align="center">
    <img src="https://raw.githubusercontent.com/itskenzylimon/quickeydb/main/assets/logo/QuickeyDBV1.png"/>
</p>

<h1 align="center">Quickey Database</h1>
<h3 align="center">FAST Object-Relational Mapping SQLite wrapper.</h3>



[QuickeyDB](https://github.com/itskenzylimon/quickeydb) is a simple ORM inspired from [ActiveRecord](https://github.com/rails/rails/tree/master/activerecord), built on-top of [Sqflite](https://pub.dev/packages/sqflite).

QuickeyDB Object-Relational Mapping (ORM) uses a coding technique with function descriptors connected to a relational database.

Apart from data access technique, QuickeyDB can benefit a developer in many ways including

* Requires Simplified development and Maintenance: this is because ORMs automate the object-to-table and table-to-object conversion
* QuickeyDB allow data caching /indexing improving database performance
* You get to write better queries in a Dart, Most developers are not the best at writing SQL statements.
* Lastly, QuickeyDB has incredibly lower code lines compared to embedded SQL Queries.

## Platforms

| Platform 	| Supported? 	               |
|----------	|----------------------------|
| Web      	| ❎ Coming Soon        	     |
| MacOS    	| ✅ Tried & Tested         	 |
| Windows  	| ✅ Tried & Tested         	               |
| Linux    	| ✅ Tried & Tested         	      |
| Android  	| ✅ Tried & Tested         	      |
| iOS      	| ✅ Tried & Tested         	      |


1. [Introduction to QuickeyDB](#introduction-to-quickeydb)
2. [Getting Started with QuickeyDB](#getting-started-with-quickeydb)
   1. [Add QuickeyDB dependency](#1-add-quickeydb-dependency)
   2. [Create Models](#2-create-user-model-and-task-model)
   3. [Create a Schema Dart File](#3-create-a-schema-dart-file)
   4. [Initialize database](#4-initialize-database)
   5. [Simple Example](#5-simple-example)
3. [Data Access Objects](#data-access-objects)
    1. [Building Queries](#building-queries)
    2. [Finder Queries](#finder-queries)
    3. [Data Persistence](#data-persistence)
    4. [Calculations Methods](#calculations-methods)
    5. [Helper Methods](#helper-methods)
    6. [Custom SQL Queries](#custom-sql-queries)
4. [Data Tables Relations](#data-tables-relations)
   1. [Belongs To](#belongs-to)
   2. [Has One](#has-one)
   3. [Has Many](#has-many)
5. [Database Migration](#database-migration)
6. [Transaction](#transaction)
7. [Batch support](#batch_support)
8. [Memory Cache](#memory_cache)
9. [Import Local Database](#import-local-databases)
10. [Persist Data Storage](#persist-data-storage)
11. [Cool Color Logger](#cool-color-logger)
12. [Platform setup](#platform-setup)
13. [Taskan Crud Example](#taskan-crud-example)
14. [Features Request & Bug Reports](#features-request-&-bug-reports)
15. [Contributing](#contributing)
16. [Articles and videos](#articles-and-videos)

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

# Database Relationships
QuickeyDB has out of box support for relationships, we treasure them and they only
work when you define the relationships on your models.

After defining the relationships. QuickeyDB will do all the heavy lifting of constructing the underlying SQL queries.

## One to one
One to One creates a one-to-one relationship between two models.

For example, A user has a profile. The has one relationship needs a foreign key in the related table.
### Defining relationship on the model
Once you have created the schema with the required columns,
you will also have to define the relationship on your schema.

<p align="center">
    <img src="https://raw.githubusercontent.com/itskenzylimon/quickeydb/main/assets/logo/One-To-One.png"/>
</p>

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
HasMany creates a one-to-many relationship between two models. For example, A user has many posts. 

The relationship needs a foreign key in the related table.

Following is an example table structure for the one-to-many relationship. 
The tasks.user_id is the foreign key and forms the relationship with the user.id column.

### Defining relationship on the model
Once you have created the tables with the required columns, you will also have to define the relationship on your schema.

<p align="center">
    <img src="https://raw.githubusercontent.com/itskenzylimon/quickeydb/main/assets/logo/One-To-Many.png"/>
</p>

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


# Transaction

Calls in Transaction must only be done using the transaction object (`txn`), avoid using the `database` or `QuickeyDB.getInstance` inside transaction as this will trigger a databased dead-lock.

Keep in mind that the callbacks `onCreate` `onUpgrade` `onDowngrade` are already internally wrapped in a transaction, so there is no need to wrap your statements within those callbacks.

```dart

await QuickeyDB.getInstance!.database!.transaction((txn) async {

txn.insert('users', { mapped data }, conflictAlgorithm: ConflictAlgorithm.replace);
txn.delete('users', where: 'id = ?', whereArgs: [id]);
txn.update('users', { mapped data });

txn.rawDelete('DELETE FROM users WHERE name = ?', ['Kenzy Limon']);
txn.rawDelete('DELETE FROM users WHERE name = ?', ['Kenzy Limon']);
txn.rawDelete('DELETE FROM users WHERE name = ?', ['Kenzy Limon']);
txn.rawQuery('SELECT COUNT(*) FROM users');

await txn.execute('CREATE TABLE task_types (id INTEGER PRIMARY KEY)');

});

```

# Batch support

```dart

var batch = QuickeyDB.getInstance!.database!.batch();
batch.insert('users', {'name': 'Kenzy'});
batch.update('users', {'name': 'Kenzy Limon'}, where: 'name = ?', whereArgs: ['Kenzy']);
batch.delete('users', where: 'name = ?', whereArgs: ['Kenzy']);
var results = await batch.commit();

```

Getting the result for each operation has a cost (id for insertion and number of changes for update and delete). 

On Android where an extra SQL request is executed. If you don't care about the result and worry about performance in big batches, you can use

```dart
await batch.commit(noResult: true);
```

Note during a transaction, the batch won't be committed until the transaction is committed

```dart

await database.transaction((txn) async {
  
var batch = txn.batch();

// ...

await batch.commit();

});

```

The actual commit will happen when the transaction is committed. 

By default, a batch stops as soon as it encounters an error (which typically reverts the uncommitted changes)
to change this action, you have to set `continueOnError` to `false`

```dart
await batch.commit(continueOnError: true);
```


# Memory Cache
Memory is meant to make data management of any string type fast and easy. 
You can easily get any type of datatype (Int, Strings, Booleans, Doubles, Map, Models and T Any kind of data) 
from within any state of the app.

### Instantiation

```dart
// Import memory class
import 'package:quickeydb/memory/memory.dart';

  // Make main function async
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Add bellow line to main() func
  Memory memory = await Memory().initMemory();
  runApp(const MyApp());
}
```

To reference an instance of Memory, use one of the following methods

```dart

Memory memory = await Memory().initMemory();

bool hasMemory = await memory.hasMemory('message');
// print('@@@ -- hasMemory 1 -- $hasMemory');

/// You can also use you own custom instance on memory and access it using the memoryKey
/// for this to work you need to pass the correct memoryKey to get the right instance
Memory memory = await Memory().instance(memoryKey: 'customMemory');


```

### Methods

Storage and retrieval methods are demonstrated in the code snippet below:

```dart

/// initialise Memory instance

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ///initialize memory
  await Memory.instance(filename:"memory.txt").initMemory();
  runApp(const MyApp());
}

///To retrieve an instance of Memory in another dart file, use one of the following ways:
///Note: this will retrieve the current initialization of the Memory object
///It is not assured you will get the most current data using synchronous functions getString(), getBool(), getInt() and getDouble()
///To get most current data, either use the instantiation below or retrieve data using async function await memory.readMemory('key')

Memory memory = await Memory().instance();

/// You can also use you own custom instance on memory and access it using the memoryKey
/// for this to work you need to pass the correct memoryKey to get the right instance
Memory memory = await Memory().instance(memoryKey: 'customMemory');


/// you can easily check if any data is saved on memory using [isMemoryEmpty]
await memory.isMemoryEmpty()


///Reading data
// await memory.setMap('message', {});
// await memory.setInt('message', 11);
// await memory.setString('message', 'Hakuna Matata');
// await memory.setBool('message', true);
await memory.setDouble('message', 0.99);


String? setDouble = await memory.getString('message');
// print('@@@ -- setMap 1 -- $setDouble');
hasMemory = await memory.hasMemory('message');
// print('@@@ -- hasMemory 2 -- $hasMemory');
await memory.setDouble('message', message);
setDouble = await memory.getString('message');
// print('@@@ -- setMap 2 -- $setDouble');
await memory.deleteMemory('message');
hasMemory = await memory.hasMemory('message');
// print('@@@ -- hasMemory 3 -- $hasMemory');

```


```dart

  final quickeyDB = QuickeyDB.initialize!(
     debugging: false, // any version
  );

```


# Cool Color Logger

Note: By default `logger` is _enabled_ while you're in debugging mode, if you want to disable it just set `debugging` property to `false`.

```dart

  final quickeyDB = QuickeyDB.initialize!(
     debugging: false, // any version
  );

```


# Supported Data types

`DateTime` is not a supported SQLite type. Personally I store them as
int (millisSinceEpoch) or string (iso8601)

`bool` is not a supported SQLite type. Use `INTEGER` and 0 and 1 values.

### INTEGER

* Dart type: `int`
* Supported values: from -2^63 to 2^63 - 1

### REAL

* Dart type: `num`

### TEXT

* Dart type: `String`

### BLOB

* Dart type: `Uint8List`


# Platform setup
## Linux

```dart
libsqlite3 and libsqlite3-dev linux packages are required.
```

One time setup for Ubuntu (to run as root):

```dart
dart tool
/

linux_setup.dart

or

sudo apt
-
get -

y install
libsqlite3-0
libsqlite3-dev
```

## MacOS

Should work as is.

## Web

Copy sqflite_sw.js and sqlite3.wasm from the example/web folder to your root/web folder.
import the database as follows.

```dart
import 'package:quickeydb/quickeydb.dart' if (dart.library.html)
'package:quickeydb/quickeywebdb.dart';
```

## Windows

Should work as is in debug mode (`sqlite3.dll is bundled`).

In release mode, add `sqlite3.dll` in same folder as your executable.

# Taskan Crud Example

- [Taskan Crud Example](https://github.com/itskenzylimon/quickeydb/example)

# Features Request & Bug Reports

Feature requests and bugs at the [issue tracker](https://github.com/itskenzylimon/quickeydb/issues).

## Contributing

Quickey Database ORM is an open source project, and thus contributions to this project are welcome - please feel free to [create a new issue](https://github.com/itskenzylimon/quickeydb/issues/new/choose) if you encounter any problems, or [submit a pull request](https://github.com/itskenzylimon/quickeydb/pulls). For community contribution guidelines, please review the [Code of Conduct](CODE_OF_CONDUCT.md).

If submitting a pull request, please ensure the following standards are met:

1) Code files must be well formatted (run `flutter format .`).

2) Tests must pass (run `flutter test`).  New test cases to validate your changes are highly recommended.

3) Implementations must not add any project dependencies.

4) Project must contain zero warnings. Running `flutter analyze` must return zero issues.

5) Ensure docstrings are kept up-to-date. New feature additions must include docstrings.




## Additional information

This package has **THREE CORE** dependencies including core SQLite Packages.
```dart
- sqflite_common_ffi // for desktop apps
- sqflite
- collection
```

Developed by:

© 2022 [Kenzy Limon](https://www.kenzylimon.com)
# Articles and videos

[Flutter Quickey Database ORM](https://medium.com/@itskenzylimon/flutter-quickey-database-orm-e1d4208f903a) - Medium Article

## Found this project useful? ❤️

If you found this project useful, then please consider giving it a ⭐️ on Github and sharing it with your friends via social media.