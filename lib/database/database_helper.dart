import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// Acesso ao SQLite local. As telas não usam esta classe: elas falam com o NoteRepository.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    } else {
      _database = await _initDB('notes.db');

      return _database!;
    }
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
        CREATE TABLE notes(
          id TEXT PRIMARY KEY,
          uid TEXT NOT NULL,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          category TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          sync_status TEXT NOT NULL DEFAULT 'pending'
        )
      ''');
  }

  Future<int> insertNote(Note note) async {
    final db = await instance.database;

    return await db.insert('notes', note.toMap());
  }

  Future<List<Note>> getNotes(String uid) async {
    final db = await instance.database;

    final result = await db.query(
      "notes",

      where: "uid = ? AND deleted_at IS NULL",

      whereArgs: [uid],

      orderBy: "updated_at DESC",
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<List<Note>> getTrash(String uid) async {
    final db = await instance.database;

    final result = await db.query(
      "notes",
      where: "uid = ? AND deleted_at IS NOT NULL AND sync_status != 'pending_purge'",
      whereArgs: [uid],
      orderBy: "deleted_at DESC",
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<int> updateNote(Note note) async {
    final db = await instance.database;

    return await db.update(
      'notes',
      note.toMap(),

      where: "id = ?",

      whereArgs: [note.id],
    );
  }

  Future<int> deleteNotePermanently(String id) async {
    final db = await instance.database;

    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
