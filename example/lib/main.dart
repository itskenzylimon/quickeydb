import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quickeydb/builder/query_method.dart';
import 'package:quickeydb/memory/memory.dart';

// This line is needed for windows apps
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quickeydb/quickeydb.dart'
    if (dart.library.html) 'package:quickeydb/quickeywebdb.dart';

import 'Database/Models/task.dart';
import 'Database/Models/user.dart';
import 'Database/schema.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Memory memory = await Memory().initMemory();

  await memory.setDouble('data', 99.99);
  await memory.getDouble('data');
  await memory.hasMemory('data');

  /**
   * For windows uncomment the following
   */
  // sqfliteFfiInit();

  /**
   * For Linux do a onetime setup by running the following
   */
  // sudo apt-get -y install libsqlite3-0 libsqlite3-dev

  await QuickeyDB.initialize(
    dbName: "QuickeyDB.db",
    persist: true,
    dbVersion: 4,
    // For passing custom DB Location
    // dbPath: Directory.current.path,
    // For web pass dbPath as /database/web
    // dbPath: '/database/web',
    dataAccessObjects: [
      UserSchema(),
      TaskSchema(),
      DemoSchema(),
    ],
  );

  runApp(const ExampleApp());
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({Key? key}) : super(key: key);

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  GlobalKey globalKey = GlobalKey<FormState>();

  TextEditingController userName = TextEditingController();
  TextEditingController userPhone = TextEditingController();
  TextEditingController userEmail = TextEditingController();

  TextEditingController taskName = TextEditingController();
  TextEditingController taskBody = TextEditingController();

  TextEditingController taskLevel = TextEditingController();
  TextEditingController userAge = TextEditingController();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initCalculations();
    searchUser({
      'name': 'John Doe',
      'age': 10,
      'phone': '254712345678',
      'email': 'johndoe@gmail.com',
    });
  }

  Future<void> initCalculations() async {
    totalUserAge();
    minUserAge();
    maxUserAge();
    averageUserAge();
  }

  @override
  Widget build(BuildContext context) {
    // print(QuickeyDB.getInstance!<TaskColumn>()!.all);

    return MaterialApp(
      debugShowCheckedModeBanner: true,
      title: 'Flutter QuickeyDB',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter QuickeyDB'),
        ),
        body: SafeArea(
            child: FutureBuilder<List>(
          future: QuickeyDB.getInstance!<UserSchema>()
              ?.includes([TaskSchema]).toList(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Column(
                children: [
                  TextButton(
                      onPressed: () {
                        double width = context.size!.width;
                        double height = context.size!.height;
                        showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            title: const Text('Add User Task'),
                            content: SizedBox(
                              width: width,
                              height: height,
                              child: userTaskForm(globalKey),
                            ),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, 'Cancel'),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context, 'OK');
                                  if (userName.text.isNotEmpty &&
                                      userPhone.text.isNotEmpty &&
                                      userEmail.text.isNotEmpty &&
                                      taskName.text.isNotEmpty &&
                                      taskBody.text.isNotEmpty) {
                                    saveEntry();
                                  }
                                },
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text('Add Task')),
                  Container(
                    margin: const EdgeInsets.only(
                        top: 10, bottom: 10, right: 10, left: 10),
                    child: Card(
                      child: SizedBox(
                        height: 50,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(sum.toString()),
                                const Text(
                                  'Sum of User Age',
                                  style: TextStyle(fontSize: 8),
                                ),
                              ],
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(minimum.toString()),
                                const Text(
                                  'Minimum User Age',
                                  style: TextStyle(fontSize: 8),
                                ),
                              ],
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(maximum.toString()),
                                const Text(
                                  'Maximum User Age',
                                  style: TextStyle(fontSize: 8),
                                ),
                              ],
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(average.toString()),
                                const Text(
                                  'Average User Age',
                                  style: TextStyle(fontSize: 8),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                      child: ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, i) {
                      User item = snapshot.data![i];

                      return ListTile(
                        title: Text('${item.name!} : Age : (${item.age})'),
                        subtitle: Text(
                            'Has one Task: ${item.task != null ? item.task!.name : 'Not set'}'),
                        leading: IconButton(
                            onPressed: () {
                              userName.text = item.name!;
                              userPhone.text = item.phone!;
                              userEmail.text = item.email!;
                              taskName.text = item.task!.name;
                              taskBody.text = item.task!.body;

                              taskLevel.text = item.task!.level.toString();
                              userAge.text = item.age.toString();

                              showDialog<String>(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: Text(
                                          'Edit ${item.name} ${item.task!.name}Task'),
                                      content: SizedBox(
                                          height: 600,
                                          width: 600,
                                          child: userTaskForm(globalKey)),
                                      actions: <Widget>[
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, 'Cancel'),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            if (userName.text.isNotEmpty &&
                                                userPhone.text.isNotEmpty &&
                                                userEmail.text.isNotEmpty &&
                                                taskName.text.isNotEmpty &&
                                                userAge.text.isNotEmpty &&
                                                taskLevel.text.isNotEmpty &&
                                                taskBody.text.isNotEmpty) {
                                              User user = User(
                                                  name: userName.text,
                                                  email: userEmail.text,
                                                  phone: userPhone.text,
                                                  id: item.id,
                                                  age: int.parse(userAge.text));
                                              Task task = Task(
                                                  name: taskName.text,
                                                  body: taskBody.text,
                                                  id: item.task!.id,
                                                  level: int.parse(
                                                      taskLevel.text));

                                              editUserTask(user, task);
                                            }
                                            Navigator.pop(context, 'Cancel');
                                          },
                                          child: const Text('SUBMIT'),
                                        ),
                                      ],
                                    );
                                  });
                            },
                            icon: const Icon(Icons.edit)),
                        trailing: IconButton(
                            onPressed: () {
                              showDialog<String>(
                                context: context,
                                builder: (BuildContext context) => AlertDialog(
                                  title: Text(
                                      'Delete ${item.task == null ? '' : item.task!.name} Task'),
                                  content: const Text(
                                      'Are you sure you want to delete this task.?'),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, 'Cancel'),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context, 'OK');
                                        deleteUserTask(item);
                                      },
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.deepOrange,
                            )),
                      );
                    },
                  ))
                ],
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        )),
      ),
    );
  }

  Widget userTaskForm(GlobalKey globalKey) {
    return Form(
        key: globalKey,
        child: Container(
          margin: const EdgeInsets.all(10),
          child: ListView(
            children: [
              TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'User Name',
                ),
                controller: userName,
                // validator: (value) {
                //   if (value == null || value.isEmpty) {
                //     return 'Please enter User Name';
                //   }
                //   return null;
                // },
              ),
              const Divider(
                height: 10,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'User Phone',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r"[0-9]"),
                  )
                ],
                controller: userPhone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter User Phone';
                  }
                  return null;
                },
              ),
              const Divider(
                height: 10,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'User Email',
                ),
                controller: userEmail,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter User Email';
                  }
                  return null;
                },
              ),
              const Divider(
                height: 10,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'User Age',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r"[0-9]"),
                  )
                ],
                controller: userAge,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter User Age';
                  }
                  return null;
                },
              ),
              const Divider(
                height: 10,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Task Name',
                ),
                controller: taskName,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter Task Name';
                  }
                  return null;
                },
              ),
              const Divider(
                height: 10,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Task Body',
                ),
                controller: taskBody,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter Task Body';
                  }
                  return null;
                },
              ),
              const Divider(
                height: 10,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Task Level',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r"[0-9]"),
                  )
                ],
                controller: taskLevel,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter Task Level';
                  }
                  return null;
                },
              ),
              const Divider(
                height: 20,
              )
            ],
          ),
        ));
  }

  Future<void> saveEntry() async {
    try {
      await QuickeyDB.getInstance!<UserSchema>()?.create(
        User(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: userName.text,
          email: userEmail.text,
          phone: userPhone.text,
          task: Task(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              name: taskName.text,
              body: taskBody.text,
              level: int.parse(taskLevel.text)),
          age: int.parse(userAge.text),
        ),
      );
    } catch (error) {
      // print(error);
    }

    /**
     * Clear fields and refresh Page
     */
    userName.clear();
    userPhone.clear();
    userEmail.clear();
    userAge.clear();
    taskName.clear();
    taskBody.clear();
    taskLevel.clear();

    /**
     * I know theres a better way to handle this
     * But at the moment bear with me.
     */
    setState(() {
      initCalculations();
    });
  }

  Future<void> deleteUserTask(User user) async {
    await QuickeyDB.getInstance!<UserSchema>()!.delete(user);
    /**
     * I know theres a better way to handle this
     * But at the moment bear with me.
     */
    setState(() {
      initCalculations();
    });
  }

  Future<void> editUserTask(User user, Task task) async {
    await QuickeyDB.getInstance!<UserSchema>()!.update(user);
    await QuickeyDB.getInstance!<TaskSchema>()!.update(task);
    /**
     * Clear fields and refresh Page
     */
    userName.clear();
    userPhone.clear();
    userEmail.clear();
    userAge.clear();
    taskName.clear();
    taskBody.clear();
    taskLevel.clear();
    /**
     * I know theres a better way to handle this
     * But at the moment bear with me.
     */
    setState(() {});
  }

  int sum = 0;

  Future<void> totalUserAge() async {
    sum = await QuickeyDB.getInstance!<UserSchema>()!.sum('age') ?? 0;
  }

  int minimum = 0;

  Future<void> minUserAge() async {
    minimum = (await QuickeyDB.getInstance!<UserSchema>()!.minimum('age')) ?? 0;
    // print('{{{{{minimum}}}}}');
    // print(minimum);
    // print('{{{{{minimum}}}}}');
  }

  int maximum = 0;

  Future<void> maxUserAge() async {
    maximum = await QuickeyDB.getInstance!<UserSchema>()!.maximum('age') ?? 0;
    // print('{{{{{maximum}}}}}');
    // print(maximum);
    // print('{{{{{maximum}}}}}');
  }

  double average = 0;

  Future<void> averageUserAge() async {
    double avg =
        (await QuickeyDB.getInstance!<UserSchema>()!.average('age')) ?? 0;
    average = avg.roundToDouble();
    // print('{{{{{average}}}}}');
    // print(average);
    // print('{{{{{average}}}}}');
    setState(() {});
  }

  /// We can contruct a query based on subquery that return a QueryMethod.
  /// This is usefull when you intend to reuse queries
  Future<List<User?>?> searchUser(Map searchMap) async {
    QueryMethod<User?>? queryMethodUser = QuickeyDB.getInstance!<UserSchema>()!
        .where({'name': searchMap['name']});
    searchMap.forEach((key, value) {
      switch (key) {
        case 'email':
          {
            // search email
            queryMethodUser = emailQuery(queryMethodUser, searchMap['email']);
          }
          break;
        case 'phone':
          {
            // search name
            queryMethodUser = phoneQuery(queryMethodUser, searchMap['phone']);
          }
          break;
        default:
          {
            // search age
            queryMethodUser =
                ageQueryGreaterThan(queryMethodUser, searchMap['age']);
          }
          break;
      }
    });
    return await queryMethodUser?.toList();
  }

  /// Here we have a subQuery for phoneQuery *
  QueryMethod<User?>? phoneQuery(
      QueryMethod<User?>? queryMethod, String phone) {
    return queryMethod?.where({'phone': phone});
  }

  /// Here we have a subQuery for emailQuery *
  QueryMethod<User?>? emailQuery(
      QueryMethod<User?>? queryMethod, String email) {
    return queryMethod?.where({'email': email});
  }

  /// Here we have a subQuery for ageQueryGreaterThan *
  QueryMethod<User?>? ageQueryGreaterThan(
      QueryMethod<User?>? queryMethod, int age) {
    return queryMethod?.where({'age > ?': age});
  }
}
