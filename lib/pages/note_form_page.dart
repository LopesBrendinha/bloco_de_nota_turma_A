import 'package:flutter/material.dart';
import '../models/note.dart';
import '../repositories/notes_repository.dart';
import '../services/reminder_service.dart';

class NoteFormPage extends StatefulWidget {
  final Note? note;
  final NotesRepository repository;
  final ReminderService reminders;
  const NoteFormPage({
    super.key,
    this.note,
    required this.repository,
    required this.reminders,
  });
  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  late final TextEditingController title, content;
  late String category;
  DateTime? reminder;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.note?.title ?? '');
    content = TextEditingController(text: widget.note?.content ?? '');
    category = widget.note?.category ?? 'Pessoal';
    reminder = widget.note?.reminderAt?.toLocal();
  }

  Future<void> addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova categoria'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    // Dialog disposal is deferred until its closing animation has completed.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (name == null || !mounted) return;
    try {
      await widget.repository.addCategory(name);
      if (mounted) {
        setState(
          () => category = widget.repository.categories.firstWhere(
            (c) => c.toLowerCase() == name.toLowerCase(),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Não foi possível criar a categoria.');
      }
    }
  }

  Future<void> pickReminder() async {
    final now = DateTime.now();
    final initial = reminder != null && reminder!.isAfter(now)
        ? reminder!
        : now;
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    if (!selected.isAfter(DateTime.now())) {
      setState(() => error = 'Escolha uma data e um horário futuros.');
      return;
    }
    setState(() {
      reminder = selected;
      error = null;
    });
  }

  Future<void> save() async {
    if (saving) return;
    if (content.text.trim().isEmpty) {
      setState(() => error = 'Escreva o conteúdo da nota.');
      return;
    }
    if (title.text.trim().length > 200 || content.text.trim().length > 100000) {
      setState(
        () => error = 'Limite: 200 caracteres no título e 100.000 no conteúdo.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final n =
          widget.note?.edit(
            title: title.text.trim(),
            content: content.text.trim(),
            category: category,
            reminderAt: reminder?.toUtc(),
            clearReminder: reminder == null,
          ) ??
          Note(
            uid: widget.repository.uid,
            title: title.text.trim(),
            content: content.text.trim(),
            category: category,
            reminderAt: reminder?.toUtc(),
          );
      await widget.repository.save(n);
      bool permission = true;
      if (reminder != null && reminder!.isAfter(DateTime.now())) {
        try {
          permission = await widget.reminders.requestPermission();
        } catch (_) {
          permission = false;
        }
        try {
          await widget.reminders.update(widget.repository.notes);
        } catch (_) {
          permission = false;
        }
      }
      if (!mounted) return;
      if (!permission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nota salva. Ative as notificações nas configurações para receber alertas fora do aplicativo.',
            ),
          ),
        );
      }
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error =
              'Não foi possível salvar localmente. Seu texto continua aqui.';
        });
      }
    }
  }

  @override
  void dispose() {
    title.dispose();
    content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.note == null ? 'Nova nota' : 'Editar nota'),
      actions: [
        TextButton.icon(
          onPressed: saving ? null : save,
          icon: const Icon(Icons.check),
          label: Text(saving ? 'Salvando…' : 'Salvar'),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              TextField(
                controller: title,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: category,
                      key: ValueKey(category),
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: widget.repository.categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (v) => setState(() => category = v!),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Criar categoria',
                    onPressed: saving ? null : addCategory,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: saving ? null : pickReminder,
                      icon: const Icon(Icons.notification_add_outlined),
                      label: Text(
                        reminder == null
                            ? 'Definir prazo e lembrete'
                            : Note.formatDate(reminder!),
                      ),
                    ),
                  ),
                  if (reminder != null)
                    IconButton(
                      tooltip: 'Remover lembrete',
                      onPressed: () => setState(() => reminder = null),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: content,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    labelText: 'Conteúdo',
                    hintText: 'Comece a escrever…',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
