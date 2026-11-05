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

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
        CREATE TABLE notes(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firebaseId TEXT,
          uid TEXT NOT NULL,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          category TEXT NOT NULL,
          date TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0,
          trashed INTEGER NOT NULL DEFAULT 0,
          deleted INTEGER NOT NULL DEFAULT 0
        )
      ''');

    await _createCategoriesTable(db);
  }

  Future<void> _createCategoriesTable(Database db) async {
    await db.execute('''
        CREATE TABLE categories(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          uid TEXT NOT NULL,
          name TEXT NOT NULL
        )
      ''');
  }

  // Quem já tinha o banco na versão 1 não perde as notas,
  // só ganha as colunas novas.
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE notes ADD COLUMN firebaseId TEXT");
      await db.execute("ALTER TABLE notes ADD COLUMN category TEXT NOT NULL DEFAULT 'Pessoal'");
      await db.execute("ALTER TABLE notes ADD COLUMN createdAt INTEGER NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE notes ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE notes ADD COLUMN synced INTEGER NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE notes ADD COLUMN trashed INTEGER NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE notes ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0");

      // as notas antigas ganham um id aleatório para usar no Firestore
      await db.execute("UPDATE notes SET firebaseId = lower(hex(randomblob(10)))");

      await _createCategoriesTable(db);
    }
  }

  Future<int> insertNote(Note note) async {
    final db = await instance.database;

    return await db.insert('notes', note.toMap());
  }

  Future<List<Note>> getNotes(String uid) async {
    final db = await instance.database;

    final result = await db.query(
      "notes",

      // não mostra as notas da lixeira nem as excluídas
      where: "uid = ? AND trashed = 0 AND deleted = 0",

      whereArgs: [uid],

      orderBy: "updatedAt DESC",
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  // todas as notas do usuário, inclusive lixeira e excluídas (usado na sincronização)
  Future<List<Note>> getAllNotes(String uid) async {
    final db = await instance.database;

    final result = await db.query(
      "notes",
      where: "uid = ?",
      whereArgs: [uid],
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  // alterações que ainda não foram enviadas para o Firebase
  Future<List<Note>> getPendingNotes(String uid) async {
    final db = await instance.database;

    final result = await db.query(
      "notes",
      where: "uid = ? AND synced = 0",
      whereArgs: [uid],
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<Note?> getNoteByFirebaseId(String uid, String firebaseId) async {
    final db = await instance.database;

    final result = await db.query(
      "notes",
      where: "uid = ? AND firebaseId = ?",
      whereArgs: [uid, firebaseId],
    );

    if (result.isEmpty) {
      return null;
    }

    return Note.fromMap(result.first);
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

  // Só marca como sincronizada se a nota não foi alterada
  // enquanto estava sendo enviada (por isso compara o updatedAt).
  Future<void> markAsSynced(String firebaseId, int updatedAt) async {
    final db = await instance.database;

    await db.update(
      'notes',
      {'synced': 1},
      where: "firebaseId = ? AND updatedAt = ?",
      whereArgs: [firebaseId, updatedAt],
    );
  }

  // A nota some do app, mas a linha continua no SQLite até
  // a exclusão ser feita no Firebase também.
  Future<void> markAsDeleted(int id) async {
    final db = await instance.database;

    await db.update(
      'notes',
      {'deleted': 1, 'synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteNote(int id) async{
    final db = await instance.database;

    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
