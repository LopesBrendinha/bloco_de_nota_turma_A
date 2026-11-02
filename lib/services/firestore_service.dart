import 'dart:async';

import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Comunicação com o Cloud Firestore.
///
/// Estrutura dos dados:
///
///     users/{uid}/notes/{noteId}
///
/// Cada usuário só possui documentos dentro do próprio `users/{uid}`, o que
/// permite escrever regras de segurança simples (veja `firestore.rules`).
///
/// Toda chamada tem um [timeout]: sem conexão, o Firestore não devolve erro,
/// ele apenas deixa a operação pendente. O timeout transforma essa espera
/// em um erro que o repositório consegue tratar.
class FirestoreService {
  FirestoreService({
    FirebaseFirestore? firestore,
    this.timeout = const Duration(seconds: 6),
  }) : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  final Duration timeout;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _notesOf(String uid) {
    return _db.collection('users').doc(uid).collection('notes');
  }

  /// Cria ou substitui o documento da nota (operação idempotente).
  Future<void> saveNote(Note note) async {
    await _notesOf(note.uid)
        .doc(note.id)
        .set(note.toFirestoreMap())
        .timeout(timeout);
  }

  Future<void> deleteNote({required String uid, required String id}) async {
    await _notesOf(uid).doc(id).delete().timeout(timeout);
  }

  /// Busca todas as notas do usuário diretamente no servidor
  /// (`Source.server`), para que a falta de conexão gere erro em vez de
  /// devolver dados antigos de cache.
  Future<List<Note>> fetchNotes(String uid) async {
    final snapshot = await _notesOf(uid)
        .get(const GetOptions(source: Source.server))
        .timeout(timeout);

    return snapshot.docs
        .map((doc) => Note.fromFirestore(doc.id, uid, doc.data()))
        .toList();
  }
}
