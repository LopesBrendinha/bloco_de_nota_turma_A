import 'dart:io';

import 'package:bloco_de_nota_turma_a/database/database_helper.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/services/note_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late Directory testDatabaseDirectory;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    testDatabaseDirectory = Directory(
      '.dart_tool/note_repository_test',
    ).absolute;
    await testDatabaseDirectory.create(recursive: true);
    await databaseFactory.setDatabasesPath(testDatabaseDirectory.path);
    database = await DatabaseHelper.instance.database;
  });

  tearDownAll(() async {
    await database.close();
    await testDatabaseDirectory.delete(recursive: true);
  });

  setUp(() async {
    await database.delete('notes');
    await database.delete('note_categories');
    await database.delete('pending_deletions');
  });

  test(
    'creates, restores, updates and deletes a note across both stores',
    () async {
      const uid = 'test-user';
      const date = '03/11/2026 18:00';
      final firestore = FakeFirebaseFirestore();
      final repository = NoteRepository(firestore: firestore);
      final sourceNote = Note(
        uid: uid,
        title: 'Revisar integração',
        content: 'SQLite e Firestore',
        category: 'Estudos',
        date: date,
        updatedAt: 100,
      );

      await repository.save(sourceNote);

      var localNotes = await repository.getLocalNotes(uid);
      expect(localNotes, hasLength(1));
      expect(localNotes.single.cloudId, isNotNull);
      expect(localNotes.single.category, 'Estudos');

      final notesCollection = firestore
          .collection('users')
          .doc(uid)
          .collection('notes');
      final cloudNote = await notesCollection
          .doc(localNotes.single.cloudId)
          .get();
      expect(cloudNote.data()?['title'], 'Revisar integração');
      expect(cloudNote.data()?['category'], 'Estudos');

      await database.delete('notes');
      await database.delete('note_categories');
      await repository.synchronize(uid);

      localNotes = await repository.getLocalNotes(uid);
      expect(localNotes, hasLength(1));
      expect(localNotes.single.title, 'Revisar integração');
      expect(await repository.getCategories(uid), contains('Estudos'));

      await notesCollection.doc(localNotes.single.cloudId).update({
        'title': 'Atualizada na nuvem',
        'updatedAt': localNotes.single.updatedAt + 100,
      });
      await repository.synchronize(uid);
      localNotes = await repository.getLocalNotes(uid);
      expect(localNotes.single.title, 'Atualizada na nuvem');

      final editedNote = Note(
        id: localNotes.single.id,
        uid: uid,
        title: 'Atualizada neste aparelho',
        content: localNotes.single.content,
        category: localNotes.single.category,
        date: date,
        cloudId: localNotes.single.cloudId,
        updatedAt: 300,
      );
      await repository.save(editedNote);
      final updatedCloudNote = await notesCollection
          .doc(editedNote.cloudId)
          .get();
      expect(updatedCloudNote.data()?['title'], 'Atualizada neste aparelho');

      await repository.delete(editedNote);
      expect(await repository.getLocalNotes(uid), isEmpty);
      expect(
        (await notesCollection.doc(editedNote.cloudId).get()).exists,
        isFalse,
      );
      expect(await database.query('pending_deletions'), isEmpty);
    },
  );
}
