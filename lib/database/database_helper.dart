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

      where: "uid = ? AND deleted_at IS NULL AND sync_status != 'pending_purge'",

      whereArgs: [uid],

      orderBy: "updated_at DESC",
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<List<String>> getCategories(String uid) async {
    final db = await instance.database;

    final result = await db.rawQuery(
      "SELECT DISTINCT category FROM notes "
      "WHERE uid = ? AND category IS NOT NULL AND deleted_at IS NULL "
      "AND sync_status != 'pending_purge'",
      [uid],
    );

    return result.map((row) => row['category'] as String).toList();
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

  Future<List<Note>> getNotesBySyncStatus(String uid, String status) async {
    final db = await instance.database;

    final result = await db.query(
      'notes',
      where: 'uid = ? AND sync_status = ?',
      whereArgs: [uid, status],
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  // Todas as notas do usuário, inclusive as da lixeira e as pending_purge.
  // Só a sincronização usa: as telas usam getNotes.
  Future<List<Note>> getAllNotes(String uid) async {
    final db = await instance.database;

    final result = await db.query(
      'notes',
      where: 'uid = ?',
      whereArgs: [uid],
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<void> upsertNote(Note note) async {
    final db = await instance.database;

    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Só marca se a nota não mudou desde o envio (mesmo updated_at, ainda
  // pending). Uma edição ou um "excluir de vez" feito durante o upsert fica
  // pending e sobe no próximo ciclo.
  Future<void> markSynced(String id, int updatedAt) async {
    final db = await instance.database;

    await db.rawUpdate(
      "UPDATE notes SET sync_status = 'synced' "
      "WHERE id = ? AND updated_at = ? AND sync_status = 'pending'",
      [id, updatedAt],
    );
  }
}
