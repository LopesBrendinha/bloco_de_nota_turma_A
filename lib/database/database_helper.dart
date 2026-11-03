
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
    }

    _database = await _initDB('notes.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
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
        category TEXT NOT NULL DEFAULT 'Geral',
        cloud_id TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_favorite INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _upgradeDB(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE notes ADD COLUMN category TEXT NOT NULL DEFAULT 'Geral'",
      );

      await db.execute(
        'ALTER TABLE notes ADD COLUMN cloud_id TEXT',
      );

      await db.execute(
        'ALTER TABLE notes ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0',
      );
    }

    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE notes ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  // INSERIR NOTA
  Future<int> insertNote(Note note) async {
    final db = await database;

    return db.insert('notes', note.toMap());
  }

  // BUSCAR NOTAS DE UM USUÁRIO
  Future<List<Note>> getNotes(String uid) async {
    final db = await database;

    final result = await db.query(
      'notes',
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: 'id DESC',
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  // BUSCAR SOMENTE NOTAS FAVORITAS
  Future<List<Note>> getFavoriteNotes(String uid) async {
    final db = await database;

    final result = await db.query(
      'notes',
      where: 'uid = ? AND is_favorite = 1',
      whereArgs: [uid],
      orderBy: 'id DESC',
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  // ATUALIZAR NOTA
  Future<int> updateNote(Note note) async {
    final db = await database;

    return db.update(
      'notes',
      note.toMap(),
      where: 'id = ? AND uid = ?',
      whereArgs: [note.id, note.uid],
    );
  }

  // ALTERAR STATUS DE FAVORITO
  Future<int> updateFavoriteStatus(
    int id,
    String uid,
    bool isFavorite,
  ) async {
    final db = await database;

    return db.update(
      'notes',
      {
        'is_favorite': isFavorite ? 1 : 0,
        'is_synced': 0,
      },
      where: 'id = ? AND uid = ?',
      whereArgs: [id, uid],
    );
  }

  // EXCLUIR NOTA
  Future<int> deleteNote(int id) async {
    final db = await database;

    return db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // BUSCAR NOTAS PENDENTES DE SINCRONIZAÇÃO
  Future<List<Note>> getUnsyncedNotes(String uid) async {
    final db = await database;

    final result = await db.query(
      'notes',
      where: 'uid = ? AND is_synced = 0',
      whereArgs: [uid],
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  // ATUALIZAR INFORMAÇÕES DE SINCRONIZAÇÃO
  Future<void> updateSyncInfo(
    int id,
    String uid,
    String cloudId,
  ) async {
    final db = await database;

    await db.update(
      'notes',
      {
        'cloud_id': cloudId,
        'is_synced': 1,
      },
      where: 'id = ? AND uid = ?',
      whereArgs: [id, uid],
    );
  }

  // INSERIR OU ATUALIZAR NOTA RECEBIDA DA NUVEM
  Future<void> upsertCloudNote(Note note) async {
    final db = await database;

    final existing = await db.query(
      'notes',
      where: 'cloud_id = ? AND uid = ?',
      whereArgs: [note.cloudId, note.uid],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert('notes', note.toMap());
    } else {
      final localNote = Note.fromMap(existing.first);

      // Preserva alterações locais ainda não sincronizadas.
      if (!localNote.isSynced) {
        return;
      }

      await db.update(
        'notes',
        {
          'title': note.title,
          'content': note.content,
          'date': note.date,
          'category': note.category,
          'is_favorite': note.isFavorite ? 1 : 0,
          'is_synced': 1,
        },
        where: 'id = ? AND uid = ?',
        whereArgs: [localNote.id, note.uid],
      );
    }
  }
}
