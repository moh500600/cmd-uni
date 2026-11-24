import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/time.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

class ExamFormScreen extends ConsumerStatefulWidget {
  final String? examId;
  final String? courseId;
  final Map<String, dynamic>? prefill;
  const ExamFormScreen({super.key, this.examId, this.courseId, this.prefill});
  @override
  ConsumerState<ExamFormScreen> createState() => _ExamFormScreenState();
}

class _ExamFormScreenState extends ConsumerState<ExamFormScreen> {
  final _form = GlobalKey<FormState>();
  final title = TextEditingController(), location = TextEditingController(), duration = TextEditingController(text: '60');
  final maxGrade = TextEditingController(), topics = TextEditingController(), notes = TextEditingController(), reminder = TextEditingController();
  String? courseId;
  String kind = 'quiz';
  DateTime? startsAt;
  List<ExamTopic> _oldTopics = [];
  bool _loaded = false;

  void _load() {
    if (_loaded) return;
    final a = ref.read(academicProvider).value;
    if (a == null) return;
    _loaded = true;
    courseId = widget.courseId;
    final p = widget.prefill;
    if (p != null) {
      title.text = p['title']?.toString() ?? '';
      startsAt = DateTime.tryParse(p['starts_at']?.toString() ?? '')?.toLocal();
      if (kExamKinds.contains(p['kind'])) kind = p['kind'] as String;
      final cn = p['course']?.toString().toLowerCase();
      for (final c in a.activeCourses) {
        if (c.name.toLowerCase() == cn || c.code.toLowerCase() == cn) courseId = c.id;
      }
      topics.text = ((p['topics'] as List?) ?? const []).join('\n');
    }
    final e = a.exams.where((e) => e.id == widget.examId).firstOrNull;
    if (e == null) return;
    title.text = e.title;
    location.text = e.location;
    duration.text = '${e.durationMin}';
    maxGrade.text = e.maxGrade?.toString() ?? '';
    topics.text = e.topics.map((t) => t.title).join('\n');
    _oldTopics = e.topics;
    notes.text = e.notes;
    reminder.text = e.reminderMin == null ? '' : '${e.reminderMin! ~/ 60}';
    courseId = e.courseId;
    kind = e.kind;
    startsAt = e.startsAt;
  }

  Future<void> _save() async {
    final l = context.l;
    if (startsAt == null) return toast(context, l.tr('choose_date'));
    final done = {for (final t in _oldTopics) t.title: t.done};
    final ts = [for (final t in lines(topics.text)) ExamTopic(t, done[t] ?? false)];
    final h = int.tryParse(normalizeDigits(reminder.text.trim()));
    try {
      await ref.read(repoProvider)!.save('exams', {
        'id': widget.examId,
        'title': title.text.trim(),
        'course_id': courseId,
        'kind': kind,
        'starts_at': isoUtc(startsAt!),
        'duration_min': int.tryParse(normalizeDigits(duration.text.trim())) ?? 60,
        'location': location.text.trim(),
        'max_grade': maxGrade.text.trim().isEmpty ? null : normalizeDigits(maxGrade.text.trim()),
        'topics': Exam.encodeTopics(ts),
        'notes': notes.text.trim(),
        'reminder_min': h == null ? null : h * 60,
      }, log: title.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, errorText(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    _load();
    return FormPage(
      title: l.tr(widget.examId == null ? 'add_exam' : 'edit_exam'),
      formKey: _form,
      onSave: _save,
      children: [
        Field(title, l.tr('exam_title'), icon: Icons.quiz_rounded, validator: V.required),
        Pick<String>(
          label: l.tr('course'),
          icon: Icons.menu_book_rounded,
          value: courseId,
          allowNone: true,
          items: [for (final c in a?.activeCourses ?? <Course>[]) (c.id, c.name)],
          onChanged: (v) => setState(() => courseId = v),
        ),
        Pick<String>(
          label: l.tr('exam_kind'),
          value: kind,
          items: [for (final k in kExamKinds) (k, l.tr('ek_$k'))],
          onChanged: (v) => setState(() => kind = v ?? kind),
        ),
        DateTimeField(label: l.tr('date_time'), value: startsAt, withTime: true, clearable: false, onChanged: (v) => setState(() => startsAt = v)),
        Row(
          children: [
            Expanded(
              child: Field(duration, l.tr('duration_min'), keyboard: TextInputType.number, validator: (v) => V.integer(v, required: true, min: 1, max: 600)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Field(
                maxGrade,
                l.tr('max_grade'),
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => V.number(v, positive: true),
              ),
            ),
          ],
        ),
        Field(location, l.tr('location'), icon: Icons.location_on_rounded),
        Field(topics, l.tr('exam_topics'), maxLines: 6, icon: Icons.checklist_rounded, hint: l.tr('one_per_line')),
        Field(notes, l.tr('notes'), maxLines: 3, icon: Icons.notes_rounded),
        Field(reminder, l.tr('remind_before_h'), keyboard: TextInputType.number, hint: l.tr('default_from_settings'), validator: (v) => V.integer(v, max: 720)),
      ],
    );
  }
}
