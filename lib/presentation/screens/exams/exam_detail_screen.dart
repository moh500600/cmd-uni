import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/services/academic.dart';
import '../../providers/providers.dart';
import '../../widgets/attachments.dart';
import '../../widgets/common.dart';
import '../notes/notes_screen.dart';
import 'exam_form_screen.dart';

class ExamDetailScreen extends ConsumerStatefulWidget {
  final String examId;
  const ExamDetailScreen({super.key, required this.examId});
  @override
  ConsumerState<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends ConsumerState<ExamDetailScreen> {
  Timer? _tick;
  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    final e = a?.exams.where((e) => e.id == widget.examId).firstOrNull;
    if (a == null || e == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.tr('not_found'))),
      );
    }
    final repo = ref.read(repoProvider)!;
    final now = DateTime.now();
    final cd = e.startsAt == null ? null : Countdown.between(now, e.startsAt!);
    final prep = ExamPrep.of(e, now);
    final c = a.course(e.courseId);
    final units = a.units.where((u) => u.courseId == e.courseId && !u.done).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('ek_${e.kind}')),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamFormScreen(examId: e.id))),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              if (await confirm(context, l.tr('delete_confirm'))) {
                await repo.delete('exams', e.id, log: e.title);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: PageList(
        children: [
          Text(e.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(
            [
              courseName(context, c),
              if (e.startsAt != null) l.dateTime(e.startsAt!),
              l.minutes(e.durationMin),
              if (e.location.isNotEmpty) e.location,
            ].join(' · '),
          ),
          const SizedBox(height: 12),
          if (cd != null)
            Card(
              color: AppColors.purple.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: cd.past
                    ? Text(l.tr('exam_done'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [_cd(context, cd.days, l.tr('days')), _cd(context, cd.hours, l.tr('hours')), _cd(context, cd.minutes, l.tr('minutes'))],
                      ),
              ),
            ),
          SectionTitle(l.tr('prep_mode'), icon: Icons.self_improvement_rounded),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Ring(value: prep.readiness, label: l.pct(prep.readiness * 100), color: AppColors.purple, size: 72),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.tr('days_left', {'n': '${prep.daysLeft < 0 ? 0 : prep.daysLeft}'}),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        Text(l.tr('topics_left', {'n': '${prep.topicsLeft}', 'total': '${prep.topicsTotal}'})),
                        if (prep.topicsPerDay > 0)
                          Text(
                            l.tr('topics_per_day', {'n': '${prep.topicsPerDay}'}),
                            style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (e.topics.isEmpty) Text(l.tr('topics_hint')),
          for (var i = 0; i < e.topics.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: CheckboxListTile(
                value: e.topics[i].done,
                title: Text(e.topics[i].title, style: TextStyle(decoration: e.topics[i].done ? TextDecoration.lineThrough : null)),
                onChanged: (v) {
                  final ts = [...e.topics];
                  ts[i] = ExamTopic(ts[i].title, v ?? false);
                  repo.save('exams', {'id': e.id, 'topics': Exam.encodeTopics(ts)});
                },
              ),
            ),
          if (units.isNotEmpty) ...[
            SectionTitle(l.tr('units_to_review'), icon: Icons.view_list_rounded),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final u in units) Chip(label: Text(u.title))]),
          ],
          if (e.notes.isNotEmpty) ...[
            SectionTitle(l.tr('notes'), icon: Icons.notes_rounded),
            Card(
              child: Padding(padding: const EdgeInsets.all(14), child: Text(e.notes)),
            ),
          ],
          if (e.courseId != null) ...[
            SectionTitle(l.tr('course_notes'), icon: Icons.sticky_note_2_rounded),
            SizedBox(height: 260, child: NotesList(courseId: e.courseId, compact: true)),
          ],
          AttachmentSection(ownerKind: 'exam', ownerId: e.id, courseId: e.courseId),
          SectionTitle(l.tr('exam_result'), icon: Icons.grade_rounded),
          _Result(e),
        ],
      ),
    );
  }

  Widget _cd(BuildContext context, int v, String label) => Column(
    children: [
      Text(
        '$v',
        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.purple),
      ),
      Text(label),
    ],
  );
}

class _Result extends ConsumerStatefulWidget {
  final Exam e;
  const _Result(this.e);
  @override
  ConsumerState<_Result> createState() => _ResultState();
}

class _ResultState extends ConsumerState<_Result> {
  late final score = TextEditingController(text: widget.e.score?.toString() ?? '');
  late final max = TextEditingController(text: widget.e.maxGrade?.toString() ?? '');
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final e = widget.e;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Field(score, l.tr('score'), keyboard: const TextInputType.numberWithOptions(decimal: true))),
                const SizedBox(width: 10),
                Expanded(child: Field(max, l.tr('max_grade'), keyboard: const TextInputType.numberWithOptions(decimal: true))),
              ],
            ),
            FilledButton.icon(
              icon: const Icon(Icons.save_rounded),
              label: Text(l.tr('save_result')),
              onPressed: () async {
                final s = parseNum(score.text), m = parseNum(max.text);
                if (s == null || m == null || m <= 0 || s < 0) return toast(context, l.tr('v_number'));
                if (s > m) return toast(context, l.tr('err_score_above_max'));
                final repo = ref.read(repoProvider)!;
                await repo.save('exams', {
                  'id': e.id,
                  'score': normalizeDigits(score.text.trim()),
                  'max_grade': normalizeDigits(max.text.trim()),
                }, log: e.title);
                if (e.courseId != null) {
                  await repo.recordScore(
                    courseId: e.courseId!,
                    title: e.title,
                    category: switch (e.kind) {
                      'midterm' => 'midterm',
                      'final' => 'final',
                      'quiz' => 'quiz',
                      'practical' => 'lab',
                      _ => 'exam',
                    },
                    score: normalizeDigits(score.text.trim()),
                    max: normalizeDigits(max.text.trim()),
                    sourceKind: 'exam',
                    sourceId: e.id,
                  );
                }
                if (context.mounted) toast(context, l.tr('saved'));
              },
            ),
            if (e.courseId != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l.tr('score_goes_to_gradebook'), style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
