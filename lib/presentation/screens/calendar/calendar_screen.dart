import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time.dart';
import '../../../domain/services/academic.dart';
import '../../providers/providers.dart';
import '../../widgets/agenda_tile.dart';
import '../../widgets/common.dart';
import '../assignments/assignment_form_screen.dart';
import '../exams/exam_form_screen.dart';
import '../study/study_screen.dart';
import 'event_form_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime focused = DateTime.now();
  DateTime selected = dayOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    final settings = ref.watch(settingsProvider);
    final view = settings.calendarView;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('nav_calendar')),
        actions: [
          IconButton(
            tooltip: l.tr('today'),
            icon: const Icon(Icons.today_rounded),
            onPressed: () => setState(() {
              focused = DateTime.now();
              selected = dayOnly(DateTime.now());
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(heroTag: 'cal_add', onPressed: () => _quickAdd(context, a), child: const Icon(Icons.add_rounded)),
      body: a == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 0, label: Text(l.tr('month'))),
                      ButtonSegment(value: 1, label: Text(l.tr('week'))),
                      ButtonSegment(value: 2, label: Text(l.tr('day'))),
                    ],
                    selected: {view},
                    onSelectionChanged: (v) => ref.read(settingsProvider.notifier).update(settings.copyWith(calendarView: v.first)),
                  ),
                ),
                Expanded(
                  child: switch (view) {
                    2 => _dayView(context, a),
                    _ => _monthOrWeek(context, a, view == 1),
                  },
                ),
              ],
            ),
    );
  }

  StartingDayOfWeek _startDay(int iso) => StartingDayOfWeek.values[(iso - 1).clamp(0, 6)];

  Widget _monthOrWeek(BuildContext context, Academic a, bool week) {
    final l = context.l;
    final items = a.agendaOn(selected);
    final cal = TableCalendar<AgendaItem>(
      locale: l.lang,
      firstDay: DateTime(2015),
      lastDay: DateTime(2040),
      focusedDay: focused,
      calendarFormat: week ? CalendarFormat.week : CalendarFormat.month,
      availableCalendarFormats: const {CalendarFormat.month: '', CalendarFormat.week: ''},
      headerStyle: HeaderStyle(formatButtonVisible: false, titleCentered: true, titleTextFormatter: (d, _) => l.month(d)),
      startingDayOfWeek: _startDay(a.profile.weekStart),
      selectedDayPredicate: (d) => isSameDay(d, selected),
      eventLoader: (d) => a.agendaOn(d).where((i) => i.kind != 'lecture').toList(),
      onDaySelected: (s, f) => setState(() {
        selected = dayOnly(s);
        focused = f;
      }),
      onPageChanged: (f) => focused = f,
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.25), shape: BoxShape.circle),
        selectedDecoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        markersMaxCount: 4,
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, events) => events.isEmpty
            ? null
            : Positioned(
                bottom: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final e in events.take(4))
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(color: AppColors.kind(e.kind), shape: BoxShape.circle),
                      ),
                  ],
                ),
              ),
      ),
    );
    final list = [
      SectionTitle('${l.weekday(selected)} ${l.date(selected)}'),
      if (items.isEmpty) EmptyState(icon: Icons.event_busy_rounded, title: l.tr('nothing_this_day')),
      for (final it in items) AgendaTile(it, a),
    ];
    if (context.isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Card(
                child: Padding(padding: const EdgeInsets.all(8), child: cal),
              ),
            ),
          ),
          Expanded(flex: 2, child: PageList(children: list)),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
      children: [
        Card(
          child: Padding(padding: const EdgeInsets.all(4), child: cal),
        ),
        ...list,
      ],
    );
  }

  Widget _dayView(BuildContext context, Academic a) {
    final l = context.l;
    final items = a.agendaOn(selected);
    final timed = items.where((i) => !i.allDay).toList();
    final allDay = items.where((i) => i.allDay).toList();
    const hourH = 56.0;
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => setState(() => selected = DateTime(selected.year, selected.month, selected.day - 1)),
            ),
            Expanded(
              child: Text(
                '${l.weekday(selected)} ${l.date(selected)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => setState(() => selected = DateTime(selected.year, selected.month, selected.day + 1)),
            ),
          ],
        ),
        for (final it in allDay) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: AgendaTile(it, a)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 96),
            child: SizedBox(
              height: 24 * hourH,
              child: LayoutBuilder(
                builder: (context, c) => Stack(
                  children: [
                    for (var h = 0; h < 24; h++)
                      PositionedDirectional(
                        top: h * hourH,
                        start: 0,
                        end: 0,
                        child: Row(
                          children: [
                            SizedBox(width: 44, child: Text(hhmm(h * 60), style: const TextStyle(fontSize: 11))),
                            Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                          ],
                        ),
                      ),
                    for (final it in timed)
                      PositionedDirectional(
                        top: minutesOf(it.start) / 60 * hourH,
                        start: 48,
                        end: 4,
                        height: (((it.end ?? it.start.add(const Duration(minutes: 30))).difference(it.start).inMinutes) / 60 * hourH).clamp(26, 24 * hourH),
                        child: Material(
                          color: AppColors.kind(it.kind).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: () => openAgendaItem(context, it),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                '${l.time(it.start)} · ${it.title}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _quickAdd(BuildContext context, Academic? a) async {
    final l = context.l;
    if (a == null) return;
    final at = DateTime(selected.year, selected.month, selected.day, 9);
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) {
        Widget t(IconData i, String k, Widget page) => ListTile(
          leading: Icon(i),
          title: Text(l.tr(k)),
          onTap: () {
            Navigator.pop(c);
            Navigator.push(context, MaterialPageRoute(builder: (_) => page));
          },
        );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              t(Icons.event_rounded, 'add_event', EventFormScreen(initial: at)),
              t(Icons.assignment_rounded, 'add_assignment', AssignmentFormScreen(prefill: {'due_at': at.toIso8601String()})),
              t(Icons.quiz_rounded, 'add_exam', ExamFormScreen(prefill: {'starts_at': at.toIso8601String()})),
              ListTile(
                leading: const Icon(Icons.menu_book_rounded),
                title: Text(l.tr('add_study')),
                onTap: () {
                  Navigator.pop(c);
                  editStudySession(context, ref, a, null, selected);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
