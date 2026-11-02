import 'dart:async';

import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/repositories/notes_repository.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_test/flutter_test.dart';

Note _sampleNote() {
  return Note(
    id: 'abc123',
    uid: 'user-1',
    title: 'Prova de Cálculo',
    content: 'Estudar derivadas e integrais',
    category: 'Estudos',
    createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(2000),
    isDeleted: true,
    deletedAt: DateTime.fromMillisecondsSinceEpoch(3000),
    isSynced: true,
  );
}

void main() {
  group('Note', () {
    test('generateId cria IDs únicos', () {
      final ids = List.generate(200, (_) => Note.generateId());

      expect(ids.toSet().length, ids.length);
    });

    test('toMap e fromMap preservam todos os dados (SQLite)', () {
      final original = _sampleNote();
      final copy = Note.fromMap(original.toMap());

      expect(copy.id, original.id);
      expect(copy.uid, original.uid);
      expect(copy.title, original.title);
      expect(copy.content, original.content);
      expect(copy.category, original.category);
      expect(copy.createdAt, original.createdAt);
      expect(copy.updatedAt, original.updatedAt);
      expect(copy.isDeleted, isTrue);
      expect(copy.deletedAt, original.deletedAt);
      expect(copy.isSynced, isTrue);
      expect(copy.isPurged, isFalse);
    });

    test('toFirestoreMap não envia flags locais e fromFirestore reconstrói', () {
      final original = _sampleNote();
      final map = original.toFirestoreMap();

      expect(map.containsKey('synced'), isFalse);
      expect(map.containsKey('purged'), isFalse);
      expect(map['uid'], 'user-1');
      expect(map['deleted'], isTrue);

      final restored = Note.fromFirestore('abc123', 'user-1', map);

      expect(restored.title, original.title);
      expect(restored.category, 'Estudos');
      expect(restored.updatedAt, original.updatedAt);
      expect(restored.isDeleted, isTrue);
      expect(restored.deletedAt, original.deletedAt);
      expect(restored.isSynced, isTrue);
    });

    test('fromFirestore usa valores padrão para campos ausentes', () {
      final note = Note.fromFirestore('id', 'uid', {});

      expect(note.title, '');
      expect(note.content, '');
      expect(note.category, Note.fallbackCategory);
      expect(note.isDeleted, isFalse);
    });

    test('copyWith pode limpar a data de exclusão (restaurar da lixeira)', () {
      final restored = _sampleNote().copyWith(
        isDeleted: false,
        clearDeletedAt: true,
      );

      expect(restored.isDeleted, isFalse);
      expect(restored.deletedAt, isNull);
    });

    test('formatDateTime usa o formato dd/MM/yyyy HH:mm', () {
      expect(
        Note.formatDateTime(DateTime(2026, 11, 2, 9, 5)),
        '02/11/2026 09:05',
      );
    });
  });

  group('describeSyncError', () {
    test('timeout vira mensagem de falta de conexão', () {
      expect(
        describeSyncError(TimeoutException('x')),
        'Sem conexão com o Firebase.',
      );
    });

    test('permission-denied vira mensagem de permissão', () {
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );

      expect(describeSyncError(error), contains('permissão'));
    });

    test('erro desconhecido vira mensagem genérica', () {
      expect(
        describeSyncError(Exception('qualquer')),
        'Não foi possível sincronizar com o Firebase.',
      );
    });
  });
}
