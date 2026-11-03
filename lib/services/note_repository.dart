import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/database_helper.dart';
import '../models/note.dart';

/// Keeps SQLite as the local source of truth and synchronizes changes to Firestore.
class NoteRepository {
  NoteRepository({DatabaseHelper? database, FirebaseFirestore? firestore})
    : _database = database ?? DatabaseHelper.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final DatabaseHelper _database;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _userNotes(String uid) =>
      _firestore.collection('users').doc(uid).collection('notes');

  CollectionReference<Map<String, dynamic>> _userCategories(String uid) =>
      _firestore.collection('users').doc(uid).collection('categories');

  String _categoryDocumentId(String name) =>
      Uri.encodeComponent(name.trim().toLowerCase());

  Future<List<Note>> getLocalNotes(String uid) => _database.getNotes(uid);

  Future<List<String>> getCategories(String uid) =>
      _database.getCategories(uid);

  Future<void> refreshCategories(String uid) => _synchronizeCategories(uid);

  Future<void> createCategory(String uid, String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return;
    await _database.saveCategory(uid, normalizedName);
    try {
      await _userCategories(uid).doc(_categoryDocumentId(normalizedName)).set({
        'uid': uid,
        'name': normalizedName,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {
      // Local categories are kept and retried during the next synchronization.
    }
  }

  Future<void> save(Note note) async {
    await createCategory(note.uid, note.category);
    final cloudId = note.cloudId ?? _userNotes(note.uid).doc().id;
    final saved = Note(
      id: note.id,
      uid: note.uid,
      title: note.title,
      content: note.content,
      category: note.category,
      date: note.date,
      cloudId: cloudId,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    if (saved.id == null) {
      final id = await _database.insertNote(saved);
      await _database.updateNote(
        Note(
          id: id,
          uid: saved.uid,
          title: saved.title,
          content: saved.content,
          date: saved.date,
          cloudId: cloudId,
          updatedAt: saved.updatedAt,
        ),
      );
    } else {
      await _database.updateNote(saved);
    }

    try {
      await _writeCloud(saved);
    } catch (_) {
      // The local copy keeps its cloud ID so the next sync can retry safely.
    }
  }

  Future<void> delete(Note note) async {
    if (note.cloudId != null) {
      await _database.queueDeletion(note.uid, note.cloudId!);
    }
    if (note.id != null) {
      await _database.deleteNoteForUser(note.id!, note.uid);
    }
    if (note.cloudId != null) {
      try {
        await _userNotes(note.uid).doc(note.cloudId!).delete();
        await _database.clearPendingDeletion(note.uid, note.cloudId!);
      } catch (_) {
        // The deletion stays queued locally and is retried during synchronization.
      }
    }
  }

  Future<void> synchronize(String uid) async {
    final pendingDeletions = await _database.getPendingDeletions(uid);
    for (final cloudId in pendingDeletions) {
      await _userNotes(uid).doc(cloudId).delete();
      await _database.clearPendingDeletion(uid, cloudId);
    }
    final localNotes = await _database.getNotes(uid);
    for (final category in localNotes.map((note) => note.category).toSet()) {
      await _database.saveCategory(uid, category);
    }
    await _synchronizeCategories(uid);
    final remoteSnapshot = await _userNotes(uid).get();
    final remoteById = {for (final doc in remoteSnapshot.docs) doc.id: doc};
    final localByCloudId = {
      for (final note in localNotes)
        if (note.cloudId != null) note.cloudId!: note,
    };

    for (final doc in remoteSnapshot.docs) {
      final data = doc.data();
      final remoteNote = Note(
        uid: uid,
        title: data['title'] as String? ?? '',
        content: data['content'] as String? ?? '',
        category: data['category'] as String? ?? 'Geral',
        date: data['date'] as String? ?? '',
        cloudId: doc.id,
        updatedAt: data['updatedAt'] as int? ?? 0,
      );
      final localNote = localByCloudId[doc.id];
      if (localNote == null || remoteNote.updatedAt > localNote.updatedAt) {
        await _database.upsertNote(remoteNote);
        await _database.saveCategory(uid, remoteNote.category);
      } else {
        await _writeCloud(localNote);
      }
    }

    for (final note in localNotes) {
      if (note.cloudId == null) {
        final cloudId = _userNotes(uid).doc().id;
        final identified = Note(
          id: note.id,
          uid: uid,
          title: note.title,
          content: note.content,
          date: note.date,
          cloudId: cloudId,
          updatedAt: note.updatedAt,
        );
        await _database.updateNote(identified);
        await _writeCloud(identified);
      } else if (!remoteById.containsKey(note.cloudId)) {
        await _writeCloud(note);
      }
    }
  }

  Future<void> _writeCloud(Note note) =>
      _userNotes(note.uid).doc(note.cloudId!).set({
        'uid': note.uid,
        'title': note.title,
        'content': note.content,
        'category': note.category,
        'date': note.date,
        'updatedAt': note.updatedAt,
      });

  Future<void> _synchronizeCategories(String uid) async {
    final remote = await _userCategories(uid).get();
    final remoteNames = <String>{};
    for (final document in remote.docs) {
      final name = document.data()['name'] as String?;
      if (name == null || name.trim().isEmpty) continue;
      remoteNames.add(name.toLowerCase());
      await _database.saveCategory(uid, name);
    }

    final localNames = await _database.getCategories(uid);
    for (final name in localNames) {
      if (remoteNames.contains(name.toLowerCase())) continue;
      await _userCategories(uid).doc(_categoryDocumentId(name)).set({
        'uid': uid,
        'name': name,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }
}
