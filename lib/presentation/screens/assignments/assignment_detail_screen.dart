import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/services/academic.dart';
import '../../providers/providers.dart';
import '../../widgets/attachments.dart';
import '../../widgets/common.dart';
import 'assignment_form_screen.dart';

class AssignmentDetailScreen extends ConsumerWidget {
  final String assignmentId;
  const AssignmentDetailScreen({super.key, required this.assignmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    final x = a?.assignments.where((x) => x.id == assignmentId).firstOrNull;
    if (a == null || x == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.tr('not_found'))),
      );
    }
    final repo = ref.read(repoProvider)!;
    final now = DateTime.now();
    final st = effectiveStatus(x, now);
    final subs = a.subtasksOf(x.id);
    final progress = a.progressOf(x);
    final c = a.course(x.courseId);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('assignment')),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: l.tr('edit'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AssignmentFormScreen(assignmentId: x.id))),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: l.tr('delete'),
            onPressed: () async {
              if (await confirm(context, l.tr('delete_confirm'))) {
                await repo.delete('assignments', x.id, log: x.title);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: PageList(
        children: [
          Text(x.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Pill(l.tr('st_$st'), AppColors.status(st)),
              Pill(l.tr('prio_${x.priority}'), x.priority >= 2 ? AppColors.danger : AppColors.info, icon: Icons.flag_rounded),
              if (c != null) Row(mainAxisSize: MainAxisSize.min, children: [CourseDot(c), const SizedBox(width: 4), Text(c.name)]),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (x.assignedOn != null) Text('${l.tr('assigned_on')}: ${l.date(x.assignedOn!)}'),
                  if (x.dueAt != null) ...[
                    Text('${l.tr('due_at')}: ${l.dateTime(x.dueAt!)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    _countdown(context, now, x.dueAt!),
                  ],
                  if (x.submittedAt != null)
                    Text(
                      '${l.tr('submitted_at')}: ${l.dateTime(x.submittedAt!)}${x.dueAt != null && x.submittedAt!.isAfter(x.dueAt!) ? ' · ${l.tr('submitted_late')}' : ''}',
                    ),
                  if (x.maxGrade != null) Text('${l.tr('grade')}: ${x.score?.toString() ?? '—'} / ${x.maxGrade}'),
                ],
              ),
            ),
          ),
          SectionTitle(l.tr('status'), icon: Icons.flag_circle_rounded),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in kAssignmentStatuses)
                ChoiceChip(label: Text(l.tr('st_$s')), selected: x.status == s, onSelected: (_) => repo.setAssignmentStatus(x, s)),
            ],
          ),
          SectionTitle(
            l.tr('progress'),
            icon: Icons.donut_large_rounded,
            trailing: Text('$progress%', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          if (subs.isEmpty)
            Slider(
              value: progress.toDouble(),
              max: 100,
              divisions: 20,
              label: '$progress%',
              onChanged: x.status == 'completed' || x.status == 'submitted'
                  ? null
                  : (v) => repo.save('assignments', {'id': x.id, 'progress': v.round(), if (x.status == 'not_started' && v > 0) 'status': 'in_progress'}),
            )
          else
            ProgressBar(progress / 100),
          SectionTitle(
            l.tr('subtasks'),
            icon: Icons.checklist_rounded,
            trailing: IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: l.tr('add_subtask'),
              onPressed: () async {
                final t = await _ask(context, l.tr('add_subtask'));
                if (t != null) await repo.save('subtasks', {'parent_kind': 'assignment', 'parent_id': x.id, 'title': t, 'position': subs.length});
              },
            ),
          ),
          for (final s in subs)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: CheckboxListTile(
                value: s.done,
                onChanged: (_) => repo.toggleSubtask(s),
                title: Text(s.title, style: TextStyle(decoration: s.done ? TextDecoration.lineThrough : null)),
                secondary: IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => repo.delete('subtasks', s.id)),
              ),
            ),
          if (x.description.isNotEmpty) ...[
            SectionTitle(l.tr('instructions'), icon: Icons.notes_rounded),
            Card(
              child: Padding(padding: const EdgeInsets.all(14), child: SelectableText(x.description)),
            ),
          ],
          if (lines(x.links).isNotEmpty) ...[
            SectionTitle(l.tr('links_refs'), icon: Icons.link_rounded),
            for (final u in lines(x.links))
              ListTile(
                dense: true,
                leading: const Icon(Icons.open_in_new_rounded),
                title: Text(u, textDirection: TextDirection.ltr, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication),
              ),
          ],
          AttachmentSection(ownerKind: 'assignment', ownerId: x.id, courseId: x.courseId),
          SectionTitle(l.tr('submission'), icon: Icons.send_rounded),
          _Submission(x),
          AttachmentSection(ownerKind: 'solution', ownerId: x.id, courseId: x.courseId, titleKey: 'final_solution'),
        ],
      ),
    );
  }

  Widget _countdown(BuildContext context, DateTime now, DateTime due) {
    final l = context.l;
    final cd = Countdown.between(now, due);
    return Text(
      cd.past ? l.tr('deadline_passed') : l.tr('countdown', {'d': '${cd.days}', 'h': '${cd.hours}', 'm': '${cd.minutes}'}),
      style: TextStyle(color: cd.past ? AppColors.danger : AppColors.success, fontWeight: FontWeight.w700),
    );
  }

  static Future<String?> _ask(BuildContext context, String title) async {
    final t = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(controller: t, autofocus: true, onSubmitted: (v) => Navigator.pop(c, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(c.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, t.text), child: Text(c.tr('save'))),
        ],
      ),
    );
    return r == null || r.trim().isEmpty ? null : r.trim();
  }
}

class _Submission extends ConsumerStatefulWidget {
  final Assignment x;
  const _Submission(this.x);
  @override
  ConsumerState<_Submission> createState() => _SubmissionState();
}

class _SubmissionState extends ConsumerState<_Submission> {
  late final note = TextEditingController(text: widget.x.solutionNote);
  late final score = TextEditingController(text: widget.x.score?.toString() ?? '');
  late DateTime? submittedAt = widget.x.submittedAt;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final x = widget.x;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DateTimeField(label: l.tr('submitted_at'), value: submittedAt, withTime: true, onChanged: (v) => setState(() => submittedAt = v)),
            Field(note, l.tr('solution_note'), maxLines: 3),
            if (x.maxGrade != null) Field(score, '${l.tr('score')} / ${x.maxGrade}', keyboard: const TextInputType.numberWithOptions(decimal: true)),
            FilledButton.icon(
              icon: const Icon(Icons.save_rounded),
              label: Text(l.tr('save_submission')),
              onPressed: () async {
                final repo = ref.read(repoProvider)!;
                final sc = score.text.trim().isEmpty ? null : normalizeDigits(score.text.trim());
                if (sc != null && (double.tryParse(sc) == null || double.parse(sc) < 0 || (x.maxGrade != null && double.parse(sc) > x.maxGrade!.toDouble()))) {
                  return toast(context, l.tr('err_score_above_max'));
                }
                await repo.save('assignments', {
                  'id': x.id,
                  'solution_note': note.text.trim(),
                  'submitted_at': submittedAt == null ? null : isoUtc(submittedAt!),
                  'score': sc,
                  if (submittedAt != null && x.status != 'completed') 'status': 'submitted',
                  if (submittedAt != null) 'progress': 100,
                }, log: x.title);
                if (sc != null && x.courseId != null && x.maxGrade != null) {
                  await repo.recordScore(
                    courseId: x.courseId!,
                    title: x.title,
                    category: 'assignment',
                    score: sc,
                    max: x.maxGrade.toString(),
                    sourceKind: 'assignment',
                    sourceId: x.id,
                  );
                }
                if (context.mounted) toast(context, l.tr('saved'));
              },
            ),
            if (x.maxGrade != null && x.courseId != null)
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
