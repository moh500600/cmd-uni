import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/services/academic.dart';
import '../../../domain/services/pomodoro.dart';
import '../../../domain/services/study_planner.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

class StudyScreen extends StatelessWidget {
  const StudyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.tr('nav_study')),
          bottom: TabBar(
            tabs: [
              Tab(text: l.tr('study_plan')),
              Tab(text: l.tr('pomodoro')),
              Tab(text: l.tr('study_stats')),
            ],
          ),
        ),
        body: const TabBarView(children: [_Plan(), PomodoroPanel(), _Stats()]),
      ),
    );
  }
}

class _Plan extends ConsumerStatefulWidget {
  const _Plan();
  @override
  ConsumerState<_Plan> createState() => _PlanState();
}

class _PlanState extends ConsumerState<_Plan> {
  bool week = true;
  DateTime anchor = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    if (a == null) return const Center(child: CircularProgressIndicator());
    final start = week ? weekStartOf(anchor, a.profile.weekStart) : dayOnly(anchor);
    final days = week ? 7 : 1;
    final repo = ref.read(repoProvider)!;
    return Stack(
      children: [
        PageList(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => setState(() => anchor = anchor.subtract(Duration(days: days))),
                ),
                Expanded(
                  child: Text(
                    week ? '${l.dateShort(start)} – ${l.dateShort(start.add(const Duration(days: 6)))}' : l.date(start),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => setState(() => anchor = anchor.add(Duration(days: days))),
                ),
              ],
            ),
            Row(
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(l.tr('daily'))),
                    ButtonSegment(value: true, label: Text(l.tr('weekly'))),
                  ],
                  selected: {week},
                  onSelectionChanged: (v) => setState(() => week = v.first),
                ),
                const Spacer(),
                TextButton.icon(onPressed: () => _smartPlan(context, a), icon: const Icon(Icons.auto_fix_high_rounded), label: Text(l.tr('smart_plan'))),
              ],
            ),
            for (var i = 0; i < days; i++)
              ...() {
                final d = DateTime(start.year, start.month, start.day + i);
                final ss = a.study.where((s) => dayOnly(s.plannedOn) == d).toList()..sort((x, y) => (x.startMin ?? 0).compareTo(y.startMin ?? 0));
                final planned = ss.fold(0, (n, s) => n + s.plannedMin), actual = ss.fold(0, (n, s) => n + s.actualMin);
                return [
                  SectionTitle(
                    '${l.weekday(d)} ${l.dateShort(d)}',
                    trailing: Text('${l.minutes(actual)} / ${l.minutes(planned)}', style: const TextStyle(fontSize: 12)),
                  ),
                  if (ss.isEmpty) Text(l.tr('no_study_day'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  for (final s in ss)
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        leading: Checkbox(
                          value: s.done,
                          onChanged: (v) =>
                              repo.save('study_sessions', {'id': s.id, 'done': v ?? false, if (v == true && s.actualMin == 0) 'actual_min': s.plannedMin}),
                        ),
                        title: Text(s.title.isEmpty ? courseName(context, a.course(s.courseId)) : s.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          [
                            if (s.title.isNotEmpty && a.course(s.courseId) != null) a.course(s.courseId)!.name,
                            if (s.startMin != null) hhmm(s.startMin!),
                            l.minutes(s.plannedMin),
                            '${l.tr('difficulty')}: ${l.tr('diff_${s.difficulty}')}',
                            if (s.source == 'pomodoro') '🍅',
                          ].join(' · '),
                        ),
                        trailing: Text(l.minutes(s.actualMin), style: const TextStyle(fontWeight: FontWeight.w700)),
                        onTap: () => editStudySession(context, ref, a, s, d),
                      ),
                    ),
                ];
              }(),
          ],
        ),
        PositionedDirectional(
          end: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'study_add',
            onPressed: () => editStudySession(context, ref, a, null, week ? dayOnly(DateTime.now()) : start),
            icon: const Icon(Icons.add_rounded),
            label: Text(l.tr('add_study')),
          ),
        ),
      ],
    );
  }

  Future<void> _smartPlan(BuildContext context, Academic a) async {
    final l = context.l;
    final plan = suggestExamPlan(a, DateTime.now());
    if (plan.isEmpty) return toast(context, l.tr('smart_plan_empty'));
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.tr('smart_plan')),
        content: SizedBox(
          width: 420,
          height: 360,
          child: ListView(
            children: [
              Text(l.tr('smart_plan_intro')),
              const SizedBox(height: 8),
              for (final p in plan)
                ListTile(
                  dense: true,
                  title: Text(p.title),
                  subtitle: Text('${l.weekday(p.day)} ${l.dateShort(p.day)} · ${a.course(p.courseId)?.name ?? ''} · ${l.minutes(p.minutes)}'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.tr('add_all', {'n': '${plan.length}'}))),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(repoProvider)!;
    for (final p in plan) {
      await repo.save('study_sessions', {
        'course_id': p.courseId,
        'title': p.title,
        'planned_on': dateKey(p.day),
        'planned_min': p.minutes,
        'difficulty': p.difficulty,
      });
    }
    if (context.mounted) toast(context, l.tr('saved'));
  }
}

Future<void> editStudySession(BuildContext context, WidgetRef ref, Academic a, StudySession? s, DateTime day) async {
  final l = context.l;
  final title = TextEditingController(text: s?.title ?? '');
  final planned = TextEditingController(text: '${s?.plannedMin ?? 60}');
  final actual = TextEditingController(text: '${s?.actualMin ?? 0}');
  String? courseId = s?.courseId, unitId = s?.unitId;
  DateTime? on = s?.plannedOn ?? day;
  int? start = s?.startMin;
  var diff = s?.difficulty ?? 2;
  final r = await showDialog<String>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) {
        final units = a.units.where((u) => u.courseId == courseId).toList();
        return AlertDialog(
          title: Text(l.tr(s == null ? 'add_study' : 'edit_study')),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Pick<String>(
                    label: l.tr('course'),
                    value: courseId,
                    allowNone: true,
                    items: [for (final x in a.activeCourses) (x.id, x.name)],
                    onChanged: (v) => set(() {
                      courseId = v;
                      unitId = null;
                    }),
                  ),
                  if (units.isNotEmpty)
                    Pick<String>(
                      label: l.tr('unit'),
                      value: unitId,
                      allowNone: true,
                      items: [for (final u in units) (u.id, u.title)],
                      onChanged: (v) => set(() {
                        unitId = v;
                        if (title.text.isEmpty) title.text = units.firstWhere((u) => u.id == v).title;
                      }),
                    ),
                  TextField(
                    controller: title,
                    decoration: InputDecoration(labelText: l.tr('study_topic')),
                  ),
                  const SizedBox(height: 12),
                  DateTimeField(label: l.tr('date'), value: on, clearable: false, onChanged: (v) => set(() => on = v)),
                  TimeField(label: l.tr('start_time'), minutes: start, onChanged: (v) => set(() => start = v)),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: planned,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: l.tr('planned_min')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: actual,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: l.tr('actual_min')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      for (final d in [1, 2, 3]) ButtonSegment(value: d, label: Text(l.tr('diff_$d'))),
                    ],
                    selected: {diff},
                    onSelectionChanged: (v) => set(() => diff = v.first),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (s != null)
              TextButton(
                onPressed: () => Navigator.pop(c, 'delete'),
                child: Text(l.tr('delete'), style: const TextStyle(color: AppColors.danger)),
              ),
            TextButton(onPressed: () => Navigator.pop(c), child: Text(l.tr('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: Text(l.tr('save'))),
          ],
        );
      },
    ),
  );
  final repo = ref.read(repoProvider)!;
  if (r == 'delete' && s != null) await repo.delete('study_sessions', s.id);
  if (r == 'save') {
    final p = int.tryParse(normalizeDigits(planned.text.trim())) ?? 0, ac = int.tryParse(normalizeDigits(actual.text.trim())) ?? 0;
    if (p < 0 || p > 1440 || ac < 0 || ac > 1440) {
      if (context.mounted) toast(context, l.tr('v_number'));
      return;
    }
    await repo.save('study_sessions', {
      'id': s?.id,
      'course_id': courseId,
      'unit_id': unitId,
      'title': title.text.trim(),
      'planned_on': dateKey(on ?? day),
      'start_min': start,
      'planned_min': p,
      'actual_min': ac,
      'difficulty': diff,
      'done': ac > 0 && ac >= p,
    });
  }
}

/// Pomodoro timer; every finished focus block is logged as study time.
class PomodoroPanel extends ConsumerStatefulWidget {
  const PomodoroPanel({super.key});
  @override
  ConsumerState<PomodoroPanel> createState() => _PomodoroPanelState();
}

class _PomodoroPanelState extends ConsumerState<PomodoroPanel> {
  late PomodoroMachine m;
  late PomodoroState st;
  Timer? _t;
  String? courseId;
  DateTime _last = DateTime.now();

  @override
  void initState() {
    super.initState();
    m = PomodoroMachine(ref.read(settingsProvider).pomodoro);
    st = PomodoroState.initial(m.config);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (st.running) {
      _t?.cancel();
      setState(() => st = st.copyWith(running: false));
      return;
    }
    _last = DateTime.now();
    setState(() => st = st.copyWith(running: true));
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _tick() async {
    final now = DateTime.now();
    final secs = now.difference(_last).inSeconds;
    if (secs <= 0) return;
    _last = _last.add(Duration(seconds: secs));
    final before = st.phase;
    final (next, focusMin) = m.tick(st, secs);
    setState(() => st = next);
    if (focusMin > 0) await _log(focusMin);
    if (before != next.phase && mounted) {
      final l = context.l;
      toast(context, l.tr(next.phase == PomoPhase.focus ? 'pomo_back_focus' : 'pomo_break_time'));
      await ref.read(notificationServiceProvider).showNow(4242, l.tr('pomodoro'), l.tr(next.phase == PomoPhase.focus ? 'pomo_back_focus' : 'pomo_break_time'));
    }
  }

  Future<void> _log(int minutes) async {
    final repo = ref.read(repoProvider);
    final a = ref.read(academicProvider).value;
    if (repo == null || a == null) return;
    final today = dayOnly(DateTime.now());
    final existing = a.study.where((s) => s.source == 'pomodoro' && dayOnly(s.plannedOn) == today && s.courseId == courseId).firstOrNull;
    await repo.save('study_sessions', {
      'id': existing?.id,
      'course_id': courseId,
      'title': existing?.title ?? context.tr('pomodoro'),
      'planned_on': dateKey(today),
      'planned_min': (existing?.plannedMin ?? 0) + minutes,
      'actual_min': (existing?.actualMin ?? 0) + minutes,
      'done': true,
      'source': 'pomodoro',
    });
  }

  Future<void> _settings() async {
    final l = context.l;
    final s = ref.read(settingsProvider);
    final f = TextEditingController(text: '${s.pomodoro.focusMin}'), sb = TextEditingController(text: '${s.pomodoro.shortBreakMin}');
    final lb = TextEditingController(text: '${s.pomodoro.longBreakMin}'), ev = TextEditingController(text: '${s.pomodoro.longEvery}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.tr('pomo_settings')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (ctl, k) in [(f, 'pomo_focus'), (sb, 'pomo_short'), (lb, 'pomo_long'), (ev, 'pomo_every')])
              TextField(
                controller: ctl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.tr(k)),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.tr('save'))),
        ],
      ),
    );
    if (ok != true) return;
    int n(TextEditingController c) => int.tryParse(normalizeDigits(c.text.trim())) ?? 0;
    final cfg = PomodoroConfig(focusMin: n(f), shortBreakMin: n(sb), longBreakMin: n(lb), longEvery: n(ev));
    final err = cfg.validate();
    if (err != null) {
      if (mounted) toast(context, l.tr(err));
      return;
    }
    await ref.read(settingsProvider.notifier).update(s.copyWith(pomodoro: cfg));
    _t?.cancel();
    setState(() {
      m = PomodoroMachine(cfg);
      st = PomodoroState.initial(cfg);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    final total = m.config.minutesOf(st.phase) * 60;
    final color = st.phase == PomoPhase.focus ? AppColors.danger : AppColors.success;
    final mm = (st.remainingSec ~/ 60).toString().padLeft(2, '0'), ss = (st.remainingSec % 60).toString().padLeft(2, '0');
    final todayMin = a?.study.where((s) => s.source == 'pomodoro' && dayOnly(s.plannedOn) == dayOnly(DateTime.now())).fold(0, (n, s) => n + s.actualMin) ?? 0;
    return PageList(
      children: [
        Pick<String>(
          label: l.tr('studying_course'),
          value: courseId,
          allowNone: true,
          items: [for (final c in a?.activeCourses ?? <Course>[]) (c.id, c.name)],
          onChanged: (v) => setState(() => courseId = v),
        ),
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CircularProgressIndicator(
                    value: 1 - st.remainingSec / total,
                    strokeWidth: 12,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.12),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$mm:$ss',
                      style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                    Text(
                      l.tr('phase_${st.phase.name}'),
                      style: TextStyle(color: color, fontWeight: FontWeight.w800),
                    ),
                    Text(l.tr('pomo_count', {'n': '${st.completedFocus}'})),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              tooltip: l.tr('reset'),
              onPressed: () {
                _t?.cancel();
                setState(() => st = PomodoroState.initial(m.config));
              },
              icon: const Icon(Icons.restart_alt_rounded),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              key: const Key('pomo_toggle'),
              style: FilledButton.styleFrom(backgroundColor: color, minimumSize: const Size(160, 56)),
              onPressed: _toggle,
              icon: Icon(st.running ? Icons.pause_rounded : Icons.play_arrow_rounded),
              label: Text(l.tr(st.running ? 'pause' : 'start')),
            ),
            const SizedBox(width: 16),
            IconButton.filledTonal(tooltip: l.tr('skip'), onPressed: () => setState(() => st = m.next(st)), icon: const Icon(Icons.skip_next_rounded)),
          ],
        ),
        const SizedBox(height: 16),
        Center(child: Text(l.tr('pomo_today', {'m': l.minutes(todayMin)}))),
        Center(
          child: TextButton.icon(
            onPressed: _settings,
            icon: const Icon(Icons.tune_rounded),
            label: Text('${m.config.focusMin} / ${m.config.shortBreakMin} / ${m.config.longBreakMin} · ${l.tr('pomo_settings')}'),
          ),
        ),
      ],
    );
  }
}

class _Stats extends ConsumerWidget {
  const _Stats();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    if (a == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final wk = weekStartOf(now, a.profile.weekStart);
    final weekMin = a.studyMinutes(wk, wk.add(const Duration(days: 7)));
    final adherence = a.studyAdherence(wk, wk.add(const Duration(days: 7)));
    final days = [for (var i = 0; i < 7; i++) DateTime(wk.year, wk.month, wk.day + i)];
    final perDay = [for (final d in days) a.studyMinutes(d, d.add(const Duration(days: 1)))];
    final perCourse = <String, int>{};
    for (final s in a.study) {
      if (s.plannedOn.isBefore(now.subtract(const Duration(days: 30)))) continue;
      final k = a.course(s.courseId)?.name ?? l.tr('general');
      perCourse[k] = (perCourse[k] ?? 0) + s.actualMin;
    }
    final maxY = perDay.fold(60, (m, v) => v > m ? v : m).toDouble();
    return PageList(
      children: [
        StatGrid(
          children: [
            StatTile(icon: Icons.timer_rounded, label: l.tr('study_this_week'), value: l.minutes(weekMin), color: AppColors.success),
            StatTile(
              icon: Icons.task_alt_rounded,
              label: l.tr('plan_adherence'),
              value: adherence == null ? '—' : l.pct(adherence * 100),
              color: AppColors.primary,
            ),
            StatTile(
              icon: Icons.local_fire_department_rounded,
              label: l.tr('study_streak'),
              value: l.tr('n_days', {'n': '${a.studyStreak}'}),
              color: AppColors.accent,
            ),
            StatTile(
              icon: Icons.history_rounded,
              label: l.tr('study_total'),
              value: l.minutes(a.study.fold(0, (n, s) => n + s.actualMin)),
              color: AppColors.info,
            ),
          ],
        ),
        SectionTitle(l.tr('study_by_day'), icon: Icons.bar_chart_rounded),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            child: SizedBox(
              height: 190,
              child: BarChart(
                BarChartData(
                  maxY: maxY * 1.15,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) => Text(l.weekdayShort(days[v.toInt()]), style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (g, _, r, _) => BarTooltipItem(l.minutes(r.toY.round()), const TextStyle(color: Colors.white)),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < 7; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [BarChartRodData(toY: perDay[i].toDouble(), color: AppColors.success, width: 16, borderRadius: BorderRadius.circular(5))],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SectionTitle(l.tr('study_by_course_30'), icon: Icons.pie_chart_rounded),
        if (perCourse.isEmpty) Text(l.tr('no_study_yet')),
        for (final e in perCourse.entries.toList()..sort((x, y) => y.value.compareTo(x.value)))
          ListTile(
            dense: true,
            title: Text(e.key),
            trailing: Text(l.minutes(e.value), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}
