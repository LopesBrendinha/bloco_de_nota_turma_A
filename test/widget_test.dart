// Testes do modelo Note (não dependem do Firebase nem de dispositivo).
//
// Rode com: flutter test

import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Note.create gera uma nota nova, fora da lixeira e não sincronizada', () {
    final note = Note.create(
      uid: 'u1',
      title: 'Título',
      content: 'Conteúdo',
      category: 'Estudos',
    );

    expect(note.id, isNotEmpty);
    expect(note.uid, 'u1');
    expect(note.deleted, isFalse);
    expect(note.synced, isFalse);
    expect(note.createdAt, note.updatedAt);
  });

  test('toMap e fromMap preservam os dados (SQLite)', () {
    final original = Note.create(
      uid: 'u1',
      title: 'Título',
      content: 'Conteúdo',
      category: 'Trabalho',
    ).copyWith(synced: true);

    final copy = Note.fromMap(original.toMap());

    expect(copy.id, original.id);
    expect(copy.uid, original.uid);
    expect(copy.title, original.title);
    expect(copy.content, original.content);
    expect(copy.category, original.category);
    expect(copy.createdAt, original.createdAt);
    expect(copy.updatedAt, original.updatedAt);
    expect(copy.deleted, isFalse);
    expect(copy.synced, isTrue);
  });

  test('toRemoteMap não envia o uid e fromRemote marca como sincronizada', () {
    final original = Note.create(
      uid: 'u1',
      title: 'Título',
      content: 'Conteúdo',
      category: 'Pessoal',
    );

    final remoteMap = original.toRemoteMap();
    expect(remoteMap.containsKey('uid'), isFalse);
    expect(remoteMap['category'], 'Pessoal');

    final copy = Note.fromRemote(original.id, 'u1', remoteMap);
    expect(copy.id, original.id);
    expect(copy.uid, 'u1');
    expect(copy.title, 'Título');
    expect(copy.synced, isTrue);
  });

  test('copyWith manda para a lixeira e restaura', () {
    final note = Note.create(
      uid: 'u1',
      title: 'Título',
      content: 'Conteúdo',
      category: 'Pessoal',
    );

    final trashed = note.copyWith(deleted: true, deletedAt: 123);
    expect(trashed.deleted, isTrue);
    expect(trashed.deletedAt, 123);

    final restored = trashed.copyWith(deleted: false, clearDeletedAt: true);
    expect(restored.deleted, isFalse);
    expect(restored.deletedAt, isNull);
  });
}
