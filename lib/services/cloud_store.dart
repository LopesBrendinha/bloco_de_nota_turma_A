import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note.dart';
import '../models/category.dart';

abstract class CloudStore {
  Future<void> putNote(Note note);
  Future<List<Note>> fetchNotes(String uid);
  Future<void> putCategory(NoteCategory category);
  Future<List<NoteCategory>> fetchCategories(String uid);
}

class FirestoreCloudStore implements CloudStore {
  final FirebaseFirestore firestore;
  final String? Function() currentUid;
  FirestoreCloudStore(this.firestore, this.currentUid);
  CollectionReference<Map<String, dynamic>> _collection(
    String uid,
    String name,
  ) {
    if (currentUid() != uid) throw StateError('A sessão foi alterada.');
    return firestore.collection('users').doc(uid).collection(name);
  }

  @override
  Future<void> putNote(Note n) async {
    final ref = _collection(n.uid, 'notes').doc(n.cloudId);
    await firestore
        .runTransaction((tx) async {
          final current = await tx.get(ref);
          if (current.exists &&
              current.data()?['deleted'] == true &&
              !n.deleted) {
            return;
          }
          if (currentUid() != n.uid) throw StateError('A sessão foi alterada.');
          tx.set(ref, {
            ...n.toCloud(),
            'syncedAt': FieldValue.serverTimestamp(),
          });
        })
        .timeout(const Duration(seconds: 12));
  }

  @override
  Future<List<Note>> fetchNotes(String uid) async {
    final snapshot = await _collection(uid, 'notes')
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 12));
    return snapshot.docs.map((d) => Note.fromCloud(d.id, d.data())).toList();
  }

  @override
  Future<void> putCategory(NoteCategory c) => _collection(c.uid, 'categories')
      .doc(c.id)
      .set({...c.toCloud(), 'syncedAt': FieldValue.serverTimestamp()})
      .timeout(const Duration(seconds: 12));
  @override
  Future<List<NoteCategory>> fetchCategories(String uid) async {
    final snapshot = await _collection(uid, 'categories')
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 12));
    return snapshot.docs
        .map(
          (d) => NoteCategory(
            id: d.id,
            uid: d.data()['uid'] as String,
            name: d.data()['name'] as String,
            revision: d.data()['revision'] as String,
            dirty: false,
          ),
        )
        .toList();
  }
}
