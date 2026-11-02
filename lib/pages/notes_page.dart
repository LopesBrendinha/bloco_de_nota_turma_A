import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/pages/login_page.dart';
import 'package:bloco_de_nota_turma_a/pages/note_form_page.dart';
import 'package:bloco_de_nota_turma_a/pages/trash_page.dart';
import 'package:bloco_de_nota_turma_a/repositories/notes_repository.dart';
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
  final NotesRepository repository = NotesRepository();
  final AuthService authService = AuthService();
  final TextEditingController searchController = TextEditingController();

  List<Note> notes = [];
  List<String> categories = [];
  String? selectedCategory;
  NoteSort sort = NoteSort.updatedAt;

  bool syncing = false;
  String? syncMessage;

  // Evita que uma consulta antiga, que terminou depois, sobrescreva a nova.
  int _loadToken = 0;

  bool get hasFilters =>
      searchController.text.trim().isNotEmpty || selectedCategory != null;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    // Mostra primeiro o que já existe no aparelho e depois sincroniza.
    await loadNotes();
    await syncNotes();
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

    final token = ++_loadToken;

    final result = await repository.getNotes(
      uid: user.uid,
      search: searchController.text,
      category: selectedCategory,
      sort: sort,
    );
    final cats = await repository.getCategories(user.uid);

    if (!mounted || token != _loadToken) return;

    setState(() {
      notes = result;
      categories = cats;
    });
  }

  Future<void> syncNotes({bool showSuccess = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || syncing) return;

    setState(() {
      syncing = true;
    });

    final result = await repository.syncAll(user.uid);

    if (!mounted) return;

    setState(() {
      syncing = false;
      syncMessage = result.success ? null : result.message;
    });

    await loadNotes();

    if (showSuccess && result.success) {
      showMessage('Notas sincronizadas com o Firebase.');
    }
  }

  Future<void> moveToTrash(Note note) async {
    final messenger = ScaffoldMessenger.of(context);

    final result = await repository.moveToTrash(note);
    await loadNotes();

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? 'Nota movida para a lixeira.'
                : 'Nota movida para a lixeira. ${result.message} '
                      'Ela será sincronizada depois.',
          ),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () async {
              await repository.restoreNote(note);
              await loadNotes();
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
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> openEditNote(Note note) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteFormPage(note: note)),
    );

    await loadNotes();
  }

  Future<void> openNewNote() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NoteFormPage()),
    );

    await loadNotes();
  }

  Future<void> openTrash() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrashPage()),
    );

    await loadNotes();
  }

  void selectCategory(String? category) {
    setState(() {
      selectedCategory = category;
    });

    loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Mantém visível a categoria selecionada mesmo que ela fique sem notas.
    final chipCategories = <String>[
      ...categories,
      if (selectedCategory != null && !categories.contains(selectedCategory))
        selectedCategory!,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Minhas notas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<NoteSort>(
            tooltip: 'Ordenar',
            icon: const Icon(Icons.sort_rounded),
            initialValue: sort,
            onSelected: (value) {
              setState(() {
                sort = value;
              });

              loadNotes();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: NoteSort.updatedAt,
                child: Text('Última atualização'),
              ),
              PopupMenuItem(
                value: NoteSort.createdAt,
                child: Text('Data de criação'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Lixeira',
            onPressed: openTrash,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          IconButton(
            tooltip: 'Sincronizar',
            onPressed: syncing ? null : () => syncNotes(showSuccess: true),
            icon: syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
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
        onPressed: openNewNote,
        backgroundColor: const Color(0xFF6C4AB6),
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
              style: const TextStyle(color: Color(0xFF77717F), fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onChanged: (_) {
                setState(() {});
                loadNotes();
              },
              decoration: InputDecoration(
                hintText: 'Pesquisar por título ou conteúdo',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar pesquisa',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          searchController.clear();
                          setState(() {});
                          loadNotes();
                        },
                      ),
              ),
            ),
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
                      onSelected: (_) => selectCategory(null),
                    ),
                  ),
                  for (final category in chipCategories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: selectedCategory == category,
                        onSelected: (_) => selectCategory(category),
                      ),
                    ),
                ],
              ),
            ),
            if (syncMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4DD),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 18,
                      color: Color(0xFFC0892B),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$syncMessage Suas notas continuam salvas no aparelho.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B5320),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: syncing ? null : () => syncNotes(),
                      child: const Text('Tentar de novo'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => syncNotes(),
                child: notes.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 60),
                          _buildEmptyState(),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 90),
                        itemCount: notes.length,
                        itemBuilder: (context, index) {
                          final note = notes[index];

                          return NoteCard(
                            note: note,
                            sort: sort,
                            onTap: () => openEditNote(note),
                            actions: [
                              IconButton(
                                tooltip: 'Mover para a lixeira',
                                onPressed: () => moveToTrash(note),
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

  Widget _buildEmptyState() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFEDE5FA),
            shape: BoxShape.circle,
          ),
          child: Icon(
            hasFilters
                ? Icons.search_off_rounded
                : Icons.sticky_note_2_rounded,
            size: 44,
            color: const Color(0xFF6C4AB6),
          ),
        ),
        const SizedBox(height: 25),
        Text(
          hasFilters ? 'Nenhum resultado' : 'Nenhuma nota ainda',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          hasFilters
              ? 'Tente outro termo ou outra categoria.'
              : 'Crie sua primeira nota.',
        ),
      ],
    );
  }
}
