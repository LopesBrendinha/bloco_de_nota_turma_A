import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/note.dart';
import '../repositories/note_repository.dart';

class NoteFormPage extends StatefulWidget {
  final Note? note;

  // categoria que estava selecionada na lista (para nota nova)
  final String? category;

  const NoteFormPage({super.key, this.note, this.category});

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  final titleController = TextEditingController();

  final contentController = TextEditingController();

  final categoryController = TextEditingController();

  final repository = NoteRepository();

  List<String> categories = [];

  String selectedCategory = 'Pessoal';

  bool get isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      titleController.text = widget.note!.title;

      contentController.text = widget.note!.content;

      selectedCategory = widget.note!.category;
    } else if (widget.category != null && widget.category!.isNotEmpty) {
      selectedCategory = widget.category!;
    }

    loadCategories();
  }

  Future<void> loadCategories() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final result = await repository.getCategories(user.uid);

    if (mounted) {
      setState(() {
        categories = result;
      });
    }
  }

  Future<void> newCategory() async {
    categoryController.clear();

    // Abrimos um dialog para o usuário digitar o nome da categoria.
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nova categoria'),
          content: TextField(
            controller: categoryController,
            autofocus: true,
            maxLength: 20,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Ex: Faculdade',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, categoryController.text.trim()),
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty || !mounted) return;

    // Verificamos se a categoria já existe
    // (sem diferenciar maiúsculas de minúsculas).
    final exists = categories.any(
      (category) => category.toLowerCase() == name.toLowerCase(),
    );

    if (exists) {
      showMessage('Essa categoria já existe.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await repository.addCategory(user.uid, name);

    await loadCategories();

    if (mounted) {
      setState(() {
        selectedCategory = name;
      });
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
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
      showMessage('Escreva alguma coisa na nota.');
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
      firebaseId: widget.note?.firebaseId,
      uid: user.uid,
      title: title,
      content: content,
      category: selectedCategory,
      date: date,
      // a data de criação não muda quando a nota é editada
      createdAt: widget.note?.createdAt ?? now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    );

    // O repository decide se é INSERT ou UPDATE.
    // A nota fica salva no SQLite e é enviada
    // para o Firebase na sincronização.
    await repository.saveNote(note);

    // Depois de salvar,
    // voltamos para a tela anterior.
    if (mounted) {
      Navigator.pop(context);
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

            const SizedBox(height: 6),

            // categorias: escolhe uma ou cria uma nova
            SizedBox(
              height: 40,

              child: ListView(
                scrollDirection: Axis.horizontal,

                children: [
                  for (var category in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),

                      child: ChoiceChip(
                        label: Text(category),
                        selected: selectedCategory == category,
                        showCheckmark: false,
                        side: BorderSide.none,
                        backgroundColor: const Color(0xFFEDE5FA),
                        selectedColor: const Color(0xFF6C4AB6),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selectedCategory == category
                              ? Colors.white
                              : const Color(0xFF40394A),
                        ),
                        onSelected: (_) {
                          setState(() {
                            selectedCategory = category;
                          });
                        },
                      ),
                    ),

                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nova categoria'),
                    side: BorderSide.none,
                    backgroundColor: Colors.white,
                    onPressed: newCategory,
                  ),
                ],
              ),
            ),

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
