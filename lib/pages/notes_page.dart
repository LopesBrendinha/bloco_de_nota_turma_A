
import 'package:bloco_de_nota_turma_a/database/database_helper.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/pages/login_page.dart';
import 'package:bloco_de_nota_turma_a/pages/note_form_page.dart';
import 'package:bloco_de_nota_turma_a/services/auth_service.dart';
import 'package:bloco_de_nota_turma_a/services/sync_service.dart';
import 'package:bloco_de_nota_turma_a/widgets/note_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final DatabaseHelper database = DatabaseHelper.instance;
  final AuthService authService = AuthService();
  final SyncService syncService = SyncService();

  final TextEditingController searchController = TextEditingController();

  List<Note> notes = [];

  bool isLoading = true;
  bool isSyncing = false;
  bool showFavoritesOnly = false;

  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadNotes();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadNotes() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final localNotes = await database.getNotes(user.uid);

      if (mounted) {
        setState(() {
          notes = localNotes;
          isLoading = false;
        });
      }

      if (!isSyncing) {
        isSyncing = true;

        try {
          await syncService.synchronize(user.uid);

          final updatedNotes = await database.getNotes(user.uid);

          if (mounted) {
            setState(() {
              notes = updatedNotes;
            });
          }
        } catch (error) {
          debugPrint('Erro ao sincronizar notas: $error');
        } finally {
          isSyncing = false;
        }
      }
    } catch (error) {
      debugPrint('Erro ao carregar notas: $error');

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Marcar ou desmarcar nota como favorita.
  Future<void> toggleFavorite(Note note) async {
    if (note.id == null) return;

    try {
      await database.updateFavoriteStatus(
        note.id!,
        note.uid,
        !note.isFavorite,
      );

      final updatedNotes = await database.getNotes(note.uid);

      if (mounted) {
        setState(() {
          notes = updatedNotes;
        });
      }

      final updatedNote = updatedNotes.firstWhere(
        (item) => item.id == note.id,
      );

      // Tenta enviar a alteração para o Firebase.
      try {
        await syncService.uploadNote(updatedNote);

        final syncedNotes = await database.getNotes(note.uid);

        if (mounted) {
          setState(() {
            notes = syncedNotes;
          });
        }
      } catch (syncError) {
        debugPrint('Erro ao sincronizar favorito: $syncError');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            note.isFavorite
                ? 'Nota removida dos favoritos!'
                : 'Nota adicionada aos favoritos!',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      debugPrint('Erro ao atualizar favorito: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível atualizar o favorito.'),
        ),
      );
    }
  }

  Future<void> deleteNote(Note note) async {
    try {
      await syncService.deleteCloudNote(note);

      if (note.id != null) {
        await database.deleteNote(note.id!);
      }

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final updatedNotes = await database.getNotes(user.uid);

        if (mounted) {
          setState(() {
            notes = updatedNotes;
          });
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nota excluída com sucesso!'),
        ),
      );
    } catch (error) {
      debugPrint('Erro ao excluir nota: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível excluir a nota. Verifique sua conexão.',
          ),
        ),
      );
    }
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

  Future<void> openEditNote(Note note) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteFormPage(note: note),
      ),
    );

    await loadNotes();
  }

  Future<void> openNewNote() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NoteFormPage(),
      ),
    );

    await loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Pesquisa e filtro de favoritas.
    final filteredNotes = notes.where((note) {
      final query = searchQuery.toLowerCase().trim();

      final matchesSearch =
          note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query);

      final matchesFavorite =
          !showFavoritesOnly || note.isFavorite;

      return matchesSearch && matchesFavorite;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Minhas notas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronizar',
            onPressed: loadNotes,
            icon: const Icon(Icons.sync),
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
        backgroundColor: const Color(0xff6c4ab6),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nova Nota',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user?.email ?? '',
              style: const TextStyle(
                color: Color(0xFF77717f),
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 18),

            // Campo de pesquisa.
            TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Pesquisar por título ou conteúdo...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xff6c4ab6),
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          searchController.clear();

                          setState(() {
                            searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.close),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xfff5f2fa),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Filtro de favoritas.
            Row(
              children: [
                FilterChip(
                  selected: showFavoritesOnly,
                  onSelected: (selected) {
                    setState(() {
                      showFavoritesOnly = selected;
                    });
                  },
                  avatar: Icon(
                    showFavoritesOnly
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: showFavoritesOnly
                        ? Colors.amber
                        : const Color(0xff6c4ab6),
                  ),
                  label: const Text('Somente favoritas'),
                  selectedColor: const Color(0xffede5fa),
                  checkmarkColor: const Color(0xff6c4ab6),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (notes.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('Nenhuma nota ainda. Crie sua primeira nota.'),
                ),
              )
            else if (filteredNotes.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off_rounded,
                        size: 55,
                        color: Color(0xff9A94A1),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        showFavoritesOnly && searchQuery.isEmpty
                            ? 'Nenhuma nota favorita'
                            : 'Nenhuma nota encontrada',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Experimente alterar os filtros.',
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: filteredNotes.length,
                  itemBuilder: (context, index) {
                    final note = filteredNotes[index];

                    return NoteCard(
                      note: note,
                      onTap: () => openEditNote(note),
                      onDelete: () => deleteNote(note),
                      onFavorite: () => toggleFavorite(note),
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
