import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final note = Note(
    id: 1,
    firebaseId: 'abc123',
    uid: 'usuario1',
    title: 'Prova',
    content: 'Estudar para a prova de mobile',
    category: 'Estudos',
    date: '05/11/2026 10:30',
    createdAt: 1000,
    updatedAt: 2000,
    synced: 1,
    trashed: 1,
  );

  test('toMap e fromMap devolvem a mesma nota', () {
    final copy = Note.fromMap(note.toMap());

    expect(copy.id, 1);
    expect(copy.firebaseId, 'abc123');
    expect(copy.title, 'Prova');
    expect(copy.category, 'Estudos');
    expect(copy.createdAt, 1000);
    expect(copy.updatedAt, 2000);
    expect(copy.trashed, 1);
  });

  test('toFirestore não manda os campos que só existem no SQLite', () {
    final map = note.toFirestore();

    expect(map.containsKey('id'), false);
    expect(map.containsKey('synced'), false);
    expect(map.containsKey('deleted'), false);
    expect(map['uid'], 'usuario1');
    expect(map['trashed'], true);
  });

  test('nota vinda do Firestore já fica como sincronizada', () {
    final remote = Note.fromFirestore('abc123', note.toFirestore());

    expect(remote.id, null);
    expect(remote.firebaseId, 'abc123');
    expect(remote.synced, 1);
    expect(remote.trashed, 1);
    expect(remote.content, note.content);
  });

  test('copyWith muda só o que foi passado', () {
    final changed = note.copyWith(trashed: 0, synced: 0);

    expect(changed.trashed, 0);
    expect(changed.synced, 0);
    expect(changed.title, note.title);
    expect(changed.firebaseId, note.firebaseId);
    expect(changed.updatedAt, note.updatedAt);
  });
}
