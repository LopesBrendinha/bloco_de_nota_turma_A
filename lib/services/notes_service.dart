import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../database/database_helper.dart';
import '../models/note.dart';

class NotesService {
  final _local = DatabaseHelper.instance;
  final _cloud = FirebaseFirestore.instance.collection('notes');

  Future<List<Note>> load(String uid) async {
    // O app abre primeiro o que já existe no aparelho.
    final localNotes = await _local.getNotes(uid);
    try {
      final snapshot = await _cloud.where('uid', isEqualTo: uid).get();
      for (final doc in snapshot.docs) {
        await _local.save(Note.fromCloud(doc.id, doc.data()));
      }
      return await _local.getNotes(uid);
    } catch (_) {
      // Sem internet, as notas locais continuam disponíveis.
      return localNotes;
    }
  }

  Future<void> save(Note note) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != note.uid) {
      throw Exception('Entre novamente para salvar suas notas.');
    }
    // Primeiro grava na nuvem. Se falhar, não informa sucesso ao usuário.
    final ref = note.cloudId.startsWith('local-') || note.cloudId.isEmpty
        ? _cloud.doc()
        : _cloud.doc(note.cloudId);
    await ref.set(note.toCloud());
    await _local.save(Note(
      id: note.id, cloudId: ref.id, uid: note.uid, title: note.title,
      content: note.content, category: note.category, date: note.date,
      pinned: note.pinned,
    ));
  }

  Future<void> delete(Note note) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != note.uid) {
      throw Exception('Entre novamente para excluir suas notas.');
    }
    await _cloud.doc(note.cloudId).delete();
    await _local.delete(note.cloudId, note.uid);
  }
}
