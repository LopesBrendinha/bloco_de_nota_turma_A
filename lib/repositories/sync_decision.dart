import '../models/note.dart';

enum SyncDecision { useRemote, keepLocal, deleteLocal, nothing }

// Função pura: decide o que fazer com uma nota que existe no aparelho (local),
// na nuvem (remote) ou nos dois. Regra: o updated_at mais novo vence.
SyncDecision decide(Note? local, Note? remote) {
  if (local == null) {
    return remote == null ? SyncDecision.nothing : SyncDecision.useRemote;
  }

  if (remote == null) {
    // synced e sumiu da nuvem: foi excluída de vez em outro aparelho.
    // pending ou pending_purge: ainda não foi enviada.
    return local.syncStatus == 'synced'
        ? SyncDecision.deleteLocal
        : SyncDecision.keepLocal;
  }

  return remote.updatedAt > local.updatedAt
      ? SyncDecision.useRemote
      : SyncDecision.keepLocal;
}
