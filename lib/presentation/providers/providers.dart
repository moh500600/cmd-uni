import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/l10n/l10n.dart';
import '../../data/db/local_store.dart';
import '../../data/repositories/uni_repository.dart';
import '../../data/services/export_service.dart';
import '../../data/services/local_session.dart';
import '../../data/services/file_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/settings_repository.dart';
import '../../domain/entities/entities.dart';
import '../../domain/services/academic.dart';
import '../../domain/services/reminders.dart';

// ------------------------------------------------------------------ roots (overridden in main)
final databaseProvider = Provider<Database>((ref) => throw UnimplementedError('databaseProvider'));
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('prefsProvider'));
final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());

/// Bumped on every local write, so the data below reloads.
class Revision extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final revisionProvider = NotifierProvider<Revision, int>(Revision.new);

final storeProvider = Provider<LocalStore>((ref) {
  final store = LocalStore(ref.watch(databaseProvider));
  store.onChange = (_) {
    ref.read(revisionProvider.notifier).bump();
  };
  return store;
});

// ------------------------------------------------------------------ settings
class SettingsNotifier extends Notifier<AppSettings> {
  late SettingsRepository _repo;
  @override
  AppSettings build() {
    _repo = SettingsRepository(ref.watch(prefsProvider));
    return _repo.load();
  }

  Future<void> update(AppSettings s) async {
    state = s;
    await _repo.save(s);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// ------------------------------------------------------------------ session
class SessionNotifier extends Notifier<AppSession?> {
  @override
  AppSession? build() => const AppSession(kLocalUid);
}

final sessionProvider = NotifierProvider<SessionNotifier, AppSession?>(SessionNotifier.new);

// ------------------------------------------------------------------ data
final repoProvider = Provider<UniRepository?>((ref) {
  final s = ref.watch(sessionProvider);
  return s == null ? null : UniRepository(ref.watch(storeProvider), s.uid);
});

/// Everything the student has (reloaded after every write or sync).
final academicProvider = FutureProvider<Academic>((ref) async {
  ref.watch(revisionProvider);
  final repo = ref.watch(repoProvider);
  if (repo == null) return Academic(uid: '', profile: Profile.empty(''));
  return repo.load();
});

final fileServiceProvider = Provider<FileService?>((ref) {
  final repo = ref.watch(repoProvider);
  return repo == null ? null : FileService(repo);
});

final exportServiceProvider = Provider<ExportService?>((ref) {
  final repo = ref.watch(repoProvider);
  return repo == null ? null : ExportService(repo);
});

// ------------------------------------------------------------------ reminders
/// Re-plans every OS reminder from the current data (called after changes).
Future<void> rescheduleReminders(WidgetRef ref, Academic a) async {
  final s = ref.read(settingsProvider);
  final l = L10n(s.lang);
  final plan = planReminders(a, s.reminders, DateTime.now(), l.tr);
  await ref.read(notificationServiceProvider).reschedule([
    for (final p in plan)
      ScheduledAlert(
        p.id,
        p.when,
        p.title,
        p.body,
        repeat: switch (p.repeat) {
          Repeat.daily => DateTimeComponents.time,
          Repeat.weekly => DateTimeComponents.dayOfWeekAndTime,
          Repeat.none => null,
        },
      ),
  ]);
}

/// Shows an AppException-aware error message.
String errorText(BuildContext context, Object e) {
  final s = e.toString();
  final key = s.contains(':') ? s.substring(0, s.indexOf(':')) : s;
  final t = context.tr(key);
  return t == key ? s : (s.contains(':') ? '$t (${s.substring(s.indexOf(':') + 1).trim()})' : t);
}
