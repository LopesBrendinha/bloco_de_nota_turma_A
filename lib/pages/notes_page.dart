import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/pages/login_page.dart';
import 'package:bloco_de_nota_turma_a/pages/note_form_page.dart';
import 'package:bloco_de_nota_turma_a/pages/trash_page.dart';
import 'package:bloco_de_nota_turma_a/repositories/note_repository.dart';
import 'package:bloco_de_nota_turma_a/services/auth_service.dart';
import 'package:bloco_de_nota_turma_a/widgets/note_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final NoteRepository repository = NoteRepository();
  final AuthService authService = AuthService();
  final searchController = TextEditingController();

  List<Note> notes = [];
  List<String> categories = [];

  // "" = todas as categorias
  String selectedCategory = "";

  // ordem da lista (vai direto no ORDER BY do SQLite)
  String order = "updatedAt DESC";

  bool syncing = false;
  bool syncAgain = false;
  bool syncError = false;

  @override
  void initState() {
    super.initState();
    loadNotes();
    syncNotes();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadNotes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final resultCategories = await repository.getCategories(user.uid);
    final result = await repository.getNotes(
      user.uid,
      search: searchController.text.trim(),
      category: selectedCategory,
      order: order,
    );

    if (mounted) {
      setState(() {
        categories = resultCategories;
        notes = result;
      });
    }
  }

  void changeOrder(String value) {
    setState(() {
      order = value;
    });
    loadNotes();
  }

  void selectCategory(String category) {
    setState(() {
      selectedCategory = category;
    });
    loadNotes();
  }

  Future<void> syncNotes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // se já estiver sincronizando, sincroniza de novo quando terminar
    if (syncing) {
      syncAgain = true;
      return;
    }

    setState(() {
      syncing = true;
    });

    final success = await repository.syncNotes(user.uid);
    await loadNotes();

    if (!mounted) return;

    setState(() {
      syncing = false;
      syncError = !success;
    });

    if (syncAgain) {
      syncAgain = false;
      syncNotes();
    }
  }

  // não apaga de verdade, manda para a lixeira
  Future<void> deleteNote(Note note) async {
    await repository.moveToTrash(note);
    await loadNotes();
    syncNotes();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Nota movida para a lixeira"),
          action: SnackBarAction(
            label: "Desfazer",
            onPressed: () => restoreNote(note),
          ),
        ),
      );
    }
  }

  Future<void> restoreNote(Note note) async {
    await repository.restoreNote(note);
    await loadNotes();
    syncNotes();
  }

  Future<void> openTrash() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrashPage()),
    );

    await loadNotes();
    syncNotes();
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

  Future<void> openEditNote(Note note) async{
    await Navigator.push(context, 
    MaterialPageRoute(builder:(_)=> NoteFormPage(note: note)));

    await loadNotes();
    syncNotes();
  }
  Future<void> openNewNote() async{
    await Navigator.push(context, 
    MaterialPageRoute(builder:(_)=> NoteFormPage(category: selectedCategory)));

    await loadNotes();
    syncNotes();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final searching = searchController.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text("Minhas notas", style: TextStyle(fontWeight:FontWeight.bold )),
        actions:[
          syncing
              ? Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: "Sincronizar",
                  onPressed: syncNotes,
                  icon: Icon(Icons.sync_rounded),
                ),
          PopupMenuButton<String>(
            tooltip: "Ordenar",
            icon: Icon(Icons.sort_rounded),
            onSelected: changeOrder,
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: "updatedAt DESC",
                checked: order == "updatedAt DESC",
                child: Text("Última atualização"),
              ),
              CheckedPopupMenuItem(
                value: "createdAt DESC",
                checked: order == "createdAt DESC",
                child: Text("Criação: mais recentes"),
              ),
              CheckedPopupMenuItem(
                value: "createdAt ASC",
                checked: order == "createdAt ASC",
                child: Text("Criação: mais antigas"),
              ),
            ],
          ),
          IconButton(
            tooltip: "Lixeira",
            onPressed: openTrash,
            icon: Icon(Icons.delete_outline_rounded),
          ),
          IconButton(
            tooltip: "Sair",
            onPressed: logout,
            icon: Icon(Icons.logout_rounded)
          ),
          SizedBox(width: 8)
        ] 
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openNewNote,
        backgroundColor: Color(0xff6c4ab6),
        foregroundColor: Colors.white,
        icon: Icon(Icons.add_rounded),
        label: Text("Nova Nota", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(20,10,20,90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:[
            Text(user?.email ?? "", style: TextStyle(color: Color(0xFF77717f), fontSize:13)),
            if (syncError)
              Container(
                margin: EdgeInsets.only(top: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xfffff3e6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 20, color: Color(0xffb7791f)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Sem conexão com o Firebase. Suas notas estão salvas no aparelho e serão enviadas quando a conexão voltar.",
                        style: TextStyle(fontSize: 13, color: Color(0xff7a4b12)),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 16),
            TextField(
              controller: searchController,
              onChanged: (value) => loadNotes(),
              decoration: InputDecoration(
                hintText: "Pesquisar por título ou conteúdo",
                prefixIcon: Icon(Icons.search_rounded),
                suffixIcon: searching
                    ? IconButton(
                        tooltip: "Limpar pesquisa",
                        onPressed: () {
                          searchController.clear();
                          loadNotes();
                        },
                        icon: Icon(Icons.close_rounded),
                      )
                    : null,
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  categoryChip("Todas", ""),
                  for (var category in categories) categoryChip(category, category),
                ],
              ),
            ),
            SizedBox(height: 16),
            if (searching)
              Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  notes.length == 1
                      ? "1 nota encontrada"
                      : "${notes.length} notas encontradas",
                  style: TextStyle(color: Color(0xFF77717f), fontSize: 13),
                ),
              ),
            if(notes.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children:[
                      Container(
                        width: 100,
                        height:100,

                        decoration: BoxDecoration(
                          color: Color(0xffede5fa),
                          shape: BoxShape.circle
                        ),
                        child: Icon(
                          Icons.sticky_note_2_rounded,
                          size: 45,
                          color: Color(0xff6c4ab6)
                        )
                      ),
                      SizedBox(height: 25),
                      Text(
                        searching
                            ? "Nenhuma nota encontrada"
                            : selectedCategory.isEmpty
                                ? "Nenhuma nota ainda"
                                : "Nenhuma nota em $selectedCategory",
                      ),
                      SizedBox(height: 8),
                      Text(searching ? 'Tente pesquisar outra palavra.' : 'Crie sua primeira nota.')
                    ]
                  )
                )
              )
            else
                Expanded(
                  child: ListView.builder(
                    itemCount: notes.length,
                    itemBuilder: (context, index){
                      final note = notes[index];

                      return NoteCard(
                        note: note,
                        onTap: () => openEditNote(note),
                        onDelete: () => deleteNote(note),
                      );
                    }
                  )
                )

          ],
        ),
      ),
    );
  }

  Widget categoryChip(String label, String value) {
    final selected = selectedCategory == value;

    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        side: BorderSide.none,
        backgroundColor: Colors.white,
        selectedColor: Color(0xff6c4ab6),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : Color(0xff40394a),
        ),
        onSelected: (_) => selectCategory(value),
      ),
    );
  }
}
