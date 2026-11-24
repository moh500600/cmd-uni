import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/services/pomodoro.dart';
import '../../domain/services/reminders.dart';

/// Device-level preferences (language, theme, reminders, timer). Academic
/// settings (GPA system, scale, absence rules) live in the synced profile.
class AppSettings {
  final String lang;
  final ThemeMode theme;
  final ReminderPrefs reminders;
  final PomodoroConfig pomodoro;
  final bool syncOnCellular;
  final int calendarView; // 0 month, 1 week, 2 day
  const AppSettings({
    this.lang = 'ar',
    this.theme = ThemeMode.system,
    this.reminders = const ReminderPrefs(),
    this.pomodoro = const PomodoroConfig(),
    this.syncOnCellular = true,
    this.calendarView = 0,
  });

  AppSettings copyWith({String? lang, ThemeMode? theme, ReminderPrefs? reminders, PomodoroConfig? pomodoro, int? calendarView}) => AppSettings(
    lang: lang ?? this.lang,
    theme: theme ?? this.theme,
    reminders: reminders ?? this.reminders,
    pomodoro: pomodoro ?? this.pomodoro,
    calendarView: calendarView ?? this.calendarView,
  );
}

class SettingsRepository {
  final SharedPreferences prefs;
  SettingsRepository(this.prefs);

  AppSettings load() {
    final r = _map('reminders');
    final p = _map('pomodoro');
    return AppSettings(
      lang: prefs.getString('lang') ?? 'ar',
      theme: ThemeMode.values[(prefs.getInt('theme') ?? 0).clamp(0, 2)],
      calendarView: prefs.getInt('calendar_view') ?? 0,
      reminders: ReminderPrefs(
        lectures: r['lectures'] as bool? ?? true,
        assignments: r['assignments'] as bool? ?? true,
        exams: r['exams'] as bool? ?? true,
        projects: r['projects'] as bool? ?? true,
        study: r['study'] as bool? ?? true,
        events: r['events'] as bool? ?? true,
        dailySummary: r['daily'] as bool? ?? true,
        weeklySummary: r['weekly'] as bool? ?? true,
        lectureLeadMin: r['lectureLead'] as int? ?? 15,
        assignmentLeadMin: r['assignmentLead'] as int? ?? 1440,
        examLeadMin: r['examLead'] as int? ?? 1440,
        projectLeadMin: r['projectLead'] as int? ?? 1440,
        dailyAtMin: r['dailyAt'] as int? ?? 420,
      ),
      pomodoro: PomodoroConfig(
        focusMin: p['focus'] as int? ?? 25,
        shortBreakMin: p['short'] as int? ?? 5,
        longBreakMin: p['long'] as int? ?? 15,
        longEvery: p['every'] as int? ?? 4,
      ),
    );
  }

  Map<String, dynamic> _map(String k) {
    try {
      return Map<String, dynamic>.from(jsonDecode(prefs.getString(k) ?? '{}') as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> save(AppSettings s) async {
    await prefs.setString('lang', s.lang);
    await prefs.setInt('theme', s.theme.index);
    await prefs.setInt('calendar_view', s.calendarView);
    final r = s.reminders;
    await prefs.setString(
      'reminders',
      jsonEncode({
        'lectures': r.lectures,
        'assignments': r.assignments,
        'exams': r.exams,
        'projects': r.projects,
        'study': r.study,
        'events': r.events,
        'daily': r.dailySummary,
        'weekly': r.weeklySummary,
        'lectureLead': r.lectureLeadMin,
        'assignmentLead': r.assignmentLeadMin,
        'examLead': r.examLeadMin,
        'projectLead': r.projectLeadMin,
        'dailyAt': r.dailyAtMin,
      }),
    );
    final p = s.pomodoro;
    await prefs.setString('pomodoro', jsonEncode({'focus': p.focusMin, 'short': p.shortBreakMin, 'long': p.longBreakMin, 'every': p.longEvery}));
  }
}
