import 'user.dart';

class Task {
  // int? id;
  String? id;
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
        'user': user?.toMap(),
      };

  Map<String, dynamic> toTableMap() => {
        'id': id,
        'name': name,
        'body': body,
        'level': level,
      };
}
