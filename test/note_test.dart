import 'package:bloco_de_nota_turma_a/models/note.dart';
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
}
