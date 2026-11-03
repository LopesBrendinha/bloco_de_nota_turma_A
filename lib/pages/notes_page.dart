import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/note.dart';
import '../repositories/notes_repository.dart';
import '../services/cloud_store.dart';
import '../services/reminder_service.dart';
import '../widgets/note_card.dart';
import 'note_form_page.dart';

class NotesPage extends StatefulWidget {
  final NotesRepository? repository;
  final String? email;
  const NotesPage({super.key, this.repository, this.email});
  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with WidgetsBindingObserver {
  late final NotesRepository repo;
  late final ReminderService reminders;
  final searchController = TextEditingController();
  Timer? _timer;
  String? category;
  String? reminderError;
  bool archived = false, loading = true;
  List<Note> due = [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final injected = widget.repository;
    if (injected != null) {
      repo = injected;
    } else {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      repo = NotesRepository(
        local: DatabaseHelper.instance,
        cloud: FirestoreCloudStore(
          FirebaseFirestore.instance,
          () => FirebaseAuth.instance.currentUser?.uid,
        ),
        uid: uid,
        sessionValid: () => FirebaseAuth.instance.currentUser?.uid == uid,
      );
    }
    reminders = ReminderService(repo.local);
    repo.addListener(_changed);
    unawaited(
      repo.start().whenComplete(() {
        if (mounted) setState(() => loading = false);
      }),
    );
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_checkDue()),
    );
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    unawaited(
      reminders.update(repo.notes).catchError((Object _) {
        if (mounted) {
          setState(
            () => reminderError =
                'Não foi possível agendar a notificação. O lembrete continua disponível no aplicativo.',
          );
        }
      }),
    );
    unawaited(_checkDue());
  }

  Future<void> _checkDue() async {
    try {
      final result = await reminders.due(repo.notes);
      if (mounted) setState(() => due = result);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              reminderError = 'Não foi possível consultar os lembretes locais.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(repo.sync());
      unawaited(_checkDue());
    }
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> edit([Note? note]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NoteFormPage(repository: repo, reminders: reminders, note: note),
      ),
    );
  }

  Future<void> delete(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir nota?'),
        content: const Text(
          'A exclusão será enviada também para a nuvem e outras instalações.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _save(note.edit(deleted: true));
  }

  Future<void> _save(Note note) async {
    try {
      await repo.save(note);
    } catch (_) {
      message('Não foi possível salvar no banco local. Tente novamente.');
    }
  }

  Future<void> logout() async {
    if (repo.pending > 0) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Há alterações pendentes'),
          content: const Text(
            'Elas ficarão neste dispositivo e serão enviadas quando você entrar novamente nesta conta. Deseja sair?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ficar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sair'),
            ),
          ],
        ),
      );
      if (yes != true) return;
    }
    try {
      await reminders.stop();
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      message('Não foi possível sair. Tente novamente.');
    }
  }

  Future<void> showReminders() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lembretes vencidos'),
        content: SizedBox(
          width: 440,
          child: ListView(
            shrinkWrap: true,
            children: due
                .map(
                  (n) => ListTile(
                    title: Text(n.title.isEmpty ? 'Sem título' : n.title),
                    subtitle: Text(Note.formatDate(n.reminderAt!)),
                    onTap: () {
                      Navigator.pop(ctx);
                      unawaited(edit(n));
                    },
                    trailing: IconButton(
                      tooltip: 'Marcar como visto',
                      icon: const Icon(Icons.done),
                      onPressed: () async {
                        try {
                          await reminders.dismiss(n);
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _checkDue();
                        } catch (_) {
                          message(
                            'Não foi possível marcar o lembrete como visto.',
                          );
                        }
                      },
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    searchController.dispose();
    repo.removeListener(_changed);
    repo.dispose();
    unawaited(reminders.stop().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = repo.search(
      query: searchController.text,
      category: category,
      archived: archived,
    );
    final email =
        widget.email ?? FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Meu bloco de notas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronizar agora',
            onPressed: repo.syncing ? null : repo.sync,
            icon: const Icon(Icons.sync),
          ),
          if (widget.repository == null)
            IconButton(
              tooltip: 'Sair',
              onPressed: logout,
              icon: const Icon(Icons.logout_rounded),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('Nova nota'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email, style: const TextStyle(color: Color(0xff77717f))),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          repo.syncError != null
                              ? Icons.cloud_off
                              : repo.syncing
                              ? Icons.sync
                              : Icons.cloud_done_outlined,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            repo.localError ??
                                repo.syncError ??
                                (repo.syncing
                                    ? 'Sincronizando… ${repo.pending} alterações pendentes'
                                    : repo.pending > 0
                                    ? '${repo.pending} alterações aguardando envio'
                                    : repo.lastSync != null
                                    ? 'Sincronizado em ${Note.formatDate(repo.lastSync!)}'
                                    : 'Notas salvas neste dispositivo'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (repo.syncing) const LinearProgressIndicator(),
                if (reminderError != null)
                  Text(
                    reminderError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (due.isNotEmpty)
                  TextButton.icon(
                    onPressed: showReminders,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(
                      '${due.length} lembrete(s) vencido(s) — ver notas',
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Pesquisar no título ou conteúdo',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Ativas'),
                        selected: !archived,
                        onSelected: (_) => setState(() => archived = false),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Arquivadas'),
                        selected: archived,
                        onSelected: (_) => setState(() => archived = true),
                      ),
                      const SizedBox(width: 20),
                      DropdownButton<String>(
                        value: category,
                        hint: const Text('Todas as categorias'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Todas as categorias'),
                          ),
                          ...repo.categories.map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          ),
                        ],
                        onChanged: (value) => setState(() => category = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${visible.length} nota(s)',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : visible.isEmpty
                      ? Center(
                          child: Text(
                            searchController.text.isNotEmpty || category != null
                                ? 'Nenhuma nota corresponde à pesquisa.'
                                : archived
                                ? 'Nenhuma nota arquivada.'
                                : 'Suas ideias começam aqui. Crie uma nota!',
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: repo.sync,
                          child: ListView.builder(
                            itemCount: visible.length,
                            itemBuilder: (_, i) {
                              final n = visible[i];
                              return NoteCard(
                                note: n,
                                onTap: () => edit(n),
                                onDelete: () => delete(n),
                                onArchive: () =>
                                    _save(n.edit(archived: !n.archived)),
                              );
                            },
                          ),
                        ),
                ),
                if (kIsWeb)
                  const Text(
                    'No navegador, os alertas de lembrete aparecem enquanto o aplicativo está aberto.',
                    style: TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
