import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/services/note_search.dart';
import 'package:bloco_de_nota_turma_a/services/note_sorting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes note fields for local storage and restores them', () {
    final note = Note(
      id: 12,
      uid: 'user-123',
      title: 'Compras',
      content: 'Café e pão',
      category: 'Pessoal',
      date: '03/11/2026 19:30',
      cloudId: 'cloud-note-1',
      updatedAt: 1793748600000,
    );

    final restored = Note.fromMap(note.toMap());

    expect(restored.id, 12);
    expect(restored.uid, 'user-123');
    expect(restored.title, 'Compras');
    expect(restored.content, 'Café e pão');
    expect(restored.category, 'Pessoal');
    expect(restored.date, '03/11/2026 19:30');
    expect(restored.cloudId, 'cloud-note-1');
    expect(restored.updatedAt, 1793748600000);
  });

  test('assigns a timestamp when one is not provided', () {
    final before = DateTime.now().millisecondsSinceEpoch;
    final note = Note(
      uid: 'user-123',
      title: 'Rascunho',
      content: '',
      date: '03/11/2026 19:30',
    );

    expect(note.updatedAt, greaterThanOrEqualTo(before));
  });

  test('sorts notes by last update in either direction', () {
    final older = Note(
      uid: 'user-123',
      title: 'Antiga',
      content: '',
      date: '01/11/2026 10:00',
      updatedAt: 100,
    );
    final newer = Note(
      uid: 'user-123',
      title: 'Recente',
      content: '',
      date: '03/11/2026 10:00',
      updatedAt: 200,
    );

    expect(sortNotesByUpdatedAt([older, newer]).first.title, 'Recente');
    expect(
      sortNotesByUpdatedAt([older, newer], newestFirst: false).first.title,
      'Antiga',
    );
  });

  test('searches title or content and combines category filters', () {
    final notes = [
      Note(
        uid: 'user-123',
        title: 'Plano da semana',
        content: 'Estudar Flutter',
        category: 'Estudos',
        date: '03/11/2026 10:00',
        updatedAt: 100,
      ),
      Note(
        uid: 'user-123',
        title: 'Lista de tarefas',
        content: 'Comprar café',
        category: 'Pessoal',
        date: '03/11/2026 11:00',
        updatedAt: 200,
      ),
    ];

    expect(
      searchNotes(notes, query: 'FLUTTER').single.title,
      'Plano da semana',
    );
    expect(searchNotes(notes, query: 'café').single.title, 'Lista de tarefas');
    expect(searchNotes(notes, query: 'semana', category: 'Pessoal'), isEmpty);
    expect(searchNotes(notes, category: 'Estudos').single.category, 'Estudos');
  });
}
