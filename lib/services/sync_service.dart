
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bloco_de_nota_turma_a/database/database_helper.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _database = DatabaseHelper.instance;

  Future<void> uploadNote(Note note) async {
    final collection = _firestore
        .collection('users')
        .doc(note.uid)
        .collection('notes');

    final document = note.cloudId == null
        ? collection.doc()
        : collection.doc(note.cloudId);

    await document.set({
      'uid': note.uid,
      'title': note.title,
      'content': note.content,
      'date': note.date,
      'category': note.category,
      'isFavorite': note.isFavorite,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (note.id != null) {
      await _database.updateSyncInfo(
        note.id!,
        note.uid,
        document.id,
      );
    }
  }

  Future<void> uploadPendingNotes(String uid) async {
    final pendingNotes = await _database.getUnsyncedNotes(uid);

    for (final note in pendingNotes) {
      await uploadNote(note);
    }
  }

  Future<void> downloadNotes(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('notes')
        .get();

    for (final document in snapshot.docs) {
      final data = document.data();

      final note = Note(
        uid: uid,
        title: data['title'] as String? ?? '',
        content: data['content'] as String? ?? '',
        date: data['date'] as String? ?? '',
        category: data['category'] as String? ?? 'Geral',
        cloudId: document.id,
        isSynced: true,
        isFavorite: data['isFavorite'] as bool? ?? false,
      );

      await _database.upsertCloudNote(note);
    }
  }

  Future<void> deleteCloudNote(Note note) async {
    if (note.cloudId == null) return;

    await _firestore
        .collection('users')
        .doc(note.uid)
        .collection('notes')
        .doc(note.cloudId)
        .delete();
  }

  Future<void> synchronize(String uid) async {
    await uploadPendingNotes(uid);
    await downloadNotes(uid);
  }
}
