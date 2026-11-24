import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/services/academic.dart';
import '../../../domain/services/gpa.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../courses/course_detail_screen.dart';
import 'gpa_settings_screen.dart';

String fmtDec(Decimal? d, [int scale = 2]) => d == null ? '—' : roundTo(d, scale).toString();

class GradesScreen extends ConsumerWidget {
  const GradesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.tr('nav_grades')),
          actions: [
            IconButton(
              tooltip: l.tr('gpa_settings'),
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GpaSettingsScreen())),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l.tr('current_term')),
              Tab(text: l.tr('transcript')),
              Tab(text: l.tr('gpa_planner')),
            ],
          ),
        ),
        body: a == null ? const Center(child: CircularProgressIndicator()) : TabBarView(children: [_Current(a), _Transcript(a), _Planner(a)]),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final Academic a;
  const _Summary(this.a);
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final cum = a.cumulative;
    final term = a.termGpa(a.currentTerm?.id);
    final max = a.scale.maxPoints;
    return StatGrid(
      children: [
        StatTile(icon: Icons.workspace_premium_rounded, label: '${l.tr('cumulative_gpa')} / $max', value: fmtDec(cum.gpa), color: const Color(0xFFB45309)),
        StatTile(icon: Icons.trending_up_rounded, label: l.tr('term_gpa'), value: fmtDec(term.gpa), color: AppColors.primary),
        StatTile(icon: Icons.hourglass_bottom_rounded, label: l.tr('earned_hours'), value: l.numText(cum.earnedHours.toDouble()), color: AppColors.success),
        StatTile(icon: Icons.rule_rounded, label: l.tr('gpa_system'), value: l.tr('sys_${a.profile.gpaSystem}'), color: AppColors.info),
      ],
    );
  }
}

class _Current extends StatelessWidget {
  final Academic a;
  const _Current(this.a);
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final courses = a.currentCourses;
    return PageList(
      children: [
        _Summary(a),
        SectionTitle(l.tr('courses_results'), icon: Icons.list_alt_rounded),
        if (courses.isEmpty) EmptyState(icon: Icons.menu_book_rounded, title: l.tr('no_courses')),
        for (final c in courses) CourseResultTile(c, a),
      ],
    );
  }
}

class CourseResultTile extends StatelessWidget {
  final Course c;
  final Academic a;
  const CourseResultTile(this.c, this.a, {super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = a.totalOf(c.id);
    final pct = a.percentOf(c);
    final g = a.gradedOf(c);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: Text(c.name),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailScreen(courseId: c.id))),
                  ),
                ],
              ),
              body: CourseGradeBook(courseId: c.id),
            ),
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.course(c.color).withValues(alpha: 0.15),
          child: Text(
            g?.band.letter ?? '—',
            style: TextStyle(color: AppColors.course(c.color), fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [
            l.tr('n_credit_hours', {'n': c.creditHours.toString()}),
            if (!t.isEmpty && c.finalPercent == null) l.tr('graded_of', {'n': fmtDec(t.possible, 1)}),
            if (c.finalPercent != null) l.tr('final_entered'),
          ].join(' · '),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(pct == null ? '—' : '${fmtDec(pct)}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            if (g != null && !a.scale.isPercentage) Text('${g.points} ${l.tr('points')}', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _Transcript extends StatelessWidget {
  final Academic a;
  const _Transcript(this.a);
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final terms = [...a.terms]..sort((x, y) => x.position.compareTo(y.position));
    final points = <(String, double)>[];
    for (final t in terms) {
      final g = a.termGpa(t.id).gpa;
      if (g != null) points.add((t.name, g.toDouble()));
    }
    return PageList(
      children: [
        _Summary(a),
        if (a.profile.priorHours > Decimal.zero)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l.tr('prior_record_line', {'h': a.profile.priorHours.toString(), 'g': fmtDec(a.profile.priorGpa)})),
          ),
        if (points.length >= 2) ...[
          SectionTitle(l.tr('terms_comparison'), icon: Icons.bar_chart_rounded),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              child: SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    maxY: a.scale.maxPoints.toDouble(),
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (v, m) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(points[v.toInt()].$1, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < points.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [BarChartRodData(toY: points[i].$2, width: 18, color: AppColors.primary, borderRadius: BorderRadius.circular(6))],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        for (final t in [...terms, null])
          ...() {
            final cs = a.courses.where((c) => c.termId == t?.id && c.status != 'withdrawn').toList();
            if (cs.isEmpty) return <Widget>[];
            final s = a.termGpa(t?.id);
            return [
              SectionTitle(
                t?.name ?? l.tr('no_term'),
                trailing: Pill('${l.tr('term_gpa')}: ${fmtDec(s.gpa)} · ${l.numText(s.hours.toDouble())} ${l.tr('hours_short')}', AppColors.primary),
              ),
              for (final c in cs) CourseResultTile(c, a),
            ];
          }(),
      ],
    );
  }
}

class _Planner extends StatefulWidget {
  final Academic a;
  const _Planner(this.a);
  @override
  State<_Planner> createState() => _PlannerState();
}

class _PlannerState extends State<_Planner> {
  final target = TextEditingController(), hours = TextEditingController(text: '15');
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = widget.a;
    final cum = a.cumulative;
    final t = parseNum(target.text), h = parseNum(hours.text);
    Decimal? needed;
    if (t != null && h != null && h > 0) {
      needed = a.calc.neededTermGpa(current: cum, nextHours: dec(h), target: dec(t));
    }
    final max = a.scale.maxPoints;
    return PageList(
      children: [
        Text(l.tr('planner_intro'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Text(
          '${l.tr('cumulative_gpa')}: ${fmtDec(cum.gpa)} · ${l.numText(cum.hours.toDouble())} ${l.tr('hours_short')}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: target,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l.tr('target_gpa')),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: hours,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l.tr('next_hours')),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (needed != null)
          Card(
            color: (needed > max ? AppColors.danger : AppColors.success).withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                needed > max
                    ? l.tr('target_unreachable', {'n': fmtDec(needed)})
                    : (needed <= Decimal.zero ? l.tr('target_secured') : l.tr('target_needed', {'n': fmtDec(needed), 'h': hours.text})),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        SectionTitle(l.tr('grade_scale'), icon: Icons.table_rows_rounded),
        Card(
          child: Column(
            children: [
              for (final b in a.scale.bands)
                ListTile(
                  dense: true,
                  title: Text(b.letter, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('≥ ${b.min}%'),
                  trailing: a.scale.isPercentage ? null : Text('${b.points}'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The grade book of one course: items, total, letter and what's needed.
class CourseGradeBook extends ConsumerWidget {
  final String courseId;
  const CourseGradeBook({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    final c = a?.course(courseId);
    if (a == null || c == null) return const SizedBox.shrink();
    final items = a.gradesOf(courseId);
    final t = a.totalOf(courseId);
    final g = a.gradedOf(c);
    final allWeighted = items.isNotEmpty && items.every((i) => i.weight != null);
    final remaining = (allWeighted ? Decimal.fromInt(100) - t.possible : Decimal.fromInt(100) - t.possible);
    return PageList(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Ring(value: (a.percentOf(c)?.toDouble() ?? 0) / 100, label: g?.band.letter ?? '—', color: AppColors.primary, size: 70),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l.tr('course_total')}: ${a.percentOf(c) == null ? '—' : '${fmtDec(a.percentOf(c))}%'}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      if (!t.isEmpty) Text(l.tr('earned_of', {'e': fmtDec(t.earned), 'p': fmtDec(t.possible)})),
                      if (g != null && !a.scale.isPercentage) Text('${l.tr('points')}: ${g.points}'),
                      if (c.finalPercent != null) Text(l.tr('final_entered'), style: const TextStyle(color: AppColors.accent)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!t.isEmpty && remaining > Decimal.zero) _Needed(t, remaining, a),
        SectionTitle(
          l.tr('grade_items'),
          icon: Icons.list_rounded,
          trailing: IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: l.tr('add_grade'),
            onPressed: () => editGradeItem(context, ref, courseId, null),
          ),
        ),
        if (items.isEmpty) EmptyState(icon: Icons.grade_rounded, title: l.tr('no_grades_yet'), subtitle: l.tr('grades_hint')),
        for (final i in items)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              title: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                [l.tr('gc_${i.category}'), if (i.weight != null) '${l.tr('weight')} ${i.weight}%', if (i.gradedOn != null) l.date(i.gradedOn!)].join(' · '),
              ),
              trailing: Text('${i.score} / ${i.maxScore}', style: const TextStyle(fontWeight: FontWeight.w800)),
              onTap: () => editGradeItem(context, ref, courseId, i),
            ),
          ),
      ],
    );
  }
}

class _Needed extends StatefulWidget {
  final CourseTotal t;
  final Decimal remaining;
  final Academic a;
  const _Needed(this.t, this.remaining, this.a);
  @override
  State<_Needed> createState() => _NeededState();
}

class _NeededState extends State<_Needed> {
  late GradeBand band = widget.a.scale.bands.firstWhere((b) => b.passing, orElse: () => widget.a.scale.bands.first);
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final need = widget.t.neededOnRest(band.min, widget.remaining);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(l.tr('what_needed', {'r': fmtDec(widget.remaining, 1)}))),
                DropdownButton<GradeBand>(
                  value: band,
                  items: [for (final b in widget.a.scale.bands) DropdownMenuItem(value: b, child: Text(b.letter))],
                  onChanged: (v) => setState(() => band = v ?? band),
                ),
              ],
            ),
            if (need != null)
              Text(
                need > Decimal.fromInt(100)
                    ? l.tr('needed_impossible')
                    : (need <= Decimal.zero ? l.tr('needed_secured') : l.tr('needed_pct', {'n': fmtDec(need, 1)})),
                style: TextStyle(fontWeight: FontWeight.w800, color: need > Decimal.fromInt(100) ? AppColors.danger : AppColors.success),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> editGradeItem(BuildContext context, WidgetRef ref, String courseId, GradeItem? i) async {
  final l = context.l;
  final title = TextEditingController(text: i?.title ?? '');
  final score = TextEditingController(text: i?.score.toString() ?? '');
  final max = TextEditingController(text: i?.maxScore.toString() ?? '');
  final weight = TextEditingController(text: i?.weight?.toString() ?? '');
  var cat = i?.category ?? 'quiz';
  DateTime? on = i?.gradedOn ?? DateTime.now();
  final key = GlobalKey<FormState>();
  final r = await showDialog<String>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: Text(l.tr(i == null ? 'add_grade' : 'edit_grade')),
        content: SizedBox(
          width: 420,
          child: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Field(title, l.tr('title'), validator: V.required),
                  Pick<String>(
                    label: l.tr('category'),
                    value: cat,
                    items: [for (final g in kGradeCategories) (g, l.tr('gc_$g'))],
                    onChanged: (v) => set(() => cat = v ?? cat),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Field(
                          score,
                          l.tr('score'),
                          keyboard: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => V.number(v, required: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Field(
                          max,
                          l.tr('out_of'),
                          keyboard: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => V.number(v, required: true, positive: true),
                        ),
                      ),
                    ],
                  ),
                  Field(
                    weight,
                    l.tr('weight_pct_optional'),
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                    hint: l.tr('weight_hint'),
                    validator: (v) => V.number(v, max: 100),
                  ),
                  DateTimeField(label: l.tr('date'), value: on, onChanged: (v) => set(() => on = v)),
                ],
              ),
            ),
          ),
        ),
        actions: [
          if (i != null)
            TextButton(
              onPressed: () => Navigator.pop(c, 'delete'),
              child: Text(l.tr('delete'), style: const TextStyle(color: AppColors.danger)),
            ),
          TextButton(onPressed: () => Navigator.pop(c), child: Text(l.tr('cancel'))),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(c, 'save');
            },
            child: Text(l.tr('save')),
          ),
        ],
      ),
    ),
  );
  final repo = ref.read(repoProvider)!;
  try {
    if (r == 'delete' && i != null) await repo.delete('grade_items', i.id);
    if (r == 'save') {
      await repo.save('grade_items', {
        'id': i?.id,
        'course_id': courseId,
        'title': title.text.trim(),
        'category': cat,
        'score': normalizeDigits(score.text.trim()),
        'max_score': normalizeDigits(max.text.trim()),
        'weight': weight.text.trim().isEmpty ? null : normalizeDigits(weight.text.trim()),
        'graded_on': on == null ? null : dateKey(on!),
      });
    }
  } catch (e) {
    if (context.mounted) toast(context, errorText(context, e));
  }
}
