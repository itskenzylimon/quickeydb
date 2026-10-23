import 'package:quickeydb/quickeydb.dart';

class Note {
  const Note({this.id, required this.title, required this.body});
  final int? id;
  final String title, body;
  Map<String, Object?> toMap() => {'id': id, 'title': title, 'body': body};
  factory Note.fromMap(Map<String?, dynamic> row) => Note(
      id: row['id'] as int?,
      title: row['title'] as String,
      body: row['body'] as String);
}

class NotesDao extends DataAccessObject<Note> {
  NotesDao({ConflictAlgorithm? insertConflictAlgorithm})
      : super('''
CREATE TABLE notes (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 title TEXT NOT NULL,
 body TEXT NOT NULL
)
''',
            encryptedColumns: {'body'},
            insertConflictAlgorithm: insertConflictAlgorithm,
            converter: Converter<Note?>(
                encode: Note.fromMap,
                decode: (note) => note!.toMap(),
                decodeTable: (note) => note!.toMap()));
}
