import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/services/academic.dart';
import '../../providers/providers.dart';
import '../../widgets/attachments.dart';
import '../../widgets/common.dart';
import 'project_form_screen.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    final p = a?.projects.where((p) => p.id == projectId).firstOrNull;
    if (a == null || p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.tr('not_found'))),
      );
    }
    final repo = ref.read(repoProvider)!;
    final phases = a.phasesOf(p.id);
    final tasks = a.subtasksOf(p.id);
    final log = a.activity.where((e) => e.entityId == p.id).take(30).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('project')),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectFormScreen(projectId: p.id))),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              if (await confirm(context, l.tr('delete_confirm'))) {
                await repo.delete('projects', p.id, log: p.title);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'task_add',
        onPressed: () => _editTask(context, ref, a, p, null),
        icon: const Icon(Icons.add_task_rounded),
        label: Text(l.tr('add_task')),
      ),
      body: PageList(
        children: [
          Row(
            children: [
              Ring(value: a.projectProgress(p) / 100, label: '${a.projectProgress(p)}%', color: AppColors.purple, size: 76),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                    Text([courseName(context, a.course(p.courseId)), if (p.supervisor.isNotEmpty) '${l.tr('supervisor')}: ${p.supervisor}'].join(' · ')),
                    Text([if (p.startOn != null) l.date(p.startOn!), if (p.dueOn != null) '→ ${l.date(p.dueOn!)}'].join(' ')),
                    const SizedBox(height: 4),
                    Pill(l.tr('ps_${p.status}'), AppColors.purple),
                  ],
                ),
              ),
            ],
          ),
          if (p.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Card(
                child: Padding(padding: const EdgeInsets.all(14), child: Text(p.description)),
              ),
            ),
          if (p.isGroup && p.members.isNotEmpty) ...[
            SectionTitle(l.tr('team_members'), icon: Icons.groups_rounded),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in p.members)
                  Chip(
                    avatar: CircleAvatar(child: Text(m.characters.first)),
                    label: Text('$m · ${tasks.where((t) => t.assignee == m && t.done).length}/${tasks.where((t) => t.assignee == m).length}'),
                  ),
              ],
            ),
          ],
          SectionTitle(
            l.tr('phases'),
            icon: Icons.linear_scale_rounded,
            trailing: IconButton(
              tooltip: l.tr('add_phase'),
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: () => _editPhase(context, ref, p, null, phases.length),
            ),
          ),
          if (phases.isEmpty) Text(l.tr('phases_hint'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          for (final ph in phases) ...[
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: Checkbox(
                  value: ph.done,
                  onChanged: (v) async {
                    await repo.save('project_phases', {'id': ph.id, 'done': v ?? false});
                    await repo.log('projects', p.id, v == true ? 'phase_done' : 'phase_reopened', ph.title);
                  },
                ),
                title: Text(ph.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  [
                    if (ph.dueOn != null) l.date(ph.dueOn!),
                    '${tasks.where((t) => t.phaseId == ph.id && t.done).length}/${tasks.where((t) => t.phaseId == ph.id).length}',
                  ].join(' · '),
                ),
                trailing: IconButton(icon: const Icon(Icons.more_horiz_rounded), onPressed: () => _editPhase(context, ref, p, ph, phases.length)),
              ),
            ),
            for (final t in tasks.where((t) => t.phaseId == ph.id)) _taskTile(context, ref, a, p, t, indent: true),
          ],
          SectionTitle(l.tr('tasks'), icon: Icons.checklist_rounded),
          if (tasks.where((t) => t.phaseId == null).isEmpty && tasks.isEmpty) Text(l.tr('no_tasks')),
          for (final t in tasks.where((t) => t.phaseId == null || !phases.any((ph) => ph.id == t.phaseId))) _taskTile(context, ref, a, p, t),
          AttachmentSection(ownerKind: 'project', ownerId: p.id, courseId: p.courseId),
          SectionTitle(l.tr('change_log'), icon: Icons.history_rounded),
          if (log.isEmpty) Text(l.tr('no_changes')),
          for (final e in log)
            ListTile(
              dense: true,
              leading: const Icon(Icons.circle, size: 8),
              title: Text('${l.tr('act_${e.action}')} — ${e.detail}'),
              subtitle: e.createdAt == null ? null : Text(l.dateTime(e.createdAt!)),
            ),
        ],
      ),
    );
  }

  Widget _taskTile(BuildContext context, WidgetRef ref, Academic a, Project p, Subtask t, {bool indent = false}) {
    final l = context.l;
    final repo = ref.read(repoProvider)!;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent ? 28 : 0, bottom: 4),
      child: Card(
        child: CheckboxListTile(
          value: t.done,
          onChanged: (_) async {
            await repo.toggleSubtask(t);
            await repo.log('projects', p.id, t.done ? 'task_reopened' : 'task_done', t.title);
          },
          title: Text(t.title, style: TextStyle(decoration: t.done ? TextDecoration.lineThrough : null)),
          subtitle: Text([if (t.assignee.isNotEmpty) '👤 ${t.assignee}', if (t.dueOn != null) l.date(t.dueOn!)].join(' · ')),
          secondary: IconButton(icon: const Icon(Icons.edit_rounded, size: 18), onPressed: () => _editTask(context, ref, a, p, t)),
        ),
      ),
    );
  }

  Future<void> _editPhase(BuildContext context, WidgetRef ref, Project p, ProjectPhase? ph, int count) async {
    final l = context.l;
    final t = TextEditingController(text: ph?.title ?? '');
    DateTime? due = ph?.dueOn;
    final r = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(l.tr(ph == null ? 'add_phase' : 'edit_phase')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: t,
                autofocus: true,
                decoration: InputDecoration(labelText: l.tr('title')),
              ),
              const SizedBox(height: 12),
              DateTimeField(label: l.tr('due_date'), value: due, onChanged: (v) => set(() => due = v)),
            ],
          ),
          actions: [
            if (ph != null)
              TextButton(
                onPressed: () => Navigator.pop(c, 'delete'),
                child: Text(l.tr('delete'), style: const TextStyle(color: AppColors.danger)),
              ),
            TextButton(onPressed: () => Navigator.pop(c), child: Text(l.tr('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: Text(l.tr('save'))),
          ],
        ),
      ),
    );
    final repo = ref.read(repoProvider)!;
    if (r == 'delete' && ph != null) {
      await repo.delete('project_phases', ph.id);
      await repo.log('projects', p.id, 'phase_deleted', ph.title);
    }
    if (r == 'save' && t.text.trim().isNotEmpty) {
      await repo.save('project_phases', {
        'id': ph?.id,
        'project_id': p.id,
        'title': t.text.trim(),
        'due_on': due == null ? null : dateKey(due!),
        if (ph == null) 'position': count,
      });
      await repo.log('projects', p.id, ph == null ? 'phase_added' : 'phase_edited', t.text.trim());
    }
  }

  Future<void> _editTask(BuildContext context, WidgetRef ref, Academic a, Project p, Subtask? t) async {
    final l = context.l;
    final title = TextEditingController(text: t?.title ?? '');
    String? assignee = t?.assignee.isEmpty ?? true ? null : t!.assignee;
    String? phaseId = t?.phaseId;
    DateTime? due = t?.dueOn;
    final phases = a.phasesOf(p.id);
    final r = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(l.tr(t == null ? 'add_task' : 'edit_task')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l.tr('title')),
                ),
                const SizedBox(height: 12),
                if (p.members.isNotEmpty)
                  Pick<String>(
                    label: l.tr('assignee'),
                    value: assignee,
                    allowNone: true,
                    items: [for (final m in p.members) (m, m)],
                    onChanged: (v) => set(() => assignee = v),
                  ),
                if (phases.isNotEmpty)
                  Pick<String>(
                    label: l.tr('phase'),
                    value: phaseId,
                    allowNone: true,
                    items: [for (final ph in phases) (ph.id, ph.title)],
                    onChanged: (v) => set(() => phaseId = v),
                  ),
                DateTimeField(label: l.tr('due_date'), value: due, onChanged: (v) => set(() => due = v)),
              ],
            ),
          ),
          actions: [
            if (t != null)
              TextButton(
                onPressed: () => Navigator.pop(c, 'delete'),
                child: Text(l.tr('delete'), style: const TextStyle(color: AppColors.danger)),
              ),
            TextButton(onPressed: () => Navigator.pop(c), child: Text(l.tr('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: Text(l.tr('save'))),
          ],
        ),
      ),
    );
    final repo = ref.read(repoProvider)!;
    if (r == 'delete' && t != null) {
      await repo.delete('subtasks', t.id);
      await repo.log('projects', p.id, 'task_deleted', t.title);
    }
    if (r == 'save' && title.text.trim().isNotEmpty) {
      await repo.save('subtasks', {
        'id': t?.id,
        'parent_kind': 'project',
        'parent_id': p.id,
        'title': title.text.trim(),
        'assignee': assignee ?? '',
        'phase_id': phaseId,
        'due_on': due == null ? null : dateKey(due!),
        if (t == null) 'position': a.subtasksOf(p.id).length,
      });
      await repo.log('projects', p.id, t == null ? 'task_added' : 'task_edited', '${title.text.trim()}${assignee == null ? '' : ' → $assignee'}');
    }
  }
}
