import 'dart:async';

import 'package:bloco_de_nota_turma_a/database/database_helper.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/services/firestore_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Resultado de uma tentativa de comunicação com o Firebase.
class SyncResult {
  final bool success;
  final String? message;

  const SyncResult._(this.success, this.message);

  const SyncResult.ok() : this._(true, null);

  const SyncResult.failure(String message) : this._(false, message);
}

/// Mensagem para erros do banco local (SQLite).
String describeLocalError(Object error) {
  debugPrint('Erro no banco local: $error');

  if (kIsWeb) {
    return 'O banco local (SQLite) não funciona no navegador. '
        'Execute o app em um emulador ou celular Android/iOS.';
  }

  return 'Erro no banco de dados local: $error';
}

/// Repositório de notas: único ponto que as telas usam.
///
/// Estratégia "local primeiro" (offline-first):
///  1. Toda alteração é gravada no SQLite (com synced = false) e a tela
///     é liberada na hora: o usuário nunca espera a rede.
///  2. A sincronização ([syncAll]) envia o que está pendente ao Firestore
///     e baixa o que existe na nuvem. Ela roda em segundo plano.
///  3. Se falhar (sem internet, regras, etc.), nada se perde: as notas
///     continuam no aparelho e são reenviadas na próxima sincronização.
class NoteRepository {
  NoteRepository._();

  static final NoteRepository instance = NoteRepository._();

  final DatabaseHelper _local = DatabaseHelper.instance;
  final FirestoreService _remote = FirestoreService();

  // ---------- Leitura (sempre do banco local) ----------

  Future<List<Note>> getNotes(
    String uid, {
    String query = '',
    String? category,
  }) {
    return _local.getNotes(uid, query: query, category: category);
  }

  Future<List<Note>> getTrash(String uid) {
    return _local.getNotes(uid, trash: true);
  }

  Future<List<String>> getCategories(String uid) {
    return _local.getCategories(uid);
  }

  // ---------- Escrita (só no SQLite; o envio é feito pelo syncAll) ----------

  /// Cria ou edita uma nota.
  Future<void> saveNote(Note note) async {
    await _local.saveNote(
      note.copyWith(
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        synced: false,
      ),
    );
  }

  /// Envia a nota para a lixeira (exclusão temporária).
  Future<void> moveToTrash(Note note) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _local.saveNote(
      note.copyWith(
        deleted: true,
        deletedAt: now,
        updatedAt: now,
        synced: false,
      ),
    );
  }

  /// Tira a nota da lixeira.
  Future<void> restore(Note note) async {
    await _local.saveNote(
      note.copyWith(
        deleted: false,
        clearDeletedAt: true,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        synced: false,
      ),
    );
  }

  /// Exclusão definitiva: apaga do aparelho agora e registra a exclusão
  /// como pendente; o syncAll apaga o documento no Firebase.
  Future<void> deleteForever(Note note) async {
    await _local.deleteNote(note.id);
    await _local.addPendingDelete(note.id, note.uid);
  }

  // ---------- Sincronização ----------

  /// Sincroniza o banco local com o Firestore, nesta ordem:
  ///  1. conclui exclusões definitivas pendentes;
  ///  2. envia as notas com alterações locais (synced = false);
  ///  3. baixa as notas da nuvem; em caso de conflito vence a alteração
  ///     mais recente (updatedAt);
  ///  4. remove do aparelho notas que foram excluídas em outro aparelho.
  ///
  /// Nunca lança exceção: devolve um [SyncResult] com a mensagem de erro.
  Future<SyncResult> syncAll(String uid) => _serialized(() => _syncAll(uid));

  Future<SyncResult> _syncAll(String uid) async {
    try {
      for (final id in await _local.getPendingDeletes(uid)) {
        await _remote.deleteNote(uid, id);
        await _local.removePendingDelete(id, uid);
      }

      for (final note in await _local.getUnsyncedNotes(uid)) {
        await _remote.upsertNote(note);
        await _local.markSynced(note.id, note.updatedAt);
      }

      final remoteNotes = await _remote.fetchNotes(uid);
      final remoteIds = <String>{};

      for (final remote in remoteNotes) {
        remoteIds.add(remote.id);

        // Nota que o usuário acabou de excluir definitivamente: não recriar.
        if (await _local.isPendingDelete(remote.id, uid)) continue;

        final local = await _local.getNoteById(remote.id, uid);

        if (local == null || remote.updatedAt > local.updatedAt) {
          await _local.saveNote(remote.copyWith(synced: true));
        }
      }

      for (final id in await _local.getSyncedIds(uid)) {
        if (!remoteIds.contains(id)) {
          await _local.deleteNote(id);
        }
      }

      return const SyncResult.ok();
    } catch (e) {
      return SyncResult.failure(_describe(e));
    }
  }

  // ---------- Internos ----------

  /// Fila simples: as sincronizações rodam uma de cada vez, para que duas
  /// execuções não se misturem (o que poderia apagar ou recriar notas).
  Future<void> _queue = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();

    _queue = _queue.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, stack) {
        completer.completeError(e, stack);
      }
    });

    return completer.future;
  }

  /// Transforma o erro técnico em uma mensagem que o usuário entende.
  String _describe(Object error) {
    debugPrint('Erro de sincronização: $error');

    const saved =
        'As alterações ficaram salvas no aparelho e serão enviadas na '
        'próxima sincronização.';

    if (error is TimeoutException) {
      return 'Sem conexão com o Firebase (tempo esgotado). $saved';
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'unavailable':
          return 'Sem conexão com o Firebase. $saved';
        case 'permission-denied':
          return 'O Firebase recusou a operação (permission-denied). '
              'Confira se o Firestore foi criado e se as regras foram '
              'publicadas. $saved';
        case 'not-found':
          return 'Banco do Firestore não encontrado. Crie o Firestore '
              'Database no console do Firebase. $saved';
        case 'unauthenticated':
          return 'Sessão expirada. Saia e entre novamente. $saved';
        default:
          return 'Erro do Firebase (${error.code}). $saved';
      }
    }

    return 'Erro inesperado ao sincronizar: $error. $saved';
  }
}
