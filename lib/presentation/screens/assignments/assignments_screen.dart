import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/services/academic.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import 'assignment_detail_screen.dart';
import 'assignment_form_screen.dart';

class AssignmentsScreen extends StatelessWidget {
  const AssignmentsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.tr('nav_assignments'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'asg_add',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssignmentFormScreen())),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.tr('add_assignment')),
      ),
      body: const AssignmentList(),
    );
  }
}

/// Assignments with status filters; [courseId] limits it to one course.
class AssignmentList extends ConsumerStatefulWidget {
  final String? courseId;
  const AssignmentList({super.key, this.courseId});
  @override
  ConsumerState<AssignmentList> createState() => _AssignmentListState();
}

class _AssignmentListState extends ConsumerState<AssignmentList> {
  String filter = 'open';

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    if (a == null) return const Center(child: CircularProgressIndicator());
    final now = DateTime.now();
    var list = a.assignments.where((x) => widget.courseId == null || x.courseId == widget.courseId).toList();
    list = switch (filter) {
      'open' => list.where((x) => isOpenAssignment(effectiveStatus(x, now))).toList(),
      'late' => list.where((x) => effectiveStatus(x, now) == 'late').toList(),
      'done' => list.where((x) => x.status == 'completed' || x.status == 'submitted').toList(),
      _ => list,
    };
    list.sort((x, y) {
      if (filter == 'done') return (y.submittedAt ?? y.updatedAt ?? now).compareTo(x.submittedAt ?? x.updatedAt ?? now);
      final p = (x.dueAt ?? DateTime(9999)).compareTo(y.dueAt ?? DateTime(9999));
      return p != 0 ? p : y.priority.compareTo(x.priority);
    });
    return PageList(
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final f in ['open', 'late', 'done', 'all'])
              ChoiceChip(label: Text(l.tr('filter_$f')), selected: filter == f, onSelected: (_) => setState(() => filter = f)),
          ],
        ),
        const SizedBox(height: 10),
        if (list.isEmpty) EmptyState(icon: Icons.assignment_turned_in_rounded, title: l.tr('no_assignments')),
        for (final x in list) AssignmentTile(x, a),
        if (widget.courseId != null)
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AssignmentFormScreen(courseId: widget.courseId))),
            icon: const Icon(Icons.add_rounded),
            label: Text(l.tr('add_assignment')),
          ),
      ],
    );
  }
}

class AssignmentTile extends ConsumerWidget {
  final Assignment x;
  final Academic a;
  const AssignmentTile(this.x, this.a, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final now = DateTime.now();
    final st = effectiveStatus(x, now);
    final progress = a.progressOf(x);
    final c = a.course(x.courseId);
    final due = x.dueAt;
    String dueText = '';
    if (due != null) {
      final cd = Countdown.between(now, due);
      dueText = cd.past ? l.dateTime(due) : (cd.days > 0 ? l.tr('in_days', {'n': '${cd.days}'}) : l.tr('in_hours', {'h': '${cd.hours}', 'm': '${cd.minutes}'}));
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AssignmentDetailScreen(assignmentId: x.id))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: x.status == 'completed' || x.status == 'submitted',
                    onChanged: (v) => ref.read(repoProvider)!.setAssignmentStatus(x, v == true ? 'completed' : 'in_progress'),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(x.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        Row(
                          children: [
                            CourseDot(c),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                [courseName(context, c), if (dueText.isNotEmpty) dueText].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, color: st == 'late' ? AppColors.danger : Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Pill(l.tr('st_$st'), AppColors.status(st)),
                      const SizedBox(height: 4),
                      if (x.priority >= 2) Pill(l.tr('prio_${x.priority}'), x.priority == 3 ? AppColors.danger : AppColors.warning, icon: Icons.flag_rounded),
                    ],
                  ),
                ],
              ),
              if (progress > 0 && progress < 100) Padding(padding: const EdgeInsetsDirectional.only(start: 48, top: 4), child: ProgressBar(progress / 100)),
            ],
          ),
        ),
      ),
    );
  }
}
