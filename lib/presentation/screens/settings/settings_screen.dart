import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/platform/desktop_files.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/services/reminders.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../grades/gpa_settings_screen.dart';
import 'demo_data.dart';
import 'terms_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final s = ref.watch(settingsProvider);
    final a = ref.watch(academicProvider).value;
    Widget nav(IconData i, String k, Widget page, {String? sub}) => ListTile(
      leading: Icon(i),
      title: Text(l.tr(k)),
      subtitle: sub == null ? null : Text(sub),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.tr('nav_settings'))),
      body: PageList(
        children: [
          SectionTitle(l.tr('appearance'), icon: Icons.palette_rounded),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.tr('language')),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    key: const Key('lang'),
                    segments: const [
                      ButtonSegment(value: 'ar', label: Text('العربية')),
                      ButtonSegment(value: 'en', label: Text('English')),
                    ],
                    selected: {s.lang},
                    onSelectionChanged: (v) => ref.read(settingsProvider.notifier).update(s.copyWith(lang: v.first)),
                  ),
                  const SizedBox(height: 12),
                  Text(l.tr('theme')),
                  const SizedBox(height: 6),
                  SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(value: ThemeMode.system, label: Text(l.tr('theme_system'))),
                      ButtonSegment(value: ThemeMode.light, label: Text(l.tr('theme_light'))),
                      ButtonSegment(value: ThemeMode.dark, label: Text(l.tr('theme_dark'))),
                    ],
                    selected: {s.theme},
                    onSelectionChanged: (v) => ref.read(settingsProvider.notifier).update(s.copyWith(theme: v.first)),
                  ),
                ],
              ),
            ),
          ),
          SectionTitle(l.tr('academic_setup'), icon: Icons.school_rounded),
          Card(
            child: Column(
              children: [
                nav(Icons.date_range_rounded, 'terms', const TermsScreen(), sub: a?.currentTerm?.name),
                nav(Icons.rule_rounded, 'gpa_settings', const GpaSettingsScreen(), sub: a == null ? null : l.tr('sys_${a.profile.gpaSystem}')),
                nav(Icons.how_to_reg_rounded, 'attendance_rules', const AttendanceRulesScreen()),
                nav(Icons.notifications_active_rounded, 'notifications', const NotificationSettingsScreen()),
              ],
            ),
          ),
          SectionTitle(l.tr('backup_export'), icon: Icons.save_alt_rounded),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup_rounded),
                  title: Text(l.tr('backup_json')),
                  subtitle: Text(l.tr('backup_json_sub')),
                  onTap: () => _export(context, ref, (e) => e.backupJson()),
                ),
                ListTile(leading: const Icon(Icons.restore_rounded), title: Text(l.tr('restore_json')), onTap: () => _restore(context, ref)),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_rounded),
                  title: Text(l.tr('transcript_pdf')),
                  onTap: () => a == null ? null : _export(context, ref, (e) => e.transcriptPdf(a, arabic: l.lang == 'ar', tr: l.tr)),
                ),
                ListTile(
                  leading: const Icon(Icons.table_chart_rounded),
                  title: Text(l.tr('grades_csv')),
                  onTap: () => a == null ? null : _export(context, ref, (e) => e.gradesCsv(a)),
                ),
                ListTile(
                  leading: const Icon(Icons.table_view_rounded),
                  title: Text(l.tr('assignments_csv')),
                  onTap: () => a == null ? null : _export(context, ref, (e) => e.assignmentsCsv(a)),
                ),
                ListTile(
                  leading: const Icon(Icons.fact_check_rounded),
                  title: Text(l.tr('attendance_csv')),
                  onTap: () => a == null ? null : _export(context, ref, (e) => e.attendanceCsv(a)),
                ),
              ],
            ),
          ),
          SectionTitle(l.tr('demo'), icon: Icons.science_rounded),
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome_motion_rounded),
              title: Text(l.tr('load_demo')),
              subtitle: Text(l.tr('load_demo_sub')),
              onTap: () async {
                final repo = ref.read(repoProvider);
                if (repo == null || !await confirm(context, l.tr('load_demo_confirm'))) return;
                await loadDemoData(repo, l.lang == 'ar');
                if (context.mounted) toast(context, l.tr('demo_loaded'));
              },
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('${l.tr('app_name')} · 1.0.0', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref, Future<dynamic> Function(dynamic e) f) async {
    final e = ref.read(exportServiceProvider);
    if (e == null) return;
    try {
      final file = await f(e);
      if (context.mounted) await shareOrSaveFile(context, file);
    } catch (err) {
      if (context.mounted) toast(context, errorText(context, err));
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l = context.l;
    final fs = ref.read(fileServiceProvider), ex = ref.read(exportServiceProvider);
    if (fs == null || ex == null) return;
    final f = await fs.pick(extensions: ['json']);
    if (f == null || !context.mounted) return;
    if (!await confirm(context, l.tr('restore_confirm'))) return;
    try {
      final n = await ex.restoreJson(utf8.decode(await f.readAsBytes()));
      if (context.mounted) toast(context, l.tr('restored_n', {'n': '$n'}));
    } catch (e) {
      if (context.mounted) toast(context, errorText(context, e));
    }
  }
}

class AttendanceRulesScreen extends ConsumerStatefulWidget {
  const AttendanceRulesScreen({super.key});
  @override
  ConsumerState<AttendanceRulesScreen> createState() => _AttendanceRulesScreenState();
}

class _AttendanceRulesScreenState extends ConsumerState<AttendanceRulesScreen> {
  final pct = TextEditingController(), late = TextEditingController();
  int weekStart = 6;
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    if (!_loaded && a != null) {
      _loaded = true;
      pct.text = a.profile.absenceLimitPct.toString();
      late.text = '${a.profile.latePerAbsence}';
      weekStart = a.profile.weekStart;
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.tr('attendance_rules'))),
      body: PageList(
        children: [
          Text(l.tr('attendance_rules_hint'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Field(pct, l.tr('absence_limit_pct'), keyboard: const TextInputType.numberWithOptions(decimal: true)),
          Field(late, l.tr('late_per_absence'), keyboard: TextInputType.number, hint: l.tr('late_per_absence_hint')),
          Pick<int>(
            label: l.tr('week_start'),
            value: weekStart,
            items: [
              for (final d in [6, 7, 1]) (d, l.weekdayName(d)),
            ],
            onChanged: (v) => setState(() => weekStart = v ?? weekStart),
          ),
          FilledButton(
            onPressed: () async {
              final p = parseNum(pct.text), lt = int.tryParse(normalizeDigits(late.text.trim()));
              if (p == null || p <= 0 || p > 100 || lt == null || lt < 0 || lt > 20) return toast(context, l.tr('v_number'));
              await ref.read(repoProvider)!.save('profiles', {
                'id': a!.uid,
                'absence_limit_pct': normalizeDigits(pct.text.trim()),
                'late_per_absence': lt,
                'week_start': weekStart,
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(l.tr('save')),
          ),
        ],
      ),
    );
  }
}

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final s = ref.watch(settingsProvider);
    final r = s.reminders;
    void put(ReminderPrefs n) => ref.read(settingsProvider.notifier).update(s.copyWith(reminders: n));
    ReminderPrefs copy({
      bool? lectures,
      bool? assignments,
      bool? exams,
      bool? projects,
      bool? study,
      bool? events,
      bool? daily,
      bool? weekly,
      int? lectureLead,
      int? assignmentLead,
      int? examLead,
      int? projectLead,
      int? dailyAt,
    }) => ReminderPrefs(
      lectures: lectures ?? r.lectures,
      assignments: assignments ?? r.assignments,
      exams: exams ?? r.exams,
      projects: projects ?? r.projects,
      study: study ?? r.study,
      events: events ?? r.events,
      dailySummary: daily ?? r.dailySummary,
      weeklySummary: weekly ?? r.weeklySummary,
      lectureLeadMin: lectureLead ?? r.lectureLeadMin,
      assignmentLeadMin: assignmentLead ?? r.assignmentLeadMin,
      examLeadMin: examLead ?? r.examLeadMin,
      projectLeadMin: projectLead ?? r.projectLeadMin,
      dailyAtMin: dailyAt ?? r.dailyAtMin,
    );
    Widget lead(int value, List<int> options, ValueChanged<int> on) => DropdownButton<int>(
      value: options.contains(value) ? value : options.first,
      underline: const SizedBox.shrink(),
      items: [
        for (final o in options)
          DropdownMenuItem(
            value: o,
            child: Text(o >= 1440 ? l.tr('n_days', {'n': '${o ~/ 1440}'}) : (o >= 60 ? l.tr('n_hours', {'n': '${o ~/ 60}'}) : l.minutes(o))),
          ),
      ],
      onChanged: (v) => v == null ? null : on(v),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.tr('notifications'))),
      body: PageList(
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_rounded),
              title: Text(l.tr('allow_notifications')),
              subtitle: Text(l.tr('allow_notifications_sub')),
              trailing: FilledButton.tonal(
                onPressed: () async {
                  final ok = await ref.read(notificationServiceProvider).requestPermissions();
                  if (context.mounted) toast(context, l.tr(ok ? 'notifications_on' : 'notifications_denied'));
                },
                child: Text(l.tr('allow')),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: r.lectures,
                  onChanged: (v) => put(copy(lectures: v)),
                  title: Text(l.tr('rem_lectures')),
                  secondary: lead(r.lectureLeadMin, [5, 10, 15, 30, 60], (v) => put(copy(lectureLead: v))),
                ),
                SwitchListTile(
                  value: r.assignments,
                  onChanged: (v) => put(copy(assignments: v)),
                  title: Text(l.tr('rem_assignments')),
                  secondary: lead(r.assignmentLeadMin, [60, 180, 720, 1440, 2880, 4320], (v) => put(copy(assignmentLead: v))),
                ),
                SwitchListTile(
                  value: r.exams,
                  onChanged: (v) => put(copy(exams: v)),
                  title: Text(l.tr('rem_exams')),
                  secondary: lead(r.examLeadMin, [60, 180, 720, 1440, 2880, 4320, 10080], (v) => put(copy(examLead: v))),
                ),
                SwitchListTile(
                  value: r.projects,
                  onChanged: (v) => put(copy(projects: v)),
                  title: Text(l.tr('rem_projects')),
                  secondary: lead(r.projectLeadMin, [1440, 2880, 4320, 10080], (v) => put(copy(projectLead: v))),
                ),
                SwitchListTile(
                  value: r.study,
                  onChanged: (v) => put(copy(study: v)),
                  title: Text(l.tr('rem_study_sessions')),
                ),
                SwitchListTile(
                  value: r.events,
                  onChanged: (v) => put(copy(events: v)),
                  title: Text(l.tr('rem_events')),
                ),
                SwitchListTile(
                  value: r.dailySummary,
                  onChanged: (v) => put(copy(daily: v)),
                  title: Text(l.tr('rem_daily')),
                ),
                SwitchListTile(
                  value: r.weeklySummary,
                  onChanged: (v) => put(copy(weekly: v)),
                  title: Text(l.tr('rem_weekly')),
                ),
                ListTile(
                  title: Text(l.tr('daily_summary_time')),
                  trailing: TimeField(
                    label: '',
                    minutes: r.dailyAtMin,
                    onChanged: (v) => put(copy(dailyAt: v ?? r.dailyAtMin)),
                    compact: true,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(l.tr('notifications_note'), style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
