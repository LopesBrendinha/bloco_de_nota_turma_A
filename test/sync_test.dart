import 'dart:async';
import 'dart:io';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bloco_de_nota_turma_a/database/database_helper.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/models/category.dart';
import 'package:bloco_de_nota_turma_a/repositories/notes_repository.dart';
import 'package:bloco_de_nota_turma_a/services/cloud_store.dart';
import 'package:bloco_de_nota_turma_a/services/reminder_service.dart';

class FaultCloud implements CloudStore {
  final CloudStore inner;
  bool offline = false;
  Completer<void>? block;
  Completer<void>? entered;
  FaultCloud(this.inner);
  void check() {
    if (offline) throw const SocketException('offline');
  }

  @override
  Future<void> putNote(Note n) async {
    check();
    entered?.complete();
    entered = null;
    if (block != null) await block!.future;
    await inner.putNote(n);
  }

  @override
  Future<List<Note>> fetchNotes(String uid) async {
    check();
    return inner.fetchNotes(uid);
  }

  @override
  Future<void> putCategory(NoteCategory c) async {
    check();
    await inner.putCategory(c);
  }

  @override
  Future<List<NoteCategory>> fetchCategories(String uid) async {
    check();
    return inner.fetchCategories(uid);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late DatabaseHelper local;
  late NotesRepository repo;
  late FaultCloud cloud;
  late FakeFirebaseFirestore firestore;
  setUp(() {
    local = DatabaseHelper(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    firestore = FakeFirebaseFirestore();
    cloud = FaultCloud(FirestoreCloudStore(firestore, () => 'alice'));
    repo = NotesRepository(
      local: local,
      cloud: cloud,
      uid: 'alice',
      sessionValid: () => true,
    );
  });
  tearDown(() async {
    await repo.sync();
    repo.dispose();
    await local.close();
  });
  Note note({
    String title = 'Revisar Flutter',
    String content = 'Estudar SQLite',
  }) => Note(uid: 'alice', title: title, content: content);

  test(
    'offline CRUD stays local; reconnect uploads edits, categories and deletion',
    () async {
      cloud.offline = true;
      final n = note();
      await repo.save(n);
      await repo.sync();
      expect(repo.notes.single.title, n.title);
      expect(repo.pending, 1);
      expect(repo.syncError, isNotNull);
      await repo.addCategory('Faculdade');
      final edited = n.edit(
        content: 'Conteúdo atualizado',
        category: 'Faculdade',
        archived: true,
        reminderAt: DateTime.now().add(const Duration(days: 1)),
      );
      await repo.save(edited);
      await repo.sync();
      cloud.offline = false;
      await repo.sync();
      expect(repo.pending, 0);
      final stored =
          (await firestore.collection('users/alice/notes').doc(n.cloudId).get())
              .data()!;
      expect(stored['content'], 'Conteúdo atualizado');
      expect(stored['archived'], true);
      expect(stored['reminderAt'], edited.reminderAt!.millisecondsSinceEpoch);
      expect(
        (await firestore.collection('users/alice/categories').get())
            .docs
            .single['name'],
        'Faculdade',
      );
      cloud.offline = true;
      await repo.save(edited.edit(deleted: true));
      await repo.sync();
      expect(repo.notes, isEmpty);
      expect((await local.pendingNotes('alice')).single.deleted, true);
      cloud.offline = false;
      await repo.sync();
      expect(
        (await firestore
            .collection('users/alice/notes')
            .doc(n.cloudId)
            .get())['deleted'],
        true,
      );
      expect(repo.pending, 0);
    },
  );
  test(
    'a second installation recovers cloud notes and categories without duplicates',
    () async {
      await local.saveNote(note());
      await local.saveCategory(NoteCategory(uid: 'alice', name: 'Projeto'));
      await repo.sync();
      final second = DatabaseHelper(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      final other = NotesRepository(
        local: second,
        cloud: cloud,
        uid: 'alice',
        sessionValid: () => true,
      );
      try {
        expect(await second.getNotes('alice'), isEmpty);
        await other.sync();
        await other.sync();
        expect(other.notes, hasLength(1));
        expect(other.categories, contains('Projeto'));
        expect(other.notes.single.dirty, false);
      } finally {
        other.dispose();
        await second.close();
      }
    },
  );
  test(
    'an edit made during upload is not acknowledged or overwritten by download',
    () async {
      final n = note();
      await local.saveNote(n);
      cloud.block = Completer<void>();
      cloud.entered = Completer<void>();
      final entered = cloud.entered!.future;
      final sending = repo.sync();
      await entered;
      final edit = n.edit(title: 'Edição concorrente');
      await local.saveNote(edit);
      cloud.block!.complete();
      await sending;
      cloud.block = null;
      expect(
        (await local.pendingNotes('alice')).single.revision,
        edit.revision,
      );
      expect(repo.notes.single.title, 'Edição concorrente');
      await repo.sync();
      expect(repo.pending, 0);
      expect(
        (await firestore
            .collection('users/alice/notes')
            .doc(n.cloudId)
            .get())['title'],
        'Edição concorrente',
      );
    },
  );
  test('local queries and acknowledgements are isolated by owner', () async {
    final a = note();
    final b = Note(
      uid: 'bob',
      cloudId: a.cloudId,
      title: 'Privada',
      content: 'De Bob',
    );
    await local.saveNote(a);
    await local.saveNote(b);
    await repo.sync();
    expect(repo.notes.single.uid, 'alice');
    expect((await local.pendingNotes('bob')).single.title, 'Privada');
    expect((await firestore.collection('users/bob/notes').get()).docs, isEmpty);
    await expectLater(
      FirestoreCloudStore(firestore, () => 'bob').fetchNotes('alice'),
      throwsStateError,
    );
  });
  test('cloud tombstone defeats an old offline edit', () async {
    final n = note();
    await local.saveNote(n);
    await repo.sync();
    await FirestoreCloudStore(
      firestore,
      () => 'alice',
    ).putNote(n.edit(deleted: true));
    await local.saveNote(n.edit(title: 'Edição em dispositivo antigo'));
    await repo.sync();
    expect(repo.notes, isEmpty);
    expect(repo.pending, 0);
  });
  test(
    'search covers local title and content with category/archive filters',
    () async {
      cloud.offline = true;
      await local.saveNote(note(title: 'DART', content: 'Texto'));
      await local.saveNote(
        note(
          title: 'Outra',
          content: 'Aprender Dart',
        ).edit(category: 'Estudos', archived: true),
      );
      await repo.refresh();
      expect(repo.search(query: ' dart '), hasLength(1));
      expect(
        repo.search(query: 'DART', category: 'Estudos', archived: true),
        hasLength(1),
      );
      expect(repo.search(query: 'inexistente'), isEmpty);
    },
  );
  test(
    'reminders honor deadlines, archive status and persistent dismissal',
    () async {
      final n = note().edit(
        reminderAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      final service = ReminderService(local);
      expect(
        await service.due([n, n.edit(archived: true), n.edit(deleted: true)]),
        hasLength(1),
      );
      await service.dismiss(n);
      expect(await service.due([n]), isEmpty);
      expect(
        await service.due([
          n.edit(reminderAt: DateTime.now().add(const Duration(days: 1))),
        ]),
        isEmpty,
      );
    },
  );
  test('queue persists across reopening the SQLite file', () async {
    final directory = await Directory.systemTemp.createTemp('notes-sync-test-');
    final path = '${directory.path}/notes.db';
    final first = DatabaseHelper(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    await first.saveNote(note());
    await first.close();
    final reopened = DatabaseHelper(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    expect(
      (await reopened.pendingNotes('alice')).single.title,
      'Revisar Flutter',
    );
    await reopened.close();
    await databaseFactoryFfi.deleteDatabase(path);
    await directory.delete();
  });
  test(
    'migration preserves v1 notes and queues them with unique cloud IDs',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'notes-migration-test-',
      );
      final path = '${directory.path}/notes.db';
      final db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) => db.execute(
            'CREATE TABLE notes(id INTEGER PRIMARY KEY AUTOINCREMENT, uid TEXT NOT NULL, title TEXT NOT NULL, content TEXT NOT NULL, date TEXT NOT NULL)',
          ),
        ),
      );
      await db.insert('notes', {
        'uid': 'alice',
        'title': 'Legada',
        'content': 'Não perder',
        'date': '01/11/2026 10:00',
      });
      await db.close();
      final migrated = DatabaseHelper(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final notes = await migrated.getNotes('alice');
      expect(notes.single.content, 'Não perder');
      expect(notes.single.dirty, true);
      expect(notes.single.cloudId.length, 36);
      expect(notes.single.category, 'Pessoal');
      await migrated.close();
      await databaseFactoryFfi.deleteDatabase(path);
      await directory.delete();
    },
  );
}
