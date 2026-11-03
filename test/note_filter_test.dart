import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/repositories/note_filter.dart';
import 'package:flutter_test/flutter_test.dart';

Note note(
  String id, {
  String title = '',
  String content = '',
  String? category,
}) => Note(
  id: id,
  uid: 'user-1',
  title: title,
  content: content,
  category: category,
  createdAt: 1000,
  updatedAt: 1000,
  syncStatus: 'synced',
);

final notes = [
  note('1', title: 'Compras', content: 'Comprar ÁGUA e pão', category: 'Pessoal'),
  note('2', title: 'Prova de Cálculo', content: 'Estudar derivadas', category: 'Estudos'),
  note('3', title: 'Reunião', content: 'Pauta do projeto', category: 'Trabalho'),
  note('4', title: 'Ideias', content: 'Nota solta'),
];

List<String> ids(List<Note> result) => result.map((n) => n.id).toList();

void main() {
  test('pesquisa vazia devolve todas as notas', () {
    expect(ids(filterNotes(notes)), ['1', '2', '3', '4']);
    expect(ids(filterNotes(notes, query: '   ')), ['1', '2', '3', '4']);
  });

  test('encontra pelo título', () {
    expect(ids(filterNotes(notes, query: 'reunião')), ['3']);
  });

  test('encontra pelo conteúdo', () {
    expect(ids(filterNotes(notes, query: 'derivadas')), ['2']);
  });

  test('ignora maiúsculas, inclusive com acento', () {
    expect(ids(filterNotes(notes, query: 'água')), ['1']);
    expect(ids(filterNotes(notes, query: 'CÁLCULO')), ['2']);
  });

  test('filtra por categoria, ignorando maiúsculas', () {
    expect(ids(filterNotes(notes, category: 'Estudos')), ['2']);
    expect(ids(filterNotes(notes, category: 'estudos')), ['2']);
  });

  test('pesquisa e categoria juntas', () {
    expect(ids(filterNotes(notes, query: 'pão', category: 'Pessoal')), ['1']);
    expect(filterNotes(notes, query: 'pão', category: 'Trabalho'), isEmpty);
  });

  test('mergeCategories junta padrão e do usuário sem repetir', () {
    expect(mergeCategories(['estudos', 'Faculdade', 'faculdade']), [
      'Estudos',
      'Faculdade',
      'Pessoal',
      'Trabalho',
    ]);
  });
}
