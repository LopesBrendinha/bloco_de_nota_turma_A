import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/pages/login_page.dart';
import 'package:bloco_de_nota_turma_a/pages/note_form_page.dart';
import 'package:bloco_de_nota_turma_a/pages/trash_page.dart';
import 'package:bloco_de_nota_turma_a/repositories/note_repository.dart';
import 'package:bloco_de_nota_turma_a/services/auth_service.dart';
import 'package:bloco_de_nota_turma_a/widgets/note_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final NoteRepository repository = NoteRepository.instance;
  final AuthService authService = AuthService();
  final TextEditingController searchController = TextEditingController();

  List<Note> notes = [];
  List<String> categories = [];
  String? selectedCategory;
  String query = '';
  int runningSyncs = 0;

  bool get syncing => runningSyncs > 0;

  @override
  void initState() {
    super.initState();
    start();
  }

  /// Mostra primeiro o que já está no aparelho e depois sincroniza com
  /// o Firebase (isso também recupera as notas em uma nova instalação).
  Future<void> start() async {
    await loadNotes();
    if (!mounted) return;
    await sync();
  }

  /// Contador para ignorar respostas antigas quando o usuário digita rápido.
  int loadCounter = 0;

  Future<void> loadNotes() async {
    try {
      await _loadNotes();
    } catch (e) {
      if (mounted) {
        showMessage(describeLocalError(e));
      }
    }
  }

  Future<void> _loadNotes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentLoad = ++loadCounter;
    final cats = await repository.getCategories(user.uid);

    // Se a categoria filtrada não existe mais, volta para "Todas".
    if (selectedCategory != null && !cats.contains(selectedCategory)) {
      selectedCategory = null;
    }

    final result = await repository.getNotes(
      user.uid,
      query: query,
      category: selectedCategory,
    );

    if (!mounted || currentLoad != loadCounter) return;
    setState(() {
      notes = result;
      categories = cats;
    });
  }

  Future<void> sync({bool showSuccess = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted || user == null) return;

    setState(() {
      runningSyncs++;
    });

    // O repositório enfileira as sincronizações, então chamar sync() várias
    // vezes seguidas é seguro: cada uma roda depois da anterior.
    final result = await repository.syncAll(user.uid);
    await loadNotes();

    if (!mounted) return;
    setState(() {
      runningSyncs--;
    });

    if (!result.success) {
      showMessage(result.message ?? 'Não foi possível sincronizar.');
    } else if (showSuccess) {
      showMessage('Notas sincronizadas com o Firebase.');
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

  /// "Excluir" manda a nota para a lixeira, com opção de desfazer.
  Future<void> deleteNote(Note note) async {
    try {
      await repository.moveToTrash(note);
    } catch (e) {
      if (mounted) showMessage(describeLocalError(e));
      return;
    }

    await loadNotes();
    sync(); // envia a alteração ao Firebase em segundo plano

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Nota movida para a lixeira.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () async {
            try {
              await repository.restore(note);
            } catch (e) {
              if (mounted) showMessage(describeLocalError(e));
              return;
            }
            await loadNotes();
            sync();
          },
        ),
      ),
    );
  }

  Future<void> logout() async {
    await authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
      (route) => false,
    );
  }

  Future<void> openForm({Note? note}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NoteFormPage(note: note)),
    );

    await loadNotes();

    // A nota já está no SQLite; agora enviamos ao Firebase em segundo plano.
    if (saved == true) {
      sync();
    }
  }

  Future<void> openTrash() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrashPage()),
    );

    await loadNotes();
    sync();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final hasFilter = query.trim().isNotEmpty || selectedCategory != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Minhas notas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (syncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Sincronizar',
              onPressed: () => sync(showSuccess: true),
              icon: const Icon(Icons.sync_rounded),
            ),
          IconButton(
            tooltip: 'Lixeira',
            onPressed: openTrash,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: logout,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openForm(),
        backgroundColor: const Color(0xff6c4ab6),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nova Nota',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user?.email ?? '',
              style: const TextStyle(color: Color(0xFF77717f), fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() {
                  query = value;
                });
                loadNotes();
              },
              decoration: InputDecoration(
                hintText: 'Pesquisar por título ou conteúdo',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar pesquisa',
                        onPressed: () {
                          searchController.clear();
                          setState(() {
                            query = '';
                          });
                          loadNotes();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('Todas'),
                        selected: selectedCategory == null,
                        onSelected: (_) {
                          setState(() {
                            selectedCategory = null;
                          });
                          loadNotes();
                        },
                      ),
                    ),
                    for (final category in categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: selectedCategory == category,
                          onSelected: (_) {
                            setState(() {
                              selectedCategory = category;
                            });
                            loadNotes();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (notes.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: const BoxDecoration(
                          color: Color(0xffede5fa),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          hasFilter
                              ? Icons.search_off_rounded
                              : Icons.sticky_note_2_rounded,
                          size: 44,
                          color: const Color(0xff6c4ab6),
                        ),
                      ),
                      const SizedBox(height: 25),
                      Text(
                        hasFilter
                            ? 'Nenhuma nota encontrada'
                            : 'Nenhuma nota ainda',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasFilter
                            ? 'Tente outra pesquisa ou categoria.'
                            : 'Crie sua primeira nota.',
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => sync(showSuccess: true),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];

                      return NoteCard(
                        note: note,
                        onTap: () => openForm(note: note),
                        actions: [
                          IconButton(
                            tooltip: 'Mover para a lixeira',
                            onPressed: () => deleteNote(note),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFB45F6C),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
