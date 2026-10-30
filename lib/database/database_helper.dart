import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
    final path = kIsWeb ? fileName : join(await getDatabasesPath(), fileName);

    return openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE notes ADD COLUMN category TEXT NOT NULL DEFAULT 'Pessoal'",
          );
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE notes ADD COLUMN cloud_id TEXT');
          await db.execute(
            'ALTER TABLE notes ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0',
          );
        }
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
          date TEXT NOT NULL,
          category TEXT NOT NULL DEFAULT 'Pessoal',
          cloud_id TEXT,
          is_synced INTEGER NOT NULL DEFAULT 0
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

  Future<void> saveCloudNote(Note note) async {
    final db = await instance.database;
    final existing = await db.query(
      'notes',
      columns: ['id'],
      where: 'uid = ? AND cloud_id = ?',
      whereArgs: [note.uid, note.cloudId],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert('notes', note.toMap());
    } else {
      final id = existing.first['id'] as int;
      await db.update(
        'notes',
        note.copyWith(id: id, isSynced: true).toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<int> deleteNote(int id) async {
    final db = await instance.database;

    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }
}
