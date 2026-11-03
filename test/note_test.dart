import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/repositories/note_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Note sample({String? category, int? deletedAt}) => Note(
  id: 'abc123',
  uid: 'user-1',
  title: 'Título',
  content: 'Conteúdo',
  category: category,
  createdAt: 1000,
  updatedAt: 2000,
  deletedAt: deletedAt,
  syncStatus: 'pending',
);

void main() {
  test('toMap/fromMap com campos opcionais nulos', () {
    final note = sample();
    expect(Note.fromMap(note.toMap()).toMap(), note.toMap());
    expect(note.toMap()['category'], isNull);
    expect(note.toMap()['deleted_at'], isNull);
  });

  test('toMap/fromMap com campos opcionais preenchidos', () {
    final note = sample(category: 'Estudos', deletedAt: 3000);
    final copy = Note.fromMap(note.toMap());
    expect(copy.toMap(), note.toMap());
    expect(copy.category, 'Estudos');
    expect(copy.deletedAt, 3000);
  });

  test('toMap usa os nomes das colunas', () {
    expect(sample().toMap().keys, [
      'id',
      'uid',
      'title',
      'content',
      'category',
      'created_at',
      'updated_at',
      'deleted_at',
      'sync_status',
    ]);
  });

  test('copyWith mantém o id', () {
    final edited = sample().copyWith(title: 'Novo', updatedAt: 5000);
    expect(edited.id, 'abc123');
    expect(edited.title, 'Novo');
    expect(edited.updatedAt, 5000);
    expect(edited.createdAt, 1000);
  });

  test('newNoteId gera 20 caracteres de [A-Za-z0-9]', () {
    final id = newNoteId();
    expect(id, matches(RegExp(r'^[A-Za-z0-9]{20}$')));
    expect(newNoteId(), isNot(id));
  });
}
