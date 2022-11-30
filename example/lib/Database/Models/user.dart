import 'task.dart';

class User {
  // int? id;
  String? id;
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
