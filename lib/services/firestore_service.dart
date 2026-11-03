import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/note.dart';

// Acesso ao Cloud Firestore. Só o NoteRepository usa esta classe.
class FirestoreService {
  // Sem a persistência, uma chamada sem internet pode esperar o servidor para
  // sempre. O timeout vira TimeoutException, que a sincronização trata como
  // offline.
  static const _timeout = Duration(seconds: 10);

  CollectionReference<Map<String, dynamic>> _notes(String uid) => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('notes');

  Future<void> upsert(Note note) =>
      _notes(note.uid).doc(note.id).set(note.toFirestore()).timeout(_timeout);

  Future<void> delete(String uid, String id) =>
      _notes(uid).doc(id).delete().timeout(_timeout);

  Future<List<Note>> fetchAll(String uid) async {
    final snapshot = await _notes(uid).get().timeout(_timeout);

    return snapshot.docs
        .map((doc) => Note.fromFirestore({...doc.data(), 'id': doc.id}))
        .toList();
  }
}
