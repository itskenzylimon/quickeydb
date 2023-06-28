class Demo {
  // int? id;
  String? id;
  String name;
  String body;

  Demo({this.id, required this.name, required this.body});

  Demo.fromMap(Map<String?, dynamic> map)
      : id = map['id'],
        name = map['name'],
        body = map['body'];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'body': body,
      };

  Map<String, dynamic> toTableMap() => {'id': id, 'name': name, 'body': body};
}
