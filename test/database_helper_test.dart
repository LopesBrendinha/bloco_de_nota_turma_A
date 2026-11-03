import 'package:bloco_de_nota_turma_a/database/database_helper.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Note sample({
  required String id,
  String uid = 'user-1',
  int updatedAt = 2000,
  String? category,
  int? deletedAt,
}) => Note(
  id: id,
  uid: uid,
  title: 'Título $id',
  content: 'Conteúdo $id',
  category: category,
  createdAt: 1000,
  updatedAt: updatedAt,
  deletedAt: deletedAt,
  syncStatus: 'pending',
);

void main() {
  final db = DatabaseHelper.instance;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Um notes.db de uma execução anterior pode ter outro esquema.
    await databaseFactory.deleteDatabase(
      join(await getDatabasesPath(), 'notes.db'),
    );
  });

  setUp(() async {
    await (await db.database).delete('notes');
  });

  test('insertNote e getNotes devolvem todos os campos intactos', () async {
    final plain = sample(id: 'a', updatedAt: 2000);
    final full = sample(id: 'b', updatedAt: 1500, category: 'Estudos');
    await db.insertNote(plain);
    await db.insertNote(full);

    final notes = await db.getNotes('user-1');

    expect(notes.map((n) => n.toMap()), [plain.toMap(), full.toMap()]);
    expect(notes[0].category, isNull);
    expect(notes[1].category, 'Estudos');
  });

  test('deletedAt preenchido é gravado e lido de volta', () async {
    await db.insertNote(sample(id: 'a', deletedAt: 3000));

    final rows = await (await db.database).query('notes');

    expect(Note.fromMap(rows.single).deletedAt, 3000);
  });

  test('getNotes devolve só as notas do uid', () async {
    await db.insertNote(sample(id: 'a', uid: 'user-1'));
    await db.insertNote(sample(id: 'b', uid: 'user-2'));

    final notes = await db.getNotes('user-1');

    expect(notes.map((n) => n.id), ['a']);
  });

  test('getNotes deixa de fora as notas excluídas', () async {
    await db.insertNote(sample(id: 'a'));
    await db.insertNote(sample(id: 'b', deletedAt: 3000));

    final notes = await db.getNotes('user-1');

    expect(notes.map((n) => n.id), ['a']);
  });

  test('getNotes ordena por updated_at, mais recente primeiro', () async {
    await db.insertNote(sample(id: 'a', updatedAt: 1000));
    await db.insertNote(sample(id: 'b', updatedAt: 3000));
    await db.insertNote(sample(id: 'c', updatedAt: 2000));

    final notes = await db.getNotes('user-1');

    expect(notes.map((n) => n.id), ['b', 'c', 'a']);
  });

  test('updateNote altera a linha', () async {
    final note = sample(id: 'a');
    await db.insertNote(note);

    await db.updateNote(
      note.copyWith(title: 'Novo', updatedAt: 5000, syncStatus: 'synced'),
    );

    final updated = (await db.getNotes('user-1')).single;
    expect(updated.title, 'Novo');
    expect(updated.updatedAt, 5000);
    expect(updated.syncStatus, 'synced');
  });

  test('deleteNotePermanently apaga a linha', () async {
    await db.insertNote(sample(id: 'a'));
    await db.insertNote(sample(id: 'b'));

    await db.deleteNotePermanently('a');

    final rows = await (await db.database).query('notes');
    expect(rows.map((r) => r['id']), ['b']);
  });
}
