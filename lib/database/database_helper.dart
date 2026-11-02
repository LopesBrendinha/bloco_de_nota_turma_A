
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/note.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;

    final path = kIsWeb
        ? 'caderno_de_bolso_web.db'
        : join(
            await getDatabasesPath(),
            'caderno_de_bolso.db',
          );

    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cloudId TEXT NOT NULL UNIQUE,
            uid TEXT NOT NULL,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            category TEXT NOT NULL,
            date TEXT NOT NULL,
            pinned INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE notes ADD COLUMN cloudId TEXT NOT NULL DEFAULT ''",
          );

          await db.execute(
            "ALTER TABLE notes ADD COLUMN category TEXT NOT NULL DEFAULT 'Geral'",
          );

          await db.execute(
            'ALTER TABLE notes ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0',
          );

          await db.execute(
            "UPDATE notes SET cloudId = 'local-' || id",
          );
        }
      },
    );

    return _db!;
  }

  Future<List<Note>> getNotes(String uid) async {
    final db = await database;

    final rows = await db.query(
      'notes',
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: 'pinned DESC, id DESC',
    );

    return rows.map(Note.fromMap).toList();
  }

  Future<void> save(Note note) async {
    final db = await database;

    final data = note.toMap()..remove('id');

    await db.insert(
      'notes',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String cloudId, String uid) async {
    final db = await database;

    await db.delete(
      'notes',
      where: 'cloudId = ? AND uid = ?',
      whereArgs: [cloudId, uid],
    );
  }
}
