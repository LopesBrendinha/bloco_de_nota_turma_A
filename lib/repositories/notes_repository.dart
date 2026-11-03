import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import '../database/database_helper.dart';
import '../models/category.dart';
import '../models/note.dart';
import '../services/cloud_store.dart';

/// SQLite dirty rows form a durable outbox. All UI reads are local.
class NotesRepository extends ChangeNotifier {
  final DatabaseHelper local;
  final CloudStore cloud;
  final String uid;
  final bool Function() sessionValid;
  List<Note> notes = [];
  List<String> categories = ['Estudos', 'Trabalho', 'Pessoal'];
  bool syncing = false;
  String? syncError, localError;
  DateTime? lastSync;
  int pending = 0;
  bool _disposed = false;
  Timer? _retry;
  Future<void>? _running;
  NotesRepository({
    required this.local,
    required this.cloud,
    required this.uid,
    required this.sessionValid,
  });
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    await refresh();
    if (_disposed) return;
    _retry = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(sync()),
    );
    unawaited(sync());
  }

  Future<void> refresh() async {
    try {
      notes = await local.getNotes(uid);
      final custom = await local.getCategories(uid);
      categories = {
        'Estudos',
        'Trabalho',
        'Pessoal',
        ...custom.map((c) => c.name),
        ...notes.map((n) => n.category),
      }.toList()..sort();
      pending =
          (await local.pendingNotes(uid)).length +
          custom.where((c) => c.dirty).length;
      localError = null;
    } catch (_) {
      localError = 'Não foi possível abrir o banco local. Tente novamente.';
    }
    _notify();
  }

  Future<void> save(Note note) async {
    if (!sessionValid() || note.uid != uid) {
      throw StateError('Entre novamente na sua conta.');
    }
    await local.saveNote(note);
    await refresh();
    unawaited(sync());
  }

  Future<void> addCategory(String name) async {
    name = name.trim();
    if (!sessionValid()) throw StateError('Entre novamente na sua conta.');
    if (name.isEmpty || name.length > 60) {
      throw ArgumentError('Use um nome de 1 a 60 caracteres.');
    }
    if (categories.any((c) => c.toLowerCase() == name.toLowerCase())) return;
    await local.saveCategory(NoteCategory(uid: uid, name: name));
    await refresh();
    unawaited(sync());
  }

  List<Note> search({
    String query = '',
    String? category,
    bool archived = false,
  }) {
    final q = query.trim().toLowerCase();
    return notes
        .where(
          (n) =>
              n.archived == archived &&
              (category == null || n.category == category) &&
              (q.isEmpty ||
                  n.title.toLowerCase().contains(q) ||
                  n.content.toLowerCase().contains(q)),
        )
        .toList();
  }

  Future<void> sync() {
    if (_disposed || !sessionValid()) return Future.value();
    return _running ??= _sync().whenComplete(() {
      _running = null;
    });
  }

  Future<void> _sync() async {
    syncing = true;
    syncError = null;
    _notify();
    try {
      for (final c in (await local.getCategories(uid)).where((c) => c.dirty)) {
        if (!sessionValid() || _disposed) return;
        await cloud.putCategory(c);
        await local.acknowledge('categories', uid, c.id, c.revision);
      }
      for (final n in await local.pendingNotes(uid)) {
        if (!sessionValid() || _disposed) return;
        await cloud.putNote(n);
        await local.acknowledge('notes', uid, n.cloudId, n.revision);
      }
      if (!sessionValid() || _disposed) return;
      final categories = await cloud.fetchCategories(uid);
      final remote = await cloud.fetchNotes(uid);
      if (!sessionValid() || _disposed) return;
      for (final c in categories) {
        if (c.uid != uid) {
          throw StateError('Dados de outro usuário rejeitados.');
        }
        await local.mergeRemoteCategory(c);
      }
      for (final n in remote) {
        if (n.uid != uid) {
          throw StateError('Dados de outro usuário rejeitados.');
        }
        await local.mergeRemoteNote(n);
      }
      lastSync = DateTime.now();
    } catch (error) {
      syncError =
          error is FirebaseException && error.code == 'permission-denied'
          ? 'Acesso ao Firestore negado. Confira a conta e as regras do projeto.'
          : 'Nuvem indisponível. Suas notas locais estão preservadas; tentaremos novamente.';
    } finally {
      syncing = false;
      if (!_disposed) await refresh();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    super.dispose();
  }
}
