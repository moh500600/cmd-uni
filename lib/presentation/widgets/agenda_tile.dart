import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/services/academic.dart';
import '../screens/assignments/assignment_detail_screen.dart';
import '../screens/calendar/event_form_screen.dart';
import '../screens/courses/course_detail_screen.dart';
import '../screens/exams/exam_detail_screen.dart';
import '../screens/projects/project_detail_screen.dart';
import '../screens/study/study_screen.dart';

IconData kindIcon(String kind) => switch (kind) {
  'lecture' => Icons.co_present_rounded,
  'exam' => Icons.quiz_rounded,
  'assignment' => Icons.assignment_rounded,
  'project' => Icons.account_tree_rounded,
  'study' => Icons.menu_book_rounded,
  _ => Icons.event_rounded,
};

void openAgendaItem(BuildContext context, AgendaItem it) {
  final Widget page = switch (it.kind) {
    'lecture' => CourseDetailScreen(courseId: it.courseId!),
    'exam' => ExamDetailScreen(examId: it.refId),
    'assignment' => AssignmentDetailScreen(assignmentId: it.refId),
    'project' => ProjectDetailScreen(projectId: it.refId),
    'study' => const StudyScreen(),
    _ => EventFormScreen(eventId: it.refId),
  };
  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

class AgendaTile extends StatelessWidget {
  final AgendaItem item;
  final Academic a;
  const AgendaTile(this.item, this.a, {super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final c = a.course(item.courseId);
    final color = c != null && item.kind == 'lecture' ? AppColors.course(c.color) : AppColors.kind(item.kind);
    final time = item.allDay ? l.tr('all_day') : (item.end == null ? l.time(item.start) : '${l.time(item.start)} – ${l.time(item.end!)}');
    final sub = [
      l.tr('kind_${item.kind}'),
      if (item.kind != 'lecture' && c != null) c.name,
      if (item.subtitle.isNotEmpty) item.subtitle == 'online' ? l.tr('mode_online') : item.subtitle,
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => openAgendaItem(context, item),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
          child: Icon(kindIcon(item.kind), color: color),
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w700, decoration: item.done ? TextDecoration.lineThrough : null),
        ),
        subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(time, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
  }
}
