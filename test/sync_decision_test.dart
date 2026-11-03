import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/repositories/sync_decision.dart';
import 'package:flutter_test/flutter_test.dart';

Note note({required int updatedAt, String syncStatus = 'synced'}) => Note(
  id: 'abc123',
  uid: 'user-1',
  title: 'Título',
  content: 'Conteúdo',
  createdAt: 1000,
  updatedAt: updatedAt,
  syncStatus: syncStatus,
);

void main() {
  test('só na nuvem: usa a remota', () {
    expect(decide(null, note(updatedAt: 2000)), SyncDecision.useRemote);
  });

  test('nos dois lados, remota mais nova: usa a remota', () {
    expect(
      decide(note(updatedAt: 2000), note(updatedAt: 3000)),
      SyncDecision.useRemote,
    );
  });

  test('nos dois lados, local mais nova: mantém a local', () {
    expect(
      decide(note(updatedAt: 3000, syncStatus: 'pending'), note(updatedAt: 2000)),
      SyncDecision.keepLocal,
    );
  });

  test('nos dois lados, mesmo updated_at: mantém a local', () {
    expect(
      decide(note(updatedAt: 2000), note(updatedAt: 2000)),
      SyncDecision.keepLocal,
    );
  });

  test('local synced e sumiu da nuvem: apaga a local', () {
    expect(decide(note(updatedAt: 2000), null), SyncDecision.deleteLocal);
  });

  test('local pending e não está na nuvem: mantém a local', () {
    expect(
      decide(note(updatedAt: 2000, syncStatus: 'pending'), null),
      SyncDecision.keepLocal,
    );
  });

  test('local pending_purge e não está na nuvem: mantém a local', () {
    expect(
      decide(note(updatedAt: 2000, syncStatus: 'pending_purge'), null),
      SyncDecision.keepLocal,
    );
  });

  test('em nenhum dos dois: nada', () {
    expect(decide(null, null), SyncDecision.nothing);
  });
}
