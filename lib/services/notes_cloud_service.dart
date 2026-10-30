import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/note.dart';

class NotesCloudService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _notesFor(String uid) {
    return _firestore.collection('users').doc(uid).collection('notes');
  }

  String createNoteId(String uid) => _notesFor(uid).doc().id;

  Future<List<Note>> getNotes(String uid) async {
    final snapshot = await _notesFor(
      uid,
    ).get().timeout(const Duration(seconds: 8));
    return snapshot.docs
        .map((document) => Note.fromCloudMap(document.id, document.data()))
        .toList();
  }

  Future<void> saveNote(Note note) async {
    final cloudId = note.cloudId;
    if (cloudId == null) {
      throw ArgumentError('A nota precisa de um identificador na nuvem.');
    }

    await _notesFor(
      note.uid,
    ).doc(cloudId).set(note.toCloudMap()).timeout(const Duration(seconds: 8));
  }

  Future<void> deleteNote(Note note) async {
    final cloudId = note.cloudId;
    if (cloudId == null) return;

    await _notesFor(
      note.uid,
    ).doc(cloudId).delete().timeout(const Duration(seconds: 8));
  }
}
