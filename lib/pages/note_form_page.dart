
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/notes_service.dart';

class NoteFormPage extends StatefulWidget {
  final Note? note;

  const NoteFormPage({super.key, this.note});

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  final title = TextEditingController();
  final content = TextEditingController();
  final category = TextEditingController();

  bool pinned = false;
  bool saving = false;

  bool get editing => widget.note != null;

  @override
  void initState() {
    super.initState();

    final n = widget.note;

    if (n != null) {
      title.text = n.title;
      content.text = n.content;
      category.text = n.category;
      pinned = n.pinned;
    } else {
      category.text = 'Geral';
    }
  }

  Future<void> save() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    if (content.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escreva algum conteúdo antes de salvar.'),
        ),
      );
      return;
    }

    setState(() => saving = true);

    final now = DateTime.now();

    final date =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    final old = widget.note;

    final note = Note(
      id: old?.id,
      cloudId: old?.cloudId ?? '',
      uid: user.uid,
      title: title.text.trim(),
      content: content.text.trim(),
      category: category.text.trim().isEmpty
          ? 'Geral'
          : category.text.trim(),
      date: date,
      pinned: pinned,
    );

    try {
      await NotesService().save(note);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      debugPrint('ERRO AO SALVAR NOTA: $e');
      debugPrint('DETALHES: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  void dispose() {
    title.dispose();
    content.dispose();
    category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar anotação' : 'Nova anotação'),
        actions: [
          IconButton(
            onPressed: saving ? null : save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: title,
            decoration: const InputDecoration(
              labelText: 'Título',
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: category,
            decoration: const InputDecoration(
              labelText: 'Categoria',
              hintText: 'Ex.: Estudos, Trabalho, Pessoal',
            ),
          ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: pinned,
            title: const Text('Fixar no início da lista'),
            onChanged: (v) {
              setState(() => pinned = v);
            },
          ),

          const SizedBox(height: 8),

          TextField(
            controller: content,
            minLines: 10,
            maxLines: 18,
            decoration: const InputDecoration(
              alignLabelWithHint: true,
              labelText: 'Anotação',
            ),
          ),

          const SizedBox(height: 18),

          FilledButton.icon(
            onPressed: saving ? null : save,
            icon: const Icon(Icons.cloud_done_outlined),
            label: Text(
              saving ? 'Salvando...' : 'Salvar anotação',
            ),
          ),
        ],
      ),
    );
  }
}
