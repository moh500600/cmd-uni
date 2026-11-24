import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/time.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

class AssignmentFormScreen extends ConsumerStatefulWidget {
  final String? assignmentId;
  final String? courseId;
  final Map<String, dynamic>? prefill; // from the assistant
  const AssignmentFormScreen({super.key, this.assignmentId, this.courseId, this.prefill});
  @override
  ConsumerState<AssignmentFormScreen> createState() => _AssignmentFormScreenState();
}

class _AssignmentFormScreenState extends ConsumerState<AssignmentFormScreen> {
  final _form = GlobalKey<FormState>();
  final title = TextEditingController(), desc = TextEditingController(), maxGrade = TextEditingController();
  final links = TextEditingController(), reminder = TextEditingController();
  String? courseId;
  DateTime? assignedOn = DateTime.now(), dueAt;
  int priority = 1;
  String status = 'not_started';
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
      desc.text = p['description']?.toString() ?? '';
      dueAt = DateTime.tryParse(p['due_at']?.toString() ?? '')?.toLocal();
      priority = (p['priority'] as num?)?.toInt().clamp(0, 3) ?? 1;
      final cn = p['course']?.toString().toLowerCase();
      if (cn != null) {
        for (final c in a.activeCourses) {
          if (c.name.toLowerCase() == cn || c.code.toLowerCase() == cn) courseId = c.id;
        }
      }
    }
    final x = a.assignments.where((x) => x.id == widget.assignmentId).firstOrNull;
    if (x == null) return;
    title.text = x.title;
    desc.text = x.description;
    maxGrade.text = x.maxGrade?.toString() ?? '';
    links.text = x.links;
    reminder.text = x.reminderMin == null ? '' : '${x.reminderMin! ~/ 60}';
    courseId = x.courseId;
    assignedOn = x.assignedOn;
    dueAt = x.dueAt;
    priority = x.priority;
    status = x.status;
  }

  Future<void> _save() async {
    final l = context.l;
    if (dueAt != null && assignedOn != null && dueAt!.isBefore(assignedOn!)) return toast(context, l.tr('err_due_before_assigned'));
    for (final ln in lines(links.text)) {
      if (V.url(ln) != null) return toast(context, '${l.tr('v_url')}: $ln');
    }
    try {
      final h = int.tryParse(normalizeDigits(reminder.text.trim()));
      final id = await ref.read(repoProvider)!.save('assignments', {
        'id': widget.assignmentId,
        'title': title.text.trim(),
        'description': desc.text.trim(),
        'course_id': courseId,
        'assigned_on': assignedOn == null ? null : dateKey(assignedOn!),
        'due_at': dueAt == null ? null : isoUtc(dueAt!),
        'priority': priority,
        'max_grade': maxGrade.text.trim().isEmpty ? null : normalizeDigits(maxGrade.text.trim()),
        'links': links.text.trim(),
        'reminder_min': h == null ? null : h * 60,
        if (widget.assignmentId == null) 'status': status,
      }, log: title.text.trim());
      if (mounted) Navigator.pop(context, id);
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
      title: l.tr(widget.assignmentId == null ? 'add_assignment' : 'edit_assignment'),
      formKey: _form,
      onSave: _save,
      children: [
        Field(title, l.tr('assignment_title'), icon: Icons.assignment_rounded, validator: V.required),
        Pick<String>(
          label: l.tr('course'),
          icon: Icons.menu_book_rounded,
          value: courseId,
          allowNone: true,
          items: [for (final c in a?.activeCourses ?? <Course>[]) (c.id, c.name)],
          onChanged: (v) => setState(() => courseId = v),
        ),
        Field(desc, l.tr('instructions'), maxLines: 4, icon: Icons.notes_rounded),
        Row(
          children: [
            Expanded(
              child: DateTimeField(label: l.tr('assigned_on'), value: assignedOn, onChanged: (v) => setState(() => assignedOn = v)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DateTimeField(label: l.tr('due_at'), value: dueAt, withTime: true, icon: Icons.alarm_rounded, onChanged: (v) => setState(() => dueAt = v)),
            ),
          ],
        ),
        Text(l.tr('priority'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            for (final p in [0, 1, 2, 3]) ButtonSegment(value: p, label: Text(l.tr('prio_$p'))),
          ],
          selected: {priority},
          onSelectionChanged: (v) => setState(() => priority = v.first),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Field(
                maxGrade,
                l.tr('max_grade'),
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => V.number(v, positive: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Field(
                reminder,
                l.tr('remind_before_h'),
                keyboard: TextInputType.number,
                hint: l.tr('default_from_settings'),
                validator: (v) => V.integer(v, max: 720),
              ),
            ),
          ],
        ),
        Field(links, l.tr('links_refs'), maxLines: 3, icon: Icons.link_rounded, hint: l.tr('one_per_line'), textDirection: TextDirection.ltr),
      ],
    );
  }
}
