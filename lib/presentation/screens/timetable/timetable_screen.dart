import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/services/academic.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import 'session_form_screen.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});
  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  bool weekView = true;
  int day = DateTime.now().weekday;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('nav_timetable')),
        actions: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: true, label: Text(l.tr('week')), icon: const Icon(Icons.view_week_rounded, size: 18)),
              ButtonSegment(value: false, label: Text(l.tr('day')), icon: const Icon(Icons.view_day_rounded, size: 18)),
            ],
            selected: {weekView},
            onSelectionChanged: (v) => setState(() => weekView = v.first),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'session_add',
        onPressed: a == null || a.activeCourses.isEmpty
            ? () => toast(context, l.tr('add_course_first'))
            : () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionFormScreen(weekday: weekView ? null : day))),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.tr('add_session')),
      ),
      body: a == null ? const Center(child: CircularProgressIndicator()) : (weekView ? _week(context, a) : _day(context, a)),
    );
  }

  List<int> _weekdays(Academic a) {
    final start = a.profile.weekStart;
    return [for (var i = 0; i < 7; i++) ((start - 1 + i) % 7) + 1];
  }

  List<ClassSession> _active(Academic a) =>
      a.sessions.where((s) => (a.course(s.courseId)?.archived ?? true) == false && a.course(s.courseId)?.status != 'withdrawn').toList();

  Widget _week(BuildContext context, Academic a) {
    final l = context.l;
    final sessions = _active(a);
    if (sessions.isEmpty) return EmptyState(icon: Icons.view_week_rounded, title: l.tr('no_sessions'), subtitle: l.tr('no_sessions_hint'));
    final conflictIds = {
      for (final p in a.timetableConflicts) ...[p.$1.id, p.$2.id],
    };
    var days = _weekdays(a);
    if (!context.isWide) days = days.where((d) => sessions.any((s) => s.weekday == d)).toList();
    final startH = (sessions.map((s) => s.startMin).reduce((x, y) => x < y ? x : y) ~/ 60);
    final endH = ((sessions.map((s) => s.endMin).reduce((x, y) => x > y ? x : y) + 59) ~/ 60).clamp(startH + 1, 24);
    const hourH = 64.0;
    const axisW = 46.0;
    return LayoutBuilder(
      builder: (context, c) {
        final colW = ((c.maxWidth - axisW - 16) / days.length).clamp(96.0, 260.0);
        final gridW = axisW + colW * days.length;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: gridW,
              child: Column(
                children: [
                  if (conflictIds.isNotEmpty)
                    Container(
                      width: gridW,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        l.tr('conflicts_found', {'n': '${a.timetableConflicts.length}'}),
                        style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
                      ),
                    ),
                  Row(
                    children: [
                      const SizedBox(width: axisW),
                      for (final d in days)
                        SizedBox(
                          width: colW,
                          child: Center(
                            child: Text(
                              l.weekdayName(d),
                              style: TextStyle(fontWeight: FontWeight.w800, color: d == DateTime.now().weekday ? Theme.of(context).colorScheme.primary : null),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: (endH - startH) * hourH,
                    child: Stack(
                      children: [
                        for (var h = startH; h <= endH; h++)
                          PositionedDirectional(
                            top: (h - startH) * hourH,
                            start: 0,
                            end: 0,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: axisW,
                                  child: Text(hhmm(h * 60), style: const TextStyle(fontSize: 11)),
                                ),
                                Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                              ],
                            ),
                          ),
                        for (var i = 0; i < days.length; i++)
                          for (final s in sessions.where((s) => s.weekday == days[i]))
                            PositionedDirectional(
                              start: axisW + i * colW + 2,
                              width: colW - 4,
                              top: (s.startMin - startH * 60) / 60 * hourH,
                              height: ((s.endMin - s.startMin) / 60 * hourH).clamp(28, 2000),
                              child: _Block(s, a.course(s.courseId)!, conflict: conflictIds.contains(s.id)),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _day(BuildContext context, Academic a) {
    final l = context.l;
    final conflictIds = {
      for (final p in a.timetableConflicts) ...[p.$1.id, p.$2.id],
    };
    final ss = _active(a).where((s) => s.weekday == day).toList()..sort((x, y) => x.startMin.compareTo(y.startMin));
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final d in _weekdays(a))
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: ChoiceChip(label: Text(l.weekdayName(d)), selected: d == day, onSelected: (_) => setState(() => day = d)),
                ),
            ],
          ),
        ),
        Expanded(
          child: PageList(
            children: [
              if (ss.isEmpty) EmptyState(icon: Icons.weekend_rounded, title: l.tr('no_lectures_day')),
              for (final s in ss)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(height: 92, child: _Block(s, a.course(s.courseId)!, conflict: conflictIds.contains(s.id), wide: true)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  final ClassSession s;
  final Course c;
  final bool conflict;
  final bool wide;
  const _Block(this.s, this.c, {this.conflict = false, this.wide = false});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final color = AppColors.course(c.color);
    return Material(
      color: color.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: conflict ? AppColors.danger : color, width: conflict ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionFormScreen(sessionId: s.id))),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (conflict)
                    const Padding(
                      padding: EdgeInsetsDirectional.only(end: 4),
                      child: Icon(Icons.warning_rounded, size: 14, color: AppColors.danger),
                    ),
                  Expanded(
                    child: Text(
                      c.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              Flexible(
                child: Text(
                  [
                    '${hhmm(s.startMin)}–${hhmm(s.endMin)}',
                    if (s.room.isNotEmpty) s.room,
                    if (s.online) l.tr('mode_online'),
                    if (wide) l.tr('sk_${s.kind}'),
                    if (wide && s.instructor.isNotEmpty) s.instructor,
                  ].join(' · '),
                  maxLines: wide ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
