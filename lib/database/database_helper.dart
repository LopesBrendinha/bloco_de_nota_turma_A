import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Acesso ao banco local (SQLite). Padrão Singleton: existe uma única
/// instância usada por todo o app.
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
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'Pessoal',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Exclusões definitivas que ainda precisam ser enviadas ao Firebase.
    await db.execute('''
      CREATE TABLE pending_deletes(
        id TEXT NOT NULL,
        uid TEXT NOT NULL,
        PRIMARY KEY (id, uid)
      )
    ''');
  }

  /// A versão 1 do banco tinha um erro de sintaxe no CREATE TABLE (vírgula
  /// sobrando), então a tabela nunca chegou a ser criada e não há dados a
  /// preservar. Recriamos tudo na versão 2.
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    await db.execute('DROP TABLE IF EXISTS notes');
    await db.execute('DROP TABLE IF EXISTS pending_deletes');
    await _createDB(db, newVersion);
  }

  // ---------- Notas ----------

  /// Insere ou substitui (se o ID já existir) uma nota.
  Future<void> saveNote(Note note) async {
    final db = await instance.database;

    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Note?> getNoteById(String id, String uid) async {
    final db = await instance.database;

    final result = await db.query(
      'notes',
      where: 'id = ? AND uid = ?',
      whereArgs: [id, uid],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return Note.fromMap(result.first);
  }

  /// Lista as notas do usuário. Com [trash] = true devolve a lixeira.
  /// [query] procura no título e no conteúdo; [category] filtra por categoria.
  Future<List<Note>> getNotes(
    String uid, {
    String query = '',
    String? category,
    bool trash = false,
  }) async {
    final db = await instance.database;

    final where = StringBuffer('uid = ? AND deleted = ?');
    final args = <Object?>[uid, trash ? 1 : 0];

    if (category != null && category.isNotEmpty) {
      where.write(' AND category = ?');
      args.add(category);
    }

    final text = query.trim();
    if (text.isNotEmpty) {
      // Escapa os curingas do LIKE para que "%" e "_" sejam pesquisados
      // como texto comum.
      final escaped = text
          .replaceAll('\\', '\\\\')
          .replaceAll('%', '\\%')
          .replaceAll('_', '\\_');

      where.write(
        " AND (title LIKE ? ESCAPE '\\' OR content LIKE ? ESCAPE '\\')",
      );
      args.add('%$escaped%');
      args.add('%$escaped%');
    }

    final result = await db.query(
      'notes',
      where: where.toString(),
      whereArgs: args,
      orderBy: trash ? 'deleted_at DESC' : 'updated_at DESC',
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  /// Categorias que existem nas notas ativas do usuário.
  Future<List<String>> getCategories(String uid) async {
    final db = await instance.database;

    final result = await db.rawQuery(
      'SELECT DISTINCT category FROM notes '
      'WHERE uid = ? AND deleted = 0 '
      'ORDER BY category COLLATE NOCASE',
      [uid],
    );

    return result.map((row) => row['category'] as String).toList();
  }

  /// Notas com alterações ainda não enviadas ao Firebase.
  Future<List<Note>> getUnsyncedNotes(String uid) async {
    final db = await instance.database;

    final result = await db.query(
      'notes',
      where: 'uid = ? AND synced = 0',
      whereArgs: [uid],
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  /// IDs das notas que já foram confirmadas no Firebase.
  Future<List<String>> getSyncedIds(String uid) async {
    final db = await instance.database;

    final result = await db.query(
      'notes',
      columns: ['id'],
      where: 'uid = ? AND synced = 1',
      whereArgs: [uid],
    );

    return result.map((row) => row['id'] as String).toList();
  }

  /// Marca como sincronizada, mas só se a nota não mudou desde o envio
  /// (compara updated_at), para não esconder uma edição mais recente.
  Future<void> markSynced(String id, int updatedAt) async {
    final db = await instance.database;

    await db.update(
      'notes',
      {'synced': 1},
      where: 'id = ? AND updated_at = ?',
      whereArgs: [id, updatedAt],
    );
  }

  Future<void> deleteNote(String id) async {
    final db = await instance.database;

    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Exclusões pendentes ----------

  Future<void> addPendingDelete(String id, String uid) async {
    final db = await instance.database;

    await db.insert(
      'pending_deletes',
      {'id': id, 'uid': uid},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<String>> getPendingDeletes(String uid) async {
    final db = await instance.database;

    final result = await db.query(
      'pending_deletes',
      where: 'uid = ?',
      whereArgs: [uid],
    );

    return result.map((row) => row['id'] as String).toList();
  }

  Future<bool> isPendingDelete(String id, String uid) async {
    final db = await instance.database;

    final result = await db.query(
      'pending_deletes',
      where: 'id = ? AND uid = ?',
      whereArgs: [id, uid],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  Future<void> removePendingDelete(String id, String uid) async {
    final db = await instance.database;

    await db.delete(
      'pending_deletes',
      where: 'id = ? AND uid = ?',
      whereArgs: [id, uid],
    );
  }
}
