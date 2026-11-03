import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Acesso direto ao Cloud Firestore (fonte de dados remota).
///
/// Estrutura no banco: users/{uid}/notes/{noteId}
/// Cada usuário só enxerga a própria coleção (ver firestore.rules).
class FirestoreService {
  /// Sem internet, as operações do Firestore podem ficar esperando
  /// indefinidamente. O timeout garante que o app responda com um erro.
  static const Duration timeout = Duration(seconds: 8);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _notes(String uid) {
    return _firestore.collection('users').doc(uid).collection('notes');
  }

  /// Cria ou atualiza o documento da nota.
  Future<void> upsertNote(Note note) {
    return _notes(note.uid).doc(note.id).set(note.toRemoteMap()).timeout(timeout);
  }

  /// Apaga definitivamente o documento da nota.
  Future<void> deleteNote(String uid, String id) {
    return _notes(uid).doc(id).delete().timeout(timeout);
  }

  /// Busca todas as notas do usuário no servidor.
  Future<List<Note>> fetchNotes(String uid) async {
    final snapshot = await _notes(
      uid,
    ).get(const GetOptions(source: Source.server)).timeout(timeout);

    return snapshot.docs
        .map((doc) => Note.fromRemote(doc.id, uid, doc.data()))
        .toList();
  }
}
