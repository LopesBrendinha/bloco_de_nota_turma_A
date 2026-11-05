import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // cada usuário tem a sua própria coleção de notas: users/{uid}/notes
  CollectionReference<Map<String, dynamic>> notesCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('notes');
  }

  // gera o id do documento sem precisar de internet
  String newId(String uid) {
    return notesCollection(uid).doc().id;
  }

  Future<List<Note>> getNotes(String uid) async {
    // Source.server obriga a buscar no servidor.
    // Sem internet dá erro em vez de devolver dados antigos.
    final result = await notesCollection(uid).get(
      GetOptions(source: Source.server),
    );

    return result.docs
        .map((doc) => Note.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  Future<void> saveNote(Note note) async {
    await notesCollection(note.uid).doc(note.firebaseId).set(note.toFirestore());
  }

  Future<void> deleteNote(Note note) async {
    await notesCollection(note.uid).doc(note.firebaseId).delete();
  }
}
