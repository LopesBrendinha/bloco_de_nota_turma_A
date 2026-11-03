import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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

    return openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE notes ADD COLUMN cloudId TEXT');
          await db.execute(
            'ALTER TABLE notes ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 3) await _createPendingDeletions(db);
        if (oldVersion < 4) {
          await db.execute(
            "ALTER TABLE notes ADD COLUMN category TEXT NOT NULL DEFAULT 'Geral'",
          );
          await _createCategories(db);
        }
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS notes_uid_cloud_id '
          'ON notes(uid, cloudId)',
        );
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
        CREATE TABLE notes(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          uid TEXT NOT NULL,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          category TEXT NOT NULL DEFAULT 'Geral',
          date TEXT NOT NULL,
          cloudId TEXT,
          updatedAt INTEGER NOT NULL DEFAULT 0
        )
      ''');
    await db.execute(
      'CREATE UNIQUE INDEX notes_uid_cloud_id ON notes(uid, cloudId)',
    );
    await _createPendingDeletions(db);
    await _createCategories(db);
  }

  Future<void> _createPendingDeletions(Database db) => db.execute('''
    CREATE TABLE pending_deletions(
      uid TEXT NOT NULL,
      cloudId TEXT NOT NULL,
      PRIMARY KEY(uid, cloudId)
    )
  ''');

  Future<void> _createCategories(Database db) => db.execute('''
    CREATE TABLE note_categories(
      uid TEXT NOT NULL,
      name TEXT NOT NULL,
      PRIMARY KEY(uid, name COLLATE NOCASE)
    )
  ''');

  Future<void> saveCategory(String uid, String name) async {
    final db = await instance.database;
    await db.insert('note_categories', {
      'uid': uid,
      'name': name.trim(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<String>> getCategories(String uid) async {
    final db = await instance.database;
    final rows = await db.query(
      'note_categories',
      columns: ['name'],
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map((row) => row['name'] as String).toList();
  }

  Future<int> insertNote(Note note) async {
    final db = await instance.database;

    return await db.insert('notes', note.toMap());
  }

  Future<void> upsertNote(Note note) async {
    final db = await instance.database;
    await db.insert(
      'notes',
      note.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Note>> getNotes(String uid) async {
    final db = await instance.database;

    final result = await db.query(
      "notes",

      where: "uid = ?",

      whereArgs: [uid],

      orderBy: "id DESC",
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

  Future<int> deleteNote(int id) async {
    final db = await instance.database;

    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteNoteForUser(int id, String uid) async {
    final db = await instance.database;
    return db.delete(
      'notes',
      where: 'id = ? AND uid = ?',
      whereArgs: [id, uid],
    );
  }

  Future<void> queueDeletion(String uid, String cloudId) async {
    final db = await instance.database;
    await db.insert('pending_deletions', {
      'uid': uid,
      'cloudId': cloudId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<String>> getPendingDeletions(String uid) async {
    final db = await instance.database;
    final rows = await db.query(
      'pending_deletions',
      columns: ['cloudId'],
      where: 'uid = ?',
      whereArgs: [uid],
    );
    return rows.map((row) => row['cloudId'] as String).toList();
  }

  Future<void> clearPendingDeletion(String uid, String cloudId) async {
    final db = await instance.database;
    await db.delete(
      'pending_deletions',
      where: 'uid = ? AND cloudId = ?',
      whereArgs: [uid, cloudId],
    );
  }
}
