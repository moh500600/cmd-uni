import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/services/academic.dart';
import '../../../domain/services/gpa.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import 'course_detail_screen.dart';
import 'course_form_screen.dart';

class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});
  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  bool archived = false;
  String query = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('nav_courses')),
        actions: [
          IconButton(
            tooltip: l.tr(archived ? 'show_active' : 'show_archived'),
            icon: Icon(archived ? Icons.unarchive_rounded : Icons.inventory_2_outlined),
            onPressed: () => setState(() => archived = !archived),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'course_add',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CourseFormScreen())),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.tr('add_course')),
      ),
      body: a == null
          ? const Center(child: CircularProgressIndicator())
          : PageList(
              children: [
                TextField(
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.tr('search_courses')),
                  onChanged: (v) => setState(() => query = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 8),
                ..._groups(context, a),
              ],
            ),
    );
  }

  List<Widget> _groups(BuildContext context, Academic a) {
    final l = context.l;
    final list = a.courses
        .where((c) => c.archived == archived)
        .where((c) => query.isEmpty || '${c.name} ${c.code} ${c.instructor}'.toLowerCase().contains(query))
        .toList();
    if (list.isEmpty) {
      return [
        EmptyState(icon: Icons.menu_book_rounded, title: l.tr(archived ? 'no_archived' : 'no_courses'), subtitle: archived ? null : l.tr('no_courses_hint')),
      ];
    }
    final terms = [...a.terms]..sort((x, y) => y.position.compareTo(x.position));
    final out = <Widget>[];
    for (final t in [...terms, null]) {
      final cs = list.where((c) => c.termId == t?.id).toList();
      if (cs.isEmpty) continue;
      final g = a.termGpa(t?.id);
      out.add(SectionTitle(t?.name ?? l.tr('no_term'), trailing: g.gpa == null ? null : Pill('${l.tr('term_gpa')} ${roundTo(g.gpa!)}', AppColors.primary)));
      out.add(
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
            final w = (c.maxWidth - (cols - 1) * 10) / cols;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [for (final course in cs) SizedBox(width: w, child: _CourseCard(course, a))],
            );
          },
        ),
      );
    }
    return out;
  }
}

class _CourseCard extends StatelessWidget {
  final Course c;
  final Academic a;
  const _CourseCard(this.c, this.a);
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final color = AppColors.course(c.color);
    final pct = a.percentOf(c);
    final g = a.gradedOf(c);
    final att = a.attendanceOf(c);
    final open = a.openAssignments(DateTime.now()).where((x) => x.courseId == c.id).length;
    return Card(
      key: Key('course_${c.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailScreen(courseId: c.id))),
        child: Container(
          decoration: BoxDecoration(
            border: BorderDirectional(start: BorderSide(color: color, width: 5)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (c.code.isNotEmpty) Pill(c.code, color),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (c.instructor.isNotEmpty) c.instructor,
                  l.tr('n_credit_hours', {'n': c.creditHours.toString()}),
                ].join(' · '),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Pill(
                    pct == null ? l.tr('no_grades_yet') : '${roundTo(pct)}%${g == null ? '' : ' · ${g.band.letter}'}',
                    AppColors.primary,
                    icon: Icons.grade_rounded,
                  ),
                  if (att.attendanceRate != null) Pill('${att.attendanceRate!.round()}%', AppColors.success, icon: Icons.fact_check_rounded),
                  if (open > 0) Pill('$open', AppColors.accent, icon: Icons.assignment_rounded),
                  if (c.status != 'ongoing') Pill(l.tr('cs_${c.status}'), Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
