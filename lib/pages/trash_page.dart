import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/repositories/note_repository.dart';
import 'package:bloco_de_nota_turma_a/widgets/note_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final NoteRepository repository = NoteRepository();

  List<Note> notes = [];

  @override
  void initState() {
    super.initState();
    loadTrash();
  }

  Future<void> loadTrash() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final result = await repository.getTrash(user.uid);

    if (mounted) {
      setState(() {
        notes = result;
      });
    }
  }

  Future<void> restoreNote(Note note) async {
    await repository.restoreNote(note);
    await loadTrash();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Nota restaurada!")),
      );
    }
  }

  Future<void> deleteForever(Note note) async {
    final confirm = await confirmDialog(
      "Excluir definitivamente?",
      "A nota será apagada do aparelho e do Firebase. Não dá para desfazer.",
    );

    if (!confirm) return;

    await repository.deleteForever(note);
    await loadTrash();
  }

  Future<void> emptyTrash() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await confirmDialog(
      "Esvaziar a lixeira?",
      "Todas as notas da lixeira serão apagadas definitivamente.",
    );

    if (!confirm) return;

    await repository.emptyTrash(user.uid);
    await loadTrash();
  }

  Future<bool> confirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancelar"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text("Excluir", style: TextStyle(color: Color(0xFFB45F6C))),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Lixeira", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (notes.isNotEmpty)
            TextButton(
              onPressed: emptyTrash,
              child: Text("Esvaziar", style: TextStyle(color: Color(0xFFB45F6C))),
            ),
          SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "As notas ficam na lixeira por 30 dias. Depois disso são excluídas definitivamente.",
              style: TextStyle(color: Color(0xFF77717f), fontSize: 13),
            ),
            SizedBox(height: 20),
            if (notes.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Color(0xffede5fa),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 45,
                          color: Color(0xff6c4ab6),
                        ),
                      ),
                      SizedBox(height: 25),
                      Text("A lixeira está vazia"),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];

                    return NoteCard(
                      note: note,
                      onRestore: () => restoreNote(note),
                      onDelete: () => deleteForever(note),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
