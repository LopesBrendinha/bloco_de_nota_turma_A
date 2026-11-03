import 'dart:async';

import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/pages/note_form_page.dart';
import 'package:bloco_de_nota_turma_a/repositories/note_filter.dart';
import 'package:bloco_de_nota_turma_a/repositories/note_repository.dart';
import 'package:bloco_de_nota_turma_a/services/auth_service.dart';
import 'package:bloco_de_nota_turma_a/widgets/note_card.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with WidgetsBindingObserver {
  final NoteRepository repository = NoteRepository();
  final AuthService authService = AuthService();

  List<Note> notes = [];
  bool offline = false;
  StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;
  final searchController = TextEditingController();
  List<String> categories = [];
  String query = '';
  String? selectedCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        runSync();
      }
    });
    loadNotes();
    runSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    connectivitySubscription?.cancel();
    searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      runSync();
    }
  }

  Future<void> loadNotes() async {
    final result = await repository.getNotes();
    final resultCategories = await repository.getCategories();

    if (mounted) {
      setState(() {
        notes = result;
        categories = resultCategories;
        if (!categories.contains(selectedCategory)) {
          selectedCategory = null;
        }
      });
    }
  }

  Future<SyncResult> runSync() async {
    final result = await repository.sync();
    if (!mounted) return result;

    setState(() {
      offline = result == SyncResult.offline;
    });
    if (result == SyncResult.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Não foi possível sincronizar. Tente novamente.")),
      );
    }
    await loadNotes();
    return result;
  }

  Future<void> refresh() async {
    final result = await runSync();
    if (result == SyncResult.ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Notas sincronizadas")));
    }
  }

  Future<void> deleteNote(Note note) async {
    await repository.delete(note);
    await loadNotes();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Nota deletada com sucesso!")));
    }
    unawaited(runSync());
  }

  Future<void> logout() async {
    await authService.logout();
  }

  Future<void> openEditNote(Note note) async{
    await Navigator.push(context, 
    MaterialPageRoute(builder:(_)=> NoteFormPage(note: note)));

    await loadNotes();
    unawaited(runSync());
  }
  Future<void> openNewNote() async{
    await Navigator.push(context, 
    MaterialPageRoute(builder:(_)=> NoteFormPage()));

    await loadNotes();
    unawaited(runSync());
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final visible = filterNotes(
      notes,
      query: query,
      category: selectedCategory,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text("Minhas notas", style: TextStyle(fontWeight:FontWeight.bold )),
        actions:[
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
            if (offline)
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Color(0xffede5fa),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 18, color: Color(0xff6c4ab6)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Sem conexão — suas notas serão sincronizadas quando a internet voltar.",
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            Text(user?.email ?? "", style: TextStyle(color: Color(0xFF77717f), fontSize:13)),
            SizedBox(height: 12),
            TextField(
              controller: searchController,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                hintText: "Pesquisar no título ou no conteúdo",
                prefixIcon: Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: "Limpar pesquisa",
                        icon: Icon(Icons.close_rounded),
                        onPressed: () {
                          searchController.clear();
                          setState(() => query = '');
                        },
                      ),
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final category in [null, ...categories])
                    Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(category ?? "Todas"),
                        selected: selectedCategory == category,
                        onSelected: (_) => setState(() => selectedCategory = category),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: refresh,
                // O RefreshIndicator só reage se o filho rolar, e uma lista
                // vazia ou curta não rola sozinha (caso da reinstalação).
                child: visible.isEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          physics: AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: constraints.maxHeight,
                            child: notes.isEmpty ? emptyState() : noResults(),
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: AlwaysScrollableScrollPhysics(),
                        itemCount: visible.length,
                        itemBuilder: (context, index){
                          final note = visible[index];

                          return NoteCard(
                            note: note,
                            onTap: () => openEditNote(note),
                            onDelete: () => deleteNote(note),
                          );
                        }
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget noResults() {
    return Center(
      child: Text(
        query.trim().isEmpty
            ? "Nenhuma nota nesta categoria"
            : "Nenhuma nota encontrada para \"${query.trim()}\"",
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget emptyState() {
    return Center(
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
              color: Color(0xff6c4ab6)
            )
          ),
          SizedBox(height: 25),
          Text("Nenhuma nota ainda"),
          SizedBox(height: 8),
          Text('Crie sua primeira nota.')
        ]
      )
    );
  }
}
