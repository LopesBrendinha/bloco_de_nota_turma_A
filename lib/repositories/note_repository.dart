import 'package:bloco_de_nota_turma_a/database/database_helper.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/services/firestore_service.dart';
import 'package:flutter/foundation.dart';

// As telas usam essa classe em vez de chamar o SQLite ou o Firestore direto.
// Tudo é salvo primeiro no SQLite (assim funciona sem internet) e depois
// o syncNotes envia as alterações para o Firebase.
class NoteRepository {
  final DatabaseHelper database = DatabaseHelper.instance;
  final FirestoreService firestoreService = FirestoreService();

  // se o Firebase não responder nesse tempo consideramos que está sem conexão
  final Duration timeout = Duration(seconds: 10);

  final List<String> defaultCategories = ["Estudos", "Trabalho", "Pessoal"];

  Future<List<Note>> getNotes(String uid, {String category = ""}) async {
    return await database.getNotes(uid, category: category);
  }

  Future<List<String>> getCategories(String uid) async {
    final categories = await database.getCategories(uid);

    // primeira vez do usuário nesse aparelho: cria as categorias padrão
    if (categories.isEmpty) {
      for (var name in defaultCategories) {
        await database.insertCategory(uid, name);
      }

      return await database.getCategories(uid);
    }

    return categories;
  }

  Future<void> addCategory(String uid, String name) async {
    await database.insertCategory(uid, name);
  }

  // Salva no SQLite marcando como pendente (synced = 0).
  // Quem manda para o Firebase é o syncNotes.
  Future<void> saveNote(Note note) async {
    final newNote = note.copyWith(
      // nota nova já ganha o id que ela vai ter no Firestore
      firebaseId: note.firebaseId ?? firestoreService.newId(note.uid),
      synced: 0,
    );

    if (newNote.id == null) {
      await database.insertNote(newNote);
    } else {
      await database.updateNote(newNote);
    }
  }

  // a nota some da tela na hora e é apagada do Firebase na sincronização
  Future<void> deleteNote(Note note) async {
    await database.markAsDeleted(note.id!);
  }

  // Sincronização entre o SQLite e o Firestore.
  // Retorna false se não conseguiu falar com o Firebase.
  //
  // 1. baixa as notas do Firebase e atualiza o SQLite
  //    (se a nota mudou nos dois lugares fica a que tem o updatedAt maior)
  // 2. apaga do SQLite as notas que foram excluídas em outro aparelho
  // 3. envia para o Firebase o que ficou pendente no SQLite
  Future<bool> syncNotes(String uid) async {
    try {
      // garante que as categorias padrão existem antes de baixar as notas
      await getCategories(uid);

      // 1
      final remoteNotes = await firestoreService.getNotes(uid).timeout(timeout);
      final remoteIds = <String>[];

      for (var remote in remoteNotes) {
        remoteIds.add(remote.firebaseId!);

        final local = await database.getNoteByFirebaseId(uid, remote.firebaseId!);

        if (local == null) {
          // nota criada em outro aparelho ou numa instalação anterior
          await database.insertNote(remote);
        } else if (local.deleted == 0 && remote.updatedAt > local.updatedAt) {
          // a versão do Firebase é mais nova
          await database.updateNote(remote.copyWith(id: local.id));
        }

        // a categoria vem junto com a nota, então recriamos ela
        // aqui caso o usuário esteja em outro aparelho
        await database.insertCategory(uid, remote.category);
      }

      // 2
      final localNotes = await database.getAllNotes(uid);

      for (var local in localNotes) {
        if (local.synced == 1 && !remoteIds.contains(local.firebaseId)) {
          await database.deleteNote(local.id!);
        }
      }

      // 3
      final pending = await database.getPendingNotes(uid);

      for (var note in pending) {
        if (note.deleted == 1) {
          await firestoreService.deleteNote(note).timeout(timeout);
          await database.deleteNote(note.id!);
        } else {
          await firestoreService.saveNote(note).timeout(timeout);
          await database.markAsSynced(note.firebaseId!, note.updatedAt);
        }
      }

      return true;
    } catch (e) {
      // sem internet, Firebase fora do ar, regra bloqueando etc.
      // as alterações continuam no SQLite com synced = 0
      debugPrint("Erro ao sincronizar: $e");
      return false;
    }
  }
}
