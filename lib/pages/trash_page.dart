import 'package:flutter/material.dart';

import '../models/note.dart';
import '../repositories/note_repository.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final repository = NoteRepository();

  List<Note> notes = [];

  @override
  void initState() {
    super.initState();
    loadTrash();
  }

  Future<void> loadTrash() async {
    final result = await repository.getTrash();

    if (mounted) {
      setState(() {
        notes = result;
      });
    }
  }

  Future<bool> confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Color(0xFFB45F6C))),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> restore(Note note) async {
    await repository.restore(note);
    await loadTrash();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nota restaurada')),
      );
    }
  }

  Future<void> deletePermanently(Note note) async {
    final ok = await confirm(
      'Excluir definitivamente?',
      'A nota será apagada deste aparelho e da nuvem. Não dá para desfazer.',
    );
    if (!ok) return;
    await repository.deletePermanently(note);
    await loadTrash();
  }

  Future<void> emptyTrash() async {
    final ok = await confirm(
      'Esvaziar lixeira?',
      'Todas as notas da lixeira serão apagadas de vez. Não dá para desfazer.',
    );
    if (!ok) return;
    await repository.emptyTrash();
    await loadTrash();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lixeira', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: notes.isEmpty ? null : emptyTrash,
            child: const Text('Esvaziar lixeira'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: notes.isEmpty
          ? const Center(child: Text('A lixeira está vazia'))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];

                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          title: Text(
                            note.title.isEmpty ? 'Sem título' : note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            note.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        OverflowBar(
                          alignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => restore(note),
                              icon: const Icon(Icons.restore_rounded),
                              label: const Text('Restaurar'),
                            ),
                            TextButton.icon(
                              onPressed: () => deletePermanently(note),
                              icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFB45F6C)),
                              label: const Text(
                                'Excluir definitivamente',
                                style: TextStyle(color: Color(0xFFB45F6C)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
