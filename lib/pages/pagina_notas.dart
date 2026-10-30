import 'package:bloco_de_nota_turma_a/database/database_helper.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/pages/pagina_login.dart';
import 'package:bloco_de_nota_turma_a/pages/pagina_formulario_nota.dart';
import 'package:bloco_de_nota_turma_a/services/auth_service.dart';
import 'package:bloco_de_nota_turma_a/widgets/note_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../services/notes_cloud_service.dart';

class PaginaNotas extends StatefulWidget {
  const PaginaNotas({super.key});

  @override
  State<PaginaNotas> createState() => _PaginaNotasState();
}

class _PaginaNotasState extends State<PaginaNotas> {
  final DatabaseHelper database = DatabaseHelper.instance;
  final AuthService authService = AuthService();
  final NotesCloudService cloudService = NotesCloudService();

  List<Note> notes = [];
  final searchController = TextEditingController();
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
    final localNotes = await database.getNotes(user.uid);

    if (mounted) {
      setState(() => notes = localNotes);
    }

    try {
      for (final localNote in localNotes.where((note) => !note.isSynced)) {
        final note = localNote.cloudId == null
            ? localNote.copyWith(cloudId: cloudService.createNoteId(user.uid))
            : localNote;
        if (note.cloudId != localNote.cloudId) {
          await database.updateNote(note);
        }
        await cloudService.saveNote(note);
        await database.updateNote(note.copyWith(isSynced: true));
      }

      final cloudNotes = await cloudService.getNotes(user.uid);
      for (final cloudNote in cloudNotes) {
        await database.saveCloudNote(cloudNote);
      }

      final updatedNotes = await database.getNotes(user.uid);
      if (mounted) setState(() => notes = updatedNotes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sem conexão com o Firebase. As notas locais foram mantidas.',
            ),
          ),
        );
      }
    }
  }

  Future<void> deleteNote(Note note) async {
    try {
      await cloudService.deleteNote(note);
      await database.deleteNote(note.id!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível excluir a nota no Firebase.'),
          ),
        );
      }
      return;
    }
    await loadNotes();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Nota deletada com sucesso!")));
    }
  }

  Future<void> logout() async {
    await authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => PaginaLogin()),
      (route) => false,
    );
  }

  Future<void> openEditNote(Note note) async {
    final cloudFailed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => PaginaFormularioNota(note: note)),
    );

    await loadNotes();
    if (cloudFailed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nota salva no aparelho; será enviada ao Firebase depois.',
          ),
        ),
      );
    }
  }

  Future<void> openNewNote() async {
    final cloudFailed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => PaginaFormularioNota()),
    );

    await loadNotes();
    if (cloudFailed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nota salva no aparelho; será enviada ao Firebase depois.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final query = searchQuery.trim().toLowerCase();
    final filteredNotes = notes
        .where(
          (note) =>
              note.title.toLowerCase().contains(query) ||
              note.content.toLowerCase().contains(query) ||
              note.category.toLowerCase().contains(query),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Minhas notas",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: "Sair",
            onPressed: logout,
            icon: Icon(Icons.logout_rounded),
          ),
          SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openNewNote,
        backgroundColor: Color(0xff6c4ab6),
        foregroundColor: Colors.white,
        icon: Icon(Icons.add_rounded),
        label: Text("Nova Nota", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user?.email ?? "",
              style: TextStyle(color: Color(0xFF77717f), fontSize: 13),
            ),
            SizedBox(height: 20),
            TextField(
              controller: searchController,
              onChanged: (value) => setState(() => searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Pesquisar título, conteúdo ou categoria',
                prefixIcon: Icon(Icons.search_rounded),
                suffixIcon: searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar pesquisa',
                        onPressed: () {
                          searchController.clear();
                          setState(() => searchQuery = '');
                        },
                        icon: Icon(Icons.close_rounded),
                      ),
              ),
            ),
            SizedBox(height: 16),
            if (filteredNotes.isEmpty)
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
                          Icons.sticky_note_2_rounded,
                          color: Color(0xffede5fa),
                        ),
                      ),
                      SizedBox(height: 25),
                      Text(
                        notes.isEmpty
                            ? "Nenhuma nota ainda"
                            : "Nenhum resultado",
                      ),
                      SizedBox(height: 8),
                      Text('Crie sua primeira nota.'),
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
