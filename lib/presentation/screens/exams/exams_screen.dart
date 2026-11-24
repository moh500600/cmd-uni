import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/services/academic.dart';
import '../../../domain/services/conflicts.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import 'exam_detail_screen.dart';
import 'exam_form_screen.dart';

class ExamsScreen extends StatelessWidget {
  const ExamsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.tr('nav_exams'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'exam_add',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamFormScreen())),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.tr('add_exam')),
      ),
      body: const ExamList(),
    );
  }
}

class ExamList extends ConsumerStatefulWidget {
  final String? courseId;
  const ExamList({super.key, this.courseId});
  @override
  ConsumerState<ExamList> createState() => _ExamListState();
}

class _ExamListState extends ConsumerState<ExamList> {
  bool past = false;
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    if (a == null) return const Center(child: CircularProgressIndicator());
    final now = DateTime.now();
    final all = a.exams.where((e) => widget.courseId == null || e.courseId == widget.courseId).toList();
    final upcoming = a.upcomingExams(now).where((e) => widget.courseId == null || e.courseId == widget.courseId).toList();
    final list = past ? (all.where((e) => !upcoming.contains(e)).toList()..sort((x, y) => (y.startsAt ?? now).compareTo(x.startsAt ?? now))) : upcoming;
    final clashes = findTimeClashes<Exam>(upcoming, (e) => e.startsAt!, (e) => e.startsAt!.add(Duration(minutes: e.durationMin)));
    return PageList(
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l.tr('upcoming'))),
            ButtonSegment(value: true, label: Text(l.tr('past'))),
          ],
          selected: {past},
          onSelectionChanged: (v) => setState(() => past = v.first),
        ),
        const SizedBox(height: 10),
        if (!past && clashes.isNotEmpty)
          Card(
            color: AppColors.danger.withValues(alpha: 0.08),
            child: ListTile(
              leading: const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              title: Text(l.tr('exam_clash')),
              subtitle: Text(clashes.map((p) => '${p.$1.title} ↔ ${p.$2.title}').join('\n')),
            ),
          ),
        if (list.isEmpty) EmptyState(icon: Icons.quiz_rounded, title: l.tr(past ? 'no_past_exams' : 'no_exams')),
        for (final e in list) ExamTile(e, a),
        if (widget.courseId != null)
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamFormScreen(courseId: widget.courseId))),
            icon: const Icon(Icons.add_rounded),
            label: Text(l.tr('add_exam')),
          ),
      ],
    );
  }
}

class ExamTile extends StatelessWidget {
  final Exam e;
  final Academic a;
  const ExamTile(this.e, this.a, {super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final now = DateTime.now();
    final c = a.course(e.courseId);
    final cd = e.startsAt == null ? null : Countdown.between(now, e.startsAt!);
    final prep = ExamPrep.of(e, now);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamDetailScreen(examId: e.id))),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: AppColors.purple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: cd == null || cd.past
              ? Icon(e.finished ? Icons.task_alt_rounded : Icons.quiz_rounded, color: AppColors.purple)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${cd.days}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.purple),
                    ),
                    Text(l.tr('days_short'), style: const TextStyle(fontSize: 10, color: AppColors.purple)),
                  ],
                ),
        ),
        title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [l.tr('ek_${e.kind}'), courseName(context, c), if (e.startsAt != null) l.dateTime(e.startsAt!), if (e.location.isNotEmpty) e.location].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: e.finished
            ? Pill('${e.score}/${e.maxGrade ?? '—'}', AppColors.success)
            : (e.topics.isEmpty ? null : Ring(value: prep.readiness, label: l.pct(prep.readiness * 100), color: AppColors.purple, size: 42)),
      ),
    );
  }
}
