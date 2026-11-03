import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../models/category.dart';

class DatabaseHelper {
  static final instance = DatabaseHelper();
  final DatabaseFactory? factory;
  final String? databasePath;
  Future<Database>? _opening;
  DatabaseHelper({this.factory, this.databasePath});
  Future<Database> get database => _opening ??= _open();
  Future<Database> _open() async {
    final f = factory ?? databaseFactory;
    final path =
        databasePath ??
        (kIsWeb ? 'notes.db' : join(await f.getDatabasesPath(), 'notes.db'));
    return f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        singleInstance: databasePath != inMemoryDatabasePath,
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT, cloudId TEXT NOT NULL,
          uid TEXT NOT NULL, title TEXT NOT NULL, content TEXT NOT NULL,
          date TEXT NOT NULL, category TEXT NOT NULL DEFAULT 'Pessoal',
          archived INTEGER NOT NULL DEFAULT 0, deleted INTEGER NOT NULL DEFAULT 0,
          dirty INTEGER NOT NULL DEFAULT 1, updatedAt INTEGER NOT NULL,
          reminderAt INTEGER, revision TEXT NOT NULL, UNIQUE(uid, cloudId))''');
          await _createExtra(db);
        },
        onUpgrade: (db, old, version) async {
          if (old < 2) {
            for (final sql in [
              'ALTER TABLE notes ADD COLUMN cloudId TEXT',
              "ALTER TABLE notes ADD COLUMN category TEXT NOT NULL DEFAULT 'Pessoal'",
              'ALTER TABLE notes ADD COLUMN archived INTEGER NOT NULL DEFAULT 0',
              'ALTER TABLE notes ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0',
              'ALTER TABLE notes ADD COLUMN dirty INTEGER NOT NULL DEFAULT 1',
              'ALTER TABLE notes ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0',
              'ALTER TABLE notes ADD COLUMN reminderAt INTEGER',
              'ALTER TABLE notes ADD COLUMN revision TEXT',
            ]) {
              await db.execute(sql);
            }
            for (final row in await db.query('notes')) {
              await db.update(
                'notes',
                {
                  'cloudId': const Uuid().v4(),
                  'revision': const Uuid().v4(),
                  'updatedAt': DateTime.now().toUtc().millisecondsSinceEpoch,
                },
                where: 'id = ?',
                whereArgs: [row['id']],
              );
            }
            await db.execute(
              'CREATE UNIQUE INDEX notes_cloud ON notes(uid, cloudId)',
            );
            await _createExtra(db);
          }
        },
      ),
    );
  }

  Future<void> _createExtra(Database db) async {
    await db.execute(
      'CREATE INDEX notes_user ON notes(uid, deleted, archived)',
    );
    await db.execute(
      '''CREATE TABLE categories (id TEXT NOT NULL, uid TEXT NOT NULL,
      name TEXT NOT NULL, dirty INTEGER NOT NULL DEFAULT 1, revision TEXT NOT NULL,
      PRIMARY KEY(uid, id))''',
    );
    await db.execute('''CREATE TABLE reminder_deliveries (uid TEXT NOT NULL,
      cloudId TEXT NOT NULL, reminderAt INTEGER NOT NULL,
      PRIMARY KEY(uid, cloudId, reminderAt))''');
  }

  Future<List<Note>> getNotes(
    String uid, {
    bool includeDeleted = false,
  }) async => (await (await database).query(
    'notes',
    where: includeDeleted ? 'uid = ?' : 'uid = ? AND deleted = 0',
    whereArgs: [uid],
    orderBy: 'updatedAt DESC, id DESC',
  )).map(Note.fromMap).toList();
  Future<void> saveNote(Note note) async {
    final map = note.toMap()..remove('id');
    await (await database).transaction((txn) async {
      final count = await txn.update(
        'notes',
        map,
        where: 'uid = ? AND cloudId = ?',
        whereArgs: [note.uid, note.cloudId],
      );
      if (count == 0) await txn.insert('notes', map);
    });
  }

  Future<List<NoteCategory>> getCategories(String uid) async =>
      (await (await database).query(
        'categories',
        where: 'uid = ?',
        whereArgs: [uid],
        orderBy: 'name COLLATE NOCASE',
      )).map(NoteCategory.fromMap).toList();
  Future<void> saveCategory(NoteCategory c) async {
    await (await database).insert(
      'categories',
      c.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Note>> pendingNotes(String uid) async => (await getNotes(
    uid,
    includeDeleted: true,
  )).where((n) => n.dirty).toList();

  /// Clear only the revision actually uploaded; an edit during upload stays dirty.
  Future<void> acknowledge(
    String table,
    String uid,
    String key,
    String revision,
  ) async {
    await (await database).update(
      table,
      {'dirty': 0},
      where:
          'uid = ? AND ${table == 'notes' ? 'cloudId' : 'id'} = ? AND revision = ?',
      whereArgs: [uid, key, revision],
    );
  }

  Future<void> mergeRemoteNote(Note note) async {
    await (await database).transaction((txn) async {
      final existing = await txn.query(
        'notes',
        where: 'uid = ? AND cloudId = ?',
        whereArgs: [note.uid, note.cloudId],
      );
      if (existing.isNotEmpty && existing.first['dirty'] == 1) return;
      final map = note.toMap()..remove('id');
      if (existing.isEmpty) {
        await txn.insert('notes', map);
      } else {
        await txn.update(
          'notes',
          map,
          where: 'uid = ? AND cloudId = ?',
          whereArgs: [note.uid, note.cloudId],
        );
      }
    });
  }

  Future<void> mergeRemoteCategory(NoteCategory c) async {
    await (await database).transaction((txn) async {
      final existing = await txn.query(
        'categories',
        where: 'uid = ? AND id = ?',
        whereArgs: [c.uid, c.id],
      );
      if (existing.isNotEmpty && existing.first['dirty'] == 1) return;
      await txn.insert(
        'categories',
        c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> markReminderDelivered(Note note) async {
    await (await database).insert('reminder_deliveries', {
      'uid': note.uid,
      'cloudId': note.cloudId,
      'reminderAt': note.reminderAt!.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<bool> reminderDelivered(Note note) async =>
      (await (await database).query(
        'reminder_deliveries',
        where: 'uid = ? AND cloudId = ? AND reminderAt = ?',
        whereArgs: [
          note.uid,
          note.cloudId,
          note.reminderAt!.millisecondsSinceEpoch,
        ],
      )).isNotEmpty;
  Future<void> close() async {
    if (_opening != null) await (await _opening!).close();
    _opening = null;
  }
}
