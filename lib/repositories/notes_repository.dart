import 'dart:async';

import 'package:bloco_de_nota_turma_a/database/database_helper.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/services/firestore_service.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;

/// Resultado de uma operação que envolve o Firebase.
///
/// Uma falha aqui NÃO significa perda de dados: a alteração já foi gravada no
/// SQLite e fica marcada como pendente até a próxima sincronização.
class SyncResult {
  final bool success;
  final String? message;

  const SyncResult.ok() : success = true, message = null;

  const SyncResult.failed(this.message) : success = false;
}

/// Traduz exceções do Firebase em mensagens claras para o usuário.
String describeSyncError(Object error) {
  if (error is TimeoutException) {
    return 'Sem conexão com o Firebase.';
  }

  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Sem permissão para acessar estas notas no Firebase.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Sem conexão com o Firebase.';
      case 'unauthenticated':
        return 'Sessão expirada. Entre novamente no aplicativo.';
    }
  }

  return 'Não foi possível sincronizar com o Firebase.';
}

/// Camada que une o banco local (SQLite) e a nuvem (Firestore).
///
/// Estratégia "offline-first":
///  1. Toda escrita vai primeiro para o SQLite, marcada como `synced = 0`.
///  2. Em seguida o repositório tenta enviar ao Firestore. Se der certo, marca
///     `synced = 1`; se falhar, a nota continua pendente.
///  3. [syncAll] reenvia as pendências e baixa o que existe na nuvem
///     (outro aparelho, nova instalação), resolvendo conflitos pela data de
///     atualização (a alteração mais recente vence).
///  4. A interface lê somente do SQLite, então funciona sem internet.
class NotesRepository {
  NotesRepository({DatabaseHelper? local, FirestoreService? remote})
    : _local = local ?? DatabaseHelper.instance,
      _remote = remote ?? FirestoreService();

  final DatabaseHelper _local;
  final FirestoreService _remote;

  static bool _syncing = false;

  /// Depois de uma falha de conexão, evita novas tentativas por um tempo para
  /// não deixar cada gravação esperando o timeout. A sincronização manual
  /// ignora essa pausa.
  static DateTime? _skipRemoteUntil;
  static const Duration _retryPause = Duration(seconds: 30);

  // ---------------------------------------------------------------- leitura

  Future<List<Note>> getNotes({
    required String uid,
    String search = '',
    String? category,
    NoteSort sort = NoteSort.updatedAt,
  }) {
    return _local.queryNotes(
      uid: uid,
      search: search,
      category: category,
      sort: sort,
    );
  }

  Future<List<Note>> getTrash(String uid) {
    return _local.queryNotes(uid: uid, trash: true);
  }

  Future<List<String>> getCategories(String uid) {
    return _local.getCategories(uid);
  }

  // --------------------------------------------------------------- escrita

  /// Cria ou atualiza uma nota (SQLite primeiro, depois Firebase).
  Future<SyncResult> saveNote(Note note) {
    return _writeAndPush(note.copyWith(updatedAt: DateTime.now()));
  }

  /// Envia a nota para a lixeira (exclusão temporária).
  Future<SyncResult> moveToTrash(Note note) {
    final now = DateTime.now();

    return _writeAndPush(
      note.copyWith(isDeleted: true, deletedAt: now, updatedAt: now),
    );
  }

  /// Recupera uma nota da lixeira.
  Future<SyncResult> restoreNote(Note note) {
    return _writeAndPush(
      note.copyWith(
        isDeleted: false,
        clearDeletedAt: true,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Exclusão definitiva: remove do Firebase e do aparelho.
  ///
  /// Sem conexão, a nota some da lista mas fica guardada como `purged` até
  /// que a sincronização consiga apagá-la da nuvem.
  Future<SyncResult> deletePermanently(Note note) async {
    try {
      await _remoteCall(
        () => _remote.deleteNote(uid: note.uid, id: note.id),
      );
      await _local.deleteById(note.id);

      return const SyncResult.ok();
    } catch (error) {
      await _local.upsertNote(note.copyWith(isPurged: true, isSynced: false));

      return SyncResult.failed(describeSyncError(error));
    }
  }

  /// Exclui definitivamente todas as notas da lixeira.
  Future<SyncResult> emptyTrash(String uid) async {
    final trash = await getTrash(uid);

    SyncResult? firstFailure;

    for (final note in trash) {
      final result = await deletePermanently(note);

      if (!result.success) {
        firstFailure ??= result;
      }
    }

    return firstFailure ?? const SyncResult.ok();
  }

  // ---------------------------------------------------------- sincronização

  /// Sincronização completa:
  ///  1. envia para o Firebase tudo que está pendente;
  ///  2. baixa as notas da nuvem e aplica as mais recentes;
  ///  3. remove do aparelho notas excluídas definitivamente em outro aparelho.
  Future<SyncResult> syncAll(String uid) async {
    if (_syncing) return const SyncResult.ok();

    _syncing = true;
    _skipRemoteUntil = null; // tentativa manual/explícita: ignora a pausa.

    try {
      // 1) Envia as pendências.
      final pending = await _local.getPendingNotes(uid);

      for (final note in pending) {
        if (note.isPurged) {
          await _remoteCall(
            () => _remote.deleteNote(uid: uid, id: note.id),
          );
          await _local.deleteById(note.id);
        } else {
          await _remoteCall(() => _remote.saveNote(note));
          await _local.markSynced(
            note.id,
            note.updatedAt.millisecondsSinceEpoch,
          );
        }
      }

      // A foto das notas "já sincronizadas" é tirada ANTES de baixar a nuvem:
      // uma nota enviada durante o download não será apagada por engano.
      final syncedBefore = await _local.getSyncedNotes(uid);

      // 2) Baixa a nuvem e aplica as versões mais recentes.
      final remoteNotes = await _remoteCall(() => _remote.fetchNotes(uid));
      final remoteIds = <String>{};

      for (final remote in remoteNotes) {
        remoteIds.add(remote.id);

        final local = await _local.getById(remote.id);

        if (local == null) {
          await _local.upsertNote(remote);
        } else if (local.isSynced &&
            remote.updatedAt.isAfter(local.updatedAt)) {
          // Local sem pendências e nuvem mais nova: a nuvem vence.
          await _local.upsertNote(remote);
        }
      }

      // 3) Notas que existiam na nuvem e sumiram foram excluídas em outro lugar.
      for (final local in syncedBefore) {
        if (!remoteIds.contains(local.id)) {
          await _local.deleteById(local.id);
        }
      }

      return const SyncResult.ok();
    } catch (error) {
      return SyncResult.failed(describeSyncError(error));
    } finally {
      _syncing = false;
    }
  }

  // ----------------------------------------------------------------- interno

  /// Grava no SQLite (pendente) e tenta enviar ao Firebase.
  Future<SyncResult> _writeAndPush(Note note) async {
    final pending = note.copyWith(isSynced: false);

    await _local.upsertNote(pending);

    try {
      await _remoteCall(() => _remote.saveNote(pending));
      await _local.markSynced(
        pending.id,
        pending.updatedAt.millisecondsSinceEpoch,
      );

      return const SyncResult.ok();
    } catch (error) {
      return SyncResult.failed(describeSyncError(error));
    }
  }

  /// Executa uma chamada ao Firebase respeitando a pausa após falhas de rede.
  Future<T> _remoteCall<T>(Future<T> Function() action) async {
    final until = _skipRemoteUntil;

    if (until != null && DateTime.now().isBefore(until)) {
      throw TimeoutException('Firebase indisponível, nova tentativa em breve.');
    }

    try {
      final result = await action();
      _skipRemoteUntil = null;

      return result;
    } on TimeoutException {
      _skipRemoteUntil = DateTime.now().add(_retryPause);
      rethrow;
    } on FirebaseException catch (error) {
      if (error.code == 'unavailable') {
        _skipRemoteUntil = DateTime.now().add(_retryPause);
      }
      rethrow;
    }
  }
}
