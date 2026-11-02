import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Acesso ao banco local (SQLite). É a fonte de verdade para a interface:
/// a tela sempre lê daqui, e a sincronização com o Firebase atualiza este banco.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    _database ??= await _initDB('notes.db');

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
    // Atenção: não pode haver vírgula depois da última coluna.
    await db.execute('''
      CREATE TABLE notes(
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        synced INTEGER NOT NULL DEFAULT 0,
        purged INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('CREATE INDEX idx_notes_uid ON notes(uid)');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // A versão 1 tinha um erro de sintaxe no CREATE TABLE e nunca chegou a
    // criar a tabela, portanto não há dados a preservar.
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS notes');
      await _createDB(db, newVersion);
    }
  }

  /// Insere ou substitui a nota (o ID é a chave primária).
  Future<void> upsertNote(Note note) async {
    final db = await instance.database;

    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Note?> getById(String id) async {
    final db = await instance.database;

    final rows = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return Note.fromMap(rows.first);
  }

  /// Lista as notas do usuário.
  ///
  /// * [trash]: `false` lista as notas ativas, `true` lista a lixeira.
  /// * [search]: texto procurado no título ou no conteúdo.
  /// * [category]: filtra por categoria.
  Future<List<Note>> queryNotes({
    required String uid,
    bool trash = false,
    String search = '',
    String? category,
    NoteSort sort = NoteSort.updatedAt,
  }) async {
    final db = await instance.database;

    final where = StringBuffer('uid = ? AND purged = 0 AND deleted = ?');
    final args = <Object?>[uid, trash ? 1 : 0];

    final term = search.trim();
    if (term.isNotEmpty) {
      final like = '%${_escapeLike(term)}%';

      where.write(" AND (title LIKE ? ESCAPE '\\' OR content LIKE ? ESCAPE '\\')");
      args.addAll([like, like]);
    }

    if (category != null && category.isNotEmpty) {
      where.write(' AND category = ?');
      args.add(category);
    }

    final String orderBy;
    if (trash) {
      orderBy = 'deleted_at DESC';
    } else if (sort == NoteSort.createdAt) {
      orderBy = 'created_at DESC';
    } else {
      orderBy = 'updated_at DESC';
    }

    final rows = await db.query(
      'notes',
      where: where.toString(),
      whereArgs: args,
      orderBy: orderBy,
    );

    return rows.map(Note.fromMap).toList();
  }

  /// Categorias que o usuário já utilizou em notas ativas.
  Future<List<String>> getCategories(String uid) async {
    final db = await instance.database;

    final rows = await db.rawQuery(
      'SELECT DISTINCT category FROM notes '
      'WHERE uid = ? AND purged = 0 AND deleted = 0 '
      'ORDER BY category COLLATE NOCASE',
      [uid],
    );

    return rows.map((row) => row['category'] as String).toList();
  }

  /// Notas com alterações que ainda não chegaram ao Firebase
  /// (inclui as marcadas para exclusão definitiva).
  Future<List<Note>> getPendingNotes(String uid) async {
    final db = await instance.database;

    final rows = await db.query(
      'notes',
      where: 'uid = ? AND synced = 0',
      whereArgs: [uid],
    );

    return rows.map(Note.fromMap).toList();
  }

  /// Notas que já foram enviadas ao Firebase.
  Future<List<Note>> getSyncedNotes(String uid) async {
    final db = await instance.database;

    final rows = await db.query(
      'notes',
      where: 'uid = ? AND synced = 1',
      whereArgs: [uid],
    );

    return rows.map(Note.fromMap).toList();
  }

  /// Marca a nota como sincronizada, mas somente se ela não foi alterada
  /// enquanto o envio estava em andamento (compara `updated_at`).
  Future<void> markSynced(String id, int updatedAtMs) async {
    final db = await instance.database;

    await db.update(
      'notes',
      {'synced': 1},
      where: 'id = ? AND updated_at = ?',
      whereArgs: [id, updatedAtMs],
    );
  }

  Future<void> deleteById(String id) async {
    final db = await instance.database;

    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  /// Escapa `%`, `_` e `\` para que sejam tratados como texto comum no LIKE.
  String _escapeLike(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }
}
