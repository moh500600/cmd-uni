import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/services/conflicts.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

const kSessionKinds = ['lecture', 'lab', 'tutorial', 'seminar'];

class SessionFormScreen extends ConsumerStatefulWidget {
  final String? sessionId;
  final String? courseId;
  final int? weekday;
  const SessionFormScreen({super.key, this.sessionId, this.courseId, this.weekday});
  @override
  ConsumerState<SessionFormScreen> createState() => _SessionFormScreenState();
}

class _SessionFormScreenState extends ConsumerState<SessionFormScreen> {
  final _form = GlobalKey<FormState>();
  final room = TextEditingController(), instructor = TextEditingController(), link = TextEditingController(), reminder = TextEditingController();
  String? courseId;
  int weekday = DateTime.now().weekday;
  int? start = 8 * 60, end = 9 * 60 + 30;
  String kind = 'lecture', mode = 'in_person';
  bool _loaded = false;

  void _load() {
    if (_loaded) return;
    final a = ref.read(academicProvider).value;
    if (a == null) return;
    _loaded = true;
    courseId = widget.courseId ?? (a.activeCourses.isEmpty ? null : a.activeCourses.first.id);
    weekday = widget.weekday ?? weekday;
    final s = a.sessions.where((s) => s.id == widget.sessionId).firstOrNull;
    if (s == null) return;
    courseId = s.courseId;
    weekday = s.weekday;
    start = s.startMin;
    end = s.endMin;
    kind = s.kind;
    mode = s.mode;
    room.text = s.room;
    instructor.text = s.instructor;
    link.text = s.link;
    reminder.text = s.reminderMin?.toString() ?? '';
  }

  Future<void> _save() async {
    final l = context.l;
    if (courseId == null) return toast(context, l.tr('choose_course'));
    if (start == null || end == null || end! <= start!) return toast(context, l.tr('err_end_before_start'));
    final a = ref.read(academicProvider).value!;
    final clashes = conflictsWith(Slot(widget.sessionId ?? '', weekday, start!, end!), [
      for (final s in a.sessions)
        if (a.course(s.courseId)?.archived == false) Slot(s.id, s.weekday, s.startMin, s.endMin),
    ]);
    if (clashes.isNotEmpty) {
      final names = clashes
          .map((c) {
            final s = a.sessions.firstWhere((x) => x.id == c.id);
            return '• ${a.course(s.courseId)?.name} (${hhmm(s.startMin)}–${hhmm(s.endMin)})';
          })
          .join('\n');
      final ok = await confirm(context, '${l.tr('conflict_warning')}\n$names', okLabel: l.tr('save_anyway'), danger: false);
      if (!ok) return;
    }
    try {
      await ref.read(repoProvider)!.save('class_sessions', {
        'id': widget.sessionId,
        'course_id': courseId,
        'weekday': weekday,
        'start_min': start,
        'end_min': end,
        'kind': kind,
        'mode': mode,
        'room': room.text.trim(),
        'instructor': instructor.text.trim(),
        'link': link.text.trim(),
        'reminder_min': int.tryParse(normalizeDigits(reminder.text.trim())),
      });
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
    final course = a?.course(courseId);
    return FormPage(
      title: l.tr(widget.sessionId == null ? 'add_session' : 'edit_session'),
      formKey: _form,
      onSave: _save,
      actions: [
        if (widget.sessionId != null)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              if (await confirm(context, l.tr('delete_confirm'))) {
                await ref.read(repoProvider)!.delete('class_sessions', widget.sessionId!);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
      ],
      children: [
        Pick<String>(
          label: l.tr('course'),
          icon: Icons.menu_book_rounded,
          value: courseId,
          items: [for (final c in a?.activeCourses ?? []) (c.id, c.name)],
          onChanged: (v) => setState(() {
            courseId = v;
            if (instructor.text.isEmpty) instructor.text = a?.course(v)?.instructor ?? '';
          }),
        ),
        Pick<int>(
          label: l.tr('weekday'),
          icon: Icons.today_rounded,
          value: weekday,
          items: [for (var d = 1; d <= 7; d++) (d, l.weekdayName(d))],
          onChanged: (v) => setState(() => weekday = v ?? weekday),
        ),
        Row(
          children: [
            Expanded(
              child: TimeField(
                label: l.tr('start_time'),
                minutes: start,
                onChanged: (v) => setState(() {
                  final dur = (end ?? 0) - (start ?? 0);
                  start = v;
                  if (v != null && (end == null || end! <= v)) end = (v + (dur > 0 ? dur : 90)).clamp(0, 1440);
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TimeField(label: l.tr('end_time'), minutes: end, onChanged: (v) => setState(() => end = v)),
            ),
          ],
        ),
        if (start != null && end != null && end! <= start!)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l.tr('err_end_before_start'), style: const TextStyle(color: AppColors.danger)),
          ),
        Pick<String>(
          label: l.tr('session_kind'),
          value: kind,
          items: [for (final k in kSessionKinds) (k, l.tr('sk_$k'))],
          onChanged: (v) => setState(() => kind = v ?? kind),
        ),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'in_person', label: Text(l.tr('mode_in_person')), icon: const Icon(Icons.meeting_room_rounded)),
            ButtonSegment(value: 'online', label: Text(l.tr('mode_online')), icon: const Icon(Icons.videocam_rounded)),
          ],
          selected: {mode},
          onSelectionChanged: (v) => setState(() => mode = v.first),
        ),
        const SizedBox(height: 12),
        if (mode == 'in_person') Field(room, l.tr('room'), icon: Icons.location_on_rounded),
        if (mode == 'online') Field(link, l.tr('online_link'), icon: Icons.link_rounded, validator: V.url, textDirection: TextDirection.ltr),
        Field(instructor, l.tr('instructor'), icon: Icons.person_rounded, hint: course?.instructor),
        Field(
          reminder,
          l.tr('remind_before_min'),
          icon: Icons.notifications_active_rounded,
          keyboard: TextInputType.number,
          hint: l.tr('default_from_settings'),
          validator: (v) => V.integer(v, max: 1440),
        ),
      ],
    );
  }
}
