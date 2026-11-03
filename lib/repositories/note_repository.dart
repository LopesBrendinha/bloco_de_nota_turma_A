import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/note.dart';
import '../services/firestore_service.dart';
import 'note_filter.dart';
import 'sync_decision.dart';

enum SyncResult { ok, offline, error }

const _idChars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
final _random = Random.secure();

// Mesmo formato dos IDs automáticos do Firestore: 20 caracteres [A-Za-z0-9].
@visibleForTesting
String newNoteId() => String.fromCharCodes(
  List.generate(
    20,
    (_) => _idChars.codeUnitAt(_random.nextInt(_idChars.length)),
  ),
);

String? _cleanCategory(String? category) {
  final trimmed = category?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

class NoteRepository {
  final DatabaseHelper _database = DatabaseHelper.instance;
  final FirestoreService _firestore = FirestoreService();

  // Sincronização em andamento. É static porque cada tela cria o seu
  // NoteRepository, e só pode existir uma sincronização por vez no app.
  static Future<SyncResult>? _running;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  int get _now => DateTime.now().millisecondsSinceEpoch;

  Future<List<Note>> getNotes() => _database.getNotes(_uid);

  Future<List<String>> getCategories() async =>
      mergeCategories(await _database.getCategories(_uid));

  Future<void> create({
    required String title,
    required String content,
    String? category,
  }) async {
    final now = _now;
    await _database.insertNote(
      Note(
        id: newNoteId(),
        uid: _uid,
        title: title,
        content: content,
        category: _cleanCategory(category),
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
      ),
    );
    unawaited(sync());
  }

  Future<void> update(
    Note note, {
    required String title,
    required String content,
    String? category,
  }) async {
    final cleaned = _cleanCategory(category);
    await _database.updateNote(
      note.copyWith(
        title: title,
        content: content,
        category: cleaned,
        clearCategory: cleaned == null,
        updatedAt: _now,
        syncStatus: 'pending',
      ),
    );
    unawaited(sync());
  }

  // Exclusão reversível: a linha fica no banco com deleted_at preenchido.
  Future<void> delete(Note note) async {
    final now = _now;
    await _database.updateNote(
      note.copyWith(deletedAt: now, updatedAt: now, syncStatus: 'pending'),
    );
    unawaited(sync());
  }

  Future<List<Note>> getTrash() => _database.getTrash(_uid);

  Future<void> restore(Note note) async {
    await _database.updateNote(
      note.copyWith(
        clearDeletedAt: true,
        updatedAt: _now,
        syncStatus: 'pending',
      ),
    );
  }

  // Não apaga a linha: se o aparelho estiver offline, a próxima sincronização
  // baixaria a nota de novo do Firestore. A sincronização (2A) apaga na nuvem
  // e depois aqui.
  Future<void> deletePermanently(Note note) => _markPurge(note);

  Future<void> emptyTrash() async {
    for (final note in await getTrash()) {
      await _markPurge(note);
    }
  }

  Future<void> _markPurge(Note note) async {
    await _database.updateNote(
      note.copyWith(updatedAt: _now, syncStatus: 'pending_purge'),
    );
  }

  // Se já existe uma sincronização rodando, devolve a mesma, sem começar outra.
  Future<SyncResult> sync() =>
      _running ??= _sync().whenComplete(() => _running = null);

  Future<SyncResult> _sync() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return SyncResult.ok;
    final uid = user.uid;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.every((c) => c == ConnectivityResult.none)) {
        return SyncResult.offline;
      }

      // Busca antes de enviar: enviar às cegas uma edição offline mais velha
      // sobrescreveria uma edição mais nova feita em outro aparelho.
      final remote = {
        for (final note in await _firestore.fetchAll(uid)) note.id: note,
      };

      for (final note in await _database.getNotesBySyncStatus(uid, 'pending')) {
        // A nuvem tem uma versão mais nova: não sobrescreve, o merge baixa.
        if (decide(note, remote[note.id]) == SyncDecision.useRemote) continue;
        await _firestore.upsert(note);
        await _database.markSynced(note.id, note.updatedAt);
        // O mapa foi baixado antes do envio. Sem isto, o merge veria uma nota
        // synced ausente da nuvem e a apagaria.
        remote[note.id] = note;
      }
      for (final note in await _database.getNotesBySyncStatus(
        uid,
        'pending_purge',
      )) {
        await _firestore.delete(uid, note.id);
        await _database.deleteNotePermanently(note.id);
        remote.remove(note.id);
      }

      final local = {
        for (final note in await _database.getAllNotes(uid)) note.id: note,
      };
      for (final id in {...local.keys, ...remote.keys}) {
        switch (decide(local[id], remote[id])) {
          case SyncDecision.useRemote:
            await _database.upsertNote(remote[id]!);
          case SyncDecision.deleteLocal:
            await _database.deleteNotePermanently(id);
          case SyncDecision.keepLocal:
          case SyncDecision.nothing:
            break;
        }
      }

      return SyncResult.ok;
    } on TimeoutException {
      return SyncResult.offline;
    } on SocketException {
      return SyncResult.offline;
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        return SyncResult.offline;
      }
      debugPrint('Erro na sincronização: $e');
      return SyncResult.error;
    } catch (e) {
      debugPrint('Erro na sincronização: $e');
      return SyncResult.error;
    }
  }
}
