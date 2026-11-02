import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/repositories/notes_repository.dart';
import 'package:bloco_de_nota_turma_a/widgets/confirm_dialog.dart';
import 'package:bloco_de_nota_turma_a/widgets/note_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Lixeira: notas excluídas temporariamente.
/// Daqui é possível restaurar uma nota ou excluí-la de forma definitiva
/// (aparelho e Firebase).
class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final NotesRepository repository = NotesRepository();

  List<Note> notes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadNotes();
  }

  void showMessage(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> loadNotes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final result = await repository.getTrash(user.uid);

    if (!mounted) return;

    setState(() {
      notes = result;
      loading = false;
    });
  }

  Future<void> restore(Note note) async {
    final result = await repository.restoreNote(note);
    await loadNotes();

    showMessage(
      result.success
          ? 'Nota restaurada.'
          : 'Nota restaurada no aparelho. ${result.message} '
                'Ela será enviada depois.',
    );
  }

  Future<void> deleteForever(Note note) async {
    final confirmed = await confirmAction(
      context,
      title: 'Excluir definitivamente?',
      message:
          'Esta nota será removida do aparelho e do Firebase. '
          'Essa ação não pode ser desfeita.',
      confirmLabel: 'Excluir',
    );

    if (!confirmed) return;

    final result = await repository.deletePermanently(note);
    await loadNotes();

    showMessage(
      result.success
          ? 'Nota excluída definitivamente.'
          : 'Nota removida da lista. ${result.message} '
                'A exclusão na nuvem será concluída depois.',
    );
  }

  Future<void> emptyTrash() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await confirmAction(
      context,
      title: 'Esvaziar a lixeira?',
      message:
          'Todas as notas da lixeira serão removidas do aparelho e do '
          'Firebase. Essa ação não pode ser desfeita.',
      confirmLabel: 'Esvaziar',
    );

    if (!confirmed) return;

    final result = await repository.emptyTrash(user.uid);
    await loadNotes();

    showMessage(
      result.success
          ? 'Lixeira esvaziada.'
          : 'Lixeira esvaziada. ${result.message} '
                'A exclusão na nuvem será concluída depois.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lixeira',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Esvaziar lixeira',
            onPressed: notes.isEmpty ? null : emptyTrash,
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notes.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'A lixeira está vazia.',
                  style: TextStyle(color: Color(0xFF77717F)),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Notas na lixeira podem ser restauradas. A exclusão '
                    'definitiva também remove a nota do Firebase.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF77717F)),
                  ),
                ),
                for (final note in notes)
                  NoteCard(
                    note: note,
                    actions: [
                      IconButton(
                        tooltip: 'Restaurar',
                        onPressed: () => restore(note),
                        icon: const Icon(
                          Icons.restore_from_trash_rounded,
                          color: Color(0xFF6C4AB6),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Excluir definitivamente',
                        onPressed: () => deleteForever(note),
                        icon: const Icon(
                          Icons.delete_forever_rounded,
                          color: Color(0xFFB45F6C),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}
