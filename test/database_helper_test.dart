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

  test('getNotes deixa de fora as notas pending_purge', () async {
    await db.insertNote(sample(id: 'a'));
    await db.insertNote(sample(id: 'b').copyWith(syncStatus: 'pending_purge'));

    final notes = await db.getNotes('user-1');

    expect(notes.map((n) => n.id), ['a']);
  });

  test('markSynced só marca a nota que não mudou desde o envio', () async {
    await db.insertNote(sample(id: 'a', updatedAt: 2000));
    await db.insertNote(sample(id: 'b', updatedAt: 3000));
    await db.insertNote(
      sample(id: 'c', updatedAt: 2000).copyWith(syncStatus: 'pending_purge'),
    );

    for (final id in ['a', 'b', 'c']) {
      await db.markSynced(id, 2000);
    }

    final status = {
      for (final note in await db.getAllNotes('user-1'))
        note.id: note.syncStatus,
    };
    expect(status, {'a': 'synced', 'b': 'pending', 'c': 'pending_purge'});
  });

  test('getCategories devolve as categorias distintas do uid', () async {
    await db.insertNote(sample(id: 'a', category: 'Estudos'));
    await db.insertNote(sample(id: 'b', category: 'Estudos'));
    await db.insertNote(sample(id: 'c', category: 'Faculdade'));
    await db.insertNote(sample(id: 'd'));
    await db.insertNote(sample(id: 'e', uid: 'user-2', category: 'Outro'));

    expect(
      await db.getCategories('user-1'),
      unorderedEquals(['Estudos', 'Faculdade']),
    );
  });

  test('getCategories ignora notas na lixeira e pending_purge', () async {
    await db.insertNote(sample(id: 'a', category: 'Estudos'));
    await db.insertNote(sample(id: 'b', category: 'Lixeira', deletedAt: 3000));
    await db.insertNote(
      sample(id: 'c', category: 'Purge').copyWith(syncStatus: 'pending_purge'),
    );

    expect(await db.getCategories('user-1'), ['Estudos']);
  });
}
