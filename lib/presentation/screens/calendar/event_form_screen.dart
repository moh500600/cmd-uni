import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/time.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

class EventFormScreen extends ConsumerStatefulWidget {
  final String? eventId;
  final DateTime? initial;
  final Map<String, dynamic>? prefill;
  const EventFormScreen({super.key, this.eventId, this.initial, this.prefill});
  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _form = GlobalKey<FormState>();
  final title = TextEditingController(), location = TextEditingController(), notes = TextEditingController(), reminder = TextEditingController();
  String kind = 'event';
  String? courseId;
  DateTime? start, end;
  bool allDay = false, _loaded = false;

  void _load() {
    if (_loaded) return;
    final a = ref.read(academicProvider).value;
    if (a == null) return;
    _loaded = true;
    start = widget.initial ?? DateTime.now().add(const Duration(hours: 1));
    end = start!.add(const Duration(hours: 1));
    final p = widget.prefill;
    if (p != null) {
      title.text = p['title']?.toString() ?? '';
      start = DateTime.tryParse(p['starts_at']?.toString() ?? '')?.toLocal() ?? start;
      end = DateTime.tryParse(p['ends_at']?.toString() ?? '')?.toLocal() ?? start!.add(const Duration(hours: 1));
      location.text = p['location']?.toString() ?? '';
    }
    final e = a.events.where((e) => e.id == widget.eventId).firstOrNull;
    if (e == null) return;
    title.text = e.title;
    location.text = e.location;
    notes.text = e.notes;
    reminder.text = e.reminderMin?.toString() ?? '';
    kind = e.kind;
    courseId = e.courseId;
    start = e.startsAt;
    end = e.endsAt;
    allDay = e.allDay;
  }

  Future<void> _save() async {
    final l = context.l;
    if (start == null) return toast(context, l.tr('choose_date'));
    if (end != null && end!.isBefore(start!)) return toast(context, l.tr('err_end_before_start'));
    try {
      await ref.read(repoProvider)!.save('events', {
        'id': widget.eventId,
        'title': title.text.trim(),
        'kind': kind,
        'course_id': courseId,
        'starts_at': isoUtc(allDay ? dayOnly(start!) : start!),
        'ends_at': end == null ? null : isoUtc(allDay ? dayOnly(end!) : end!),
        'all_day': allDay,
        'location': location.text.trim(),
        'notes': notes.text.trim(),
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
    return FormPage(
      title: l.tr(widget.eventId == null ? 'add_event' : 'edit_event'),
      formKey: _form,
      onSave: _save,
      actions: [
        if (widget.eventId != null)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              if (await confirm(context, l.tr('delete_confirm'))) {
                await ref.read(repoProvider)!.delete('events', widget.eventId!);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
      ],
      children: [
        Field(title, l.tr('title'), icon: Icons.event_rounded, validator: V.required),
        Pick<String>(
          label: l.tr('event_kind'),
          value: kind,
          items: [for (final k in kEventKinds) (k, l.tr('evk_$k'))],
          onChanged: (v) => setState(() => kind = v ?? kind),
        ),
        Pick<String>(
          label: l.tr('course'),
          value: courseId,
          allowNone: true,
          items: [for (final c in a?.activeCourses ?? <Course>[]) (c.id, c.name)],
          onChanged: (v) => setState(() => courseId = v),
        ),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: allDay, onChanged: (v) => setState(() => allDay = v), title: Text(l.tr('all_day'))),
        DateTimeField(label: l.tr('starts'), value: start, withTime: !allDay, clearable: false, onChanged: (v) => setState(() => start = v)),
        DateTimeField(label: l.tr('ends'), value: end, withTime: !allDay, onChanged: (v) => setState(() => end = v)),
        Field(location, l.tr('location'), icon: Icons.location_on_rounded),
        Field(notes, l.tr('notes'), maxLines: 3),
        Field(reminder, l.tr('remind_before_min'), keyboard: TextInputType.number, validator: (v) => V.integer(v, max: 10080)),
      ],
    );
  }
}
