import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../grades/grades_screen.dart' show fmtDec;

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    if (a == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.tr('nav_analytics'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final now = DateTime.now();
    final w = a.weekly(now);
    final courses = a.currentCourses;
    final done = a.assignments.where((x) => x.status == 'completed' || x.status == 'submitted').length;
    final late = a.overdue(now).length;
    final open = a.openAssignments(now).length - late;
    final onTime = a.assignments.where((x) => x.submittedAt != null && x.dueAt != null && !x.submittedAt!.isAfter(x.dueAt!)).length;
    final submitted = a.assignments.where((x) => x.submittedAt != null && x.dueAt != null).length;
    final wk0 = weekStartOf(now, a.profile.weekStart);
    final weeks = [for (var i = 7; i >= 0; i--) DateTime(wk0.year, wk0.month, wk0.day - 7 * i)];
    final studyWeeks = [for (final s in weeks) a.studyMinutes(s, s.add(const Duration(days: 7))) / 60];
    final terms = [...a.terms]..sort((x, y) => x.position.compareTo(y.position));
    final gpaPts = <(String, double)>[
      for (final t in terms)
        if (a.termGpa(t.id).gpa != null) (t.name, a.termGpa(t.id).gpa!.toDouble()),
    ];

    Widget chartCard(String title, IconData icon, Widget chart, {double h = 200}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title, icon: icon),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            child: SizedBox(height: h, child: chart),
          ),
        ),
      ],
    );

    FlTitlesData titles(String Function(int) bottom, {double reserved = 34}) => FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: reserved)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: 1,
          getTitlesWidget: (v, _) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(bottom(v.toInt()), style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );

    String short(String s) => s.length > 8 ? '${s.substring(0, 7)}…' : s;

    final body = <Widget>[
      SectionTitle(l.tr('this_week'), icon: Icons.summarize_rounded),
      StatGrid(
        children: [
          StatTile(icon: Icons.task_alt_rounded, label: l.tr('done_this_week'), value: '${w.assignmentsDone}', color: AppColors.success),
          StatTile(icon: Icons.event_note_rounded, label: l.tr('due_this_week'), value: '${w.assignmentsDue}', color: AppColors.primary),
          StatTile(icon: Icons.quiz_rounded, label: l.tr('exams_this_week'), value: '${w.examsThisWeek}', color: AppColors.purple),
          StatTile(icon: Icons.timer_rounded, label: l.tr('study_this_week'), value: l.minutes(w.studyMinutes), color: AppColors.accent),
          StatTile(
            icon: Icons.how_to_reg_rounded,
            label: l.tr('attendance_rate'),
            value: w.attendanceRate == null ? '—' : l.pct(w.attendanceRate!),
            color: AppColors.info,
          ),
          StatTile(icon: Icons.warning_amber_rounded, label: l.tr('overdue'), value: '${w.overdue}', color: AppColors.danger),
        ],
      ),
      if (gpaPts.length >= 2)
        chartCard(
          l.tr('gpa_trend'),
          Icons.show_chart_rounded,
          LineChart(
            LineChartData(
              minY: 0,
              maxY: a.scale.maxPoints.toDouble(),
              titlesData: titles((i) => i < gpaPts.length ? short(gpaPts[i].$1) : ''),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(drawVerticalLine: false),
              lineBarsData: [
                LineChartBarData(
                  spots: [for (var i = 0; i < gpaPts.length; i++) FlSpot(i.toDouble(), gpaPts[i].$2)],
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.12)),
                ),
              ],
            ),
          ),
        ),
      if (courses.isNotEmpty)
        chartCard(
          l.tr('course_percent'),
          Icons.bar_chart_rounded,
          BarChart(
            BarChartData(
              maxY: 100,
              titlesData: titles((i) => i < courses.length ? short(courses[i].code.isNotEmpty ? courses[i].code : courses[i].name) : ''),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(drawVerticalLine: false),
              barGroups: [
                for (var i = 0; i < courses.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: a.percentOf(courses[i])?.toDouble() ?? 0,
                        color: AppColors.course(courses[i].color),
                        width: 16,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      if (courses.isNotEmpty)
        chartCard(
          l.tr('attendance_by_course'),
          Icons.how_to_reg_rounded,
          BarChart(
            BarChartData(
              maxY: 100,
              titlesData: titles((i) => i < courses.length ? short(courses[i].code.isNotEmpty ? courses[i].code : courses[i].name) : ''),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(drawVerticalLine: false),
              barGroups: [
                for (var i = 0; i < courses.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: a.attendanceOf(courses[i]).attendanceRate ?? 0,
                        color: (a.attendanceOf(courses[i]).attendanceRate ?? 100) < 75 ? AppColors.danger : AppColors.success,
                        width: 16,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      if (a.assignments.isNotEmpty)
        chartCard(
          l.tr('assignments_status'),
          Icons.pie_chart_rounded,
          Row(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 36,
                    sections: [
                      if (done > 0)
                        PieChartSectionData(
                          value: done.toDouble(),
                          color: AppColors.success,
                          title: '$done',
                          radius: 50,
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      if (open > 0)
                        PieChartSectionData(
                          value: open.toDouble(),
                          color: AppColors.primary,
                          title: '$open',
                          radius: 50,
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      if (late > 0)
                        PieChartSectionData(
                          value: late.toDouble(),
                          color: AppColors.danger,
                          title: '$late',
                          radius: 50,
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                    ],
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _legend(AppColors.success, l.tr('st_completed')),
                  _legend(AppColors.primary, l.tr('filter_open')),
                  _legend(AppColors.danger, l.tr('st_late')),
                  const SizedBox(height: 8),
                  if (submitted > 0) Text(l.tr('on_time_rate', {'n': l.pct(onTime / submitted * 100)}), style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
          h: 180,
        ),
      chartCard(
        l.tr('study_hours_8w'),
        Icons.timer_rounded,
        BarChart(
          BarChartData(
            titlesData: titles((i) => i < weeks.length ? l.dateShort(weeks[i]) : ''),
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(drawVerticalLine: false),
            barGroups: [
              for (var i = 0; i < weeks.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: double.parse(studyWeeks[i].toStringAsFixed(1)),
                      color: AppColors.accent,
                      width: 14,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      SectionTitle(l.tr('term_progress'), icon: Icons.flag_rounded),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.termCompletion == null ? l.tr('set_term_dates') : l.tr('term_passed', {'n': l.pct(a.termCompletion! * 100)})),
              const SizedBox(height: 6),
              ProgressBar(a.termCompletion ?? 0),
              const SizedBox(height: 10),
              Text('${l.tr('cumulative_gpa')}: ${fmtDec(a.cumulative.gpa)} · ${l.tr('earned_hours')}: ${l.numText(a.completedHours.toDouble())}'),
            ],
          ),
        ),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.tr('nav_analytics'))),
      body: PageList(children: body),
    );
  }

  static Widget _legend(Color c, String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(t),
      ],
    ),
  );
}
