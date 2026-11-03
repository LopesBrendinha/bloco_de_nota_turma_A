import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/repositories/note_repository.dart';
import 'package:bloco_de_nota_turma_a/widgets/note_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Lixeira: notas excluídas temporariamente. Daqui o usuário pode
/// restaurar a nota ou excluí-la definitivamente.
class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final NoteRepository repository = NoteRepository.instance;

  List<Note> notes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
      return;
    }

    try {
      final result = await repository.getTrash(user.uid);

      if (!mounted) return;
      setState(() {
        notes = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
      showMessage(describeLocalError(e));
    }
  }

  /// Envia as alterações ao Firebase sem fazer a tela esperar.
  void syncInBackground() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      repository.syncAll(user.uid);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> restore(Note note) async {
    try {
      await repository.restore(note);
    } catch (e) {
      if (mounted) showMessage(describeLocalError(e));
      return;
    }

    await load();
    syncInBackground();

    if (!mounted) return;
    showMessage('Nota restaurada.');
  }

  Future<void> deleteForever(Note note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir definitivamente?'),
          content: const Text(
            'Esta nota será apagada do aparelho e do Firebase. '
            'Não será possível recuperá-la.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await repository.deleteForever(note);
    } catch (e) {
      if (mounted) showMessage(describeLocalError(e));
      return;
    }

    await load();
    syncInBackground();

    if (!mounted) return;
    showMessage('Nota excluída definitivamente.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lixeira',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notes.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    size: 48,
                    color: Color(0xFF6C4AB6),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'A lixeira está vazia',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];

                return NoteCard(
                  note: note,
                  onTap: () {},
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
                );
              },
            ),
    );
  }
}
