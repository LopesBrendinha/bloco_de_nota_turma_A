import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../database/database_helper.dart';
import '../models/note.dart';

class ReminderService {
  final DatabaseHelper local;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final Map<int, String> _scheduled = {};
  Future<void> _queue = Future.value();
  bool _initialized = false;
  bool _stopped = false;
  ReminderService(this.local);
  bool get native =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  Future<void> _initialize() async {
    if (_initialized || !native) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_note'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    // On a new session, discard alarms left by a previous process/account.
    // The current account's future reminders are restored by update().
    await _plugin.cancelAll();
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (!native) return true;
    await _initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  /// Serializes rescheduling so an old refresh cannot revive a cancelled alarm.
  Future<void> update(List<Note> notes) {
    final snapshot = List<Note>.of(notes);
    final task = _queue.then((_) async {
      if (_stopped || !native) return;
      await _initialize();
      final future = snapshot
          .where(
            (n) =>
                !n.archived &&
                !n.deleted &&
                n.reminderAt != null &&
                n.reminderAt!.isAfter(DateTime.now()) &&
                n.id != null,
          )
          .toList();
      final ids = future.map((n) => n.id!).toSet();
      for (final id in _scheduled.keys.toList()) {
        if (!ids.contains(id)) {
          await _plugin.cancel(id: id);
          _scheduled.remove(id);
        }
      }
      for (final note in future) {
        if (_stopped) return;
        final key =
            '${note.revision}:${note.reminderAt!.millisecondsSinceEpoch}';
        if (_scheduled[note.id] == key) continue;
        await _plugin.zonedSchedule(
          id: note.id!,
          title: note.title.isEmpty ? 'Lembrete de nota' : note.title,
          body: 'Abra seu Bloco de Notas para consultar a tarefa.',
          scheduledDate: tz.TZDateTime.from(note.reminderAt!, tz.UTC),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'note_reminders',
              'Lembretes de notas',
              channelDescription: 'Prazos definidos nas suas notas',
              importance: Importance.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: note.cloudId,
        );
        _scheduled[note.id!] = key;
      }
    });
    _queue = task.catchError((Object _) {});
    return task;
  }

  Future<List<Note>> due(List<Note> notes) async {
    final result = <Note>[];
    for (final n in notes) {
      if (!n.archived &&
          !n.deleted &&
          n.reminderAt != null &&
          !n.reminderAt!.isAfter(DateTime.now()) &&
          !await local.reminderDelivered(n)) {
        result.add(n);
      }
    }
    return result;
  }

  Future<void> dismiss(Note n) => local.markReminderDelivered(n);
  Future<void> stop() async {
    _stopped = true;
    await _queue;
    if (_initialized) await _plugin.cancelAll();
    _scheduled.clear();
  }
}
