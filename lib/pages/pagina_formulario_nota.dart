import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/note.dart';
import '../services/notes_cloud_service.dart';

class PaginaFormularioNota extends StatefulWidget {
  final Note? note;

  const PaginaFormularioNota({super.key, this.note});

  @override
  State<PaginaFormularioNota> createState() => _PaginaFormularioNotaState();
}

class _PaginaFormularioNotaState extends State<PaginaFormularioNota> {
  final titleController = TextEditingController();

  final contentController = TextEditingController();
  final categoryController = TextEditingController();

  final database = DatabaseHelper.instance;
  final cloudService = NotesCloudService();

  bool get isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      titleController.text = widget.note!.title;

      contentController.text = widget.note!.content;
      categoryController.text = widget.note!.category;
    } else {
      categoryController.text = 'Pessoal';
    }
  }

  Future<void> saveNote() async {
    // Pegamos o usuário atualmente autenticado.
    final user = FirebaseAuth.instance.currentUser;

    // Sem usuário não podemos salvar.
    if (user == null) return;

    // Pegamos os valores digitados.
    final title = titleController.text.trim();

    final content = contentController.text.trim();

    // Verificamos se existe conteúdo.
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite o conteúdo da nota.')),
      );
      return;
    }

    // Criamos a data da alteração.
    final now = DateTime.now();

    final date =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    // Criamos um objeto Note.
    //
    // Se estamos editando:
    //     widget.note?.id
    // mantém o ID existente.
    //
    // Se estamos criando:
    //     o ID será null.
    final note = Note(
      id: widget.note?.id,
      uid: user.uid,
      title: title,
      content: content,
      date: date,
      category: categoryController.text.trim().isEmpty
          ? 'Pessoal'
          : categoryController.text.trim(),
      cloudId: widget.note?.cloudId ?? cloudService.createNoteId(user.uid),
      isSynced: false,
    );

    // Verificamos se estamos criando
    // ou editando uma nota.
    int localId;
    try {
      if (isEditing) {
        await database.updateNote(note);
        localId = note.id!;
      } else {
        localId = await database.insertNote(note);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar a nota no aparelho.'),
          ),
        );
      }
      return;
    }

    var cloudFailed = false;
    try {
      await cloudService.saveNote(note);
      await database.updateNote(note.copyWith(id: localId, isSynced: true));
    } catch (_) {
      cloudFailed = true;
    }

    // Depois de salvar,
    // voltamos para a tela anterior.
    if (mounted) {
      Navigator.pop(context, cloudFailed);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    categoryController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar nota' : 'Nova nota',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        actions: [
          IconButton(
            onPressed: saveNote,
            icon: const Icon(Icons.check_rounded),
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(22),

        child: Column(
          children: [
            TextField(
              controller: titleController,

              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF292333),
              ),

              decoration: const InputDecoration(
                hintText: 'Título',
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
              ),
            ),

            const Divider(color: Color(0xFFE4DFEA)),

            TextField(
              controller: categoryController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                hintText: 'Ex.: estudos, trabalho, pessoal',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: TextField(
                controller: contentController,

                maxLines: null,

                expands: true,

                textAlignVertical: TextAlignVertical.top,

                style: const TextStyle(
                  fontSize: 17,
                  height: 1.5,
                  color: Color(0xFF40394A),
                ),

                decoration: const InputDecoration(
                  hintText: 'Comece a escrever...',
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
