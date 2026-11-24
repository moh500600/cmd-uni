import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/time.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

class ProjectFormScreen extends ConsumerStatefulWidget {
  final String? projectId;
  const ProjectFormScreen({super.key, this.projectId});
  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  final _form = GlobalKey<FormState>();
  final title = TextEditingController(), desc = TextEditingController(), supervisor = TextEditingController(), team = TextEditingController();
  String? courseId;
  bool isGroup = false;
  DateTime? startOn = DateTime.now(), dueOn;
  String status = 'active';
  bool _loaded = false;

  void _load() {
    if (_loaded) return;
    final a = ref.read(academicProvider).value;
    if (a == null) return;
    _loaded = true;
    final p = a.projects.where((p) => p.id == widget.projectId).firstOrNull;
    if (p == null) return;
    title.text = p.title;
    desc.text = p.description;
    supervisor.text = p.supervisor;
    team.text = p.team;
    courseId = p.courseId;
    isGroup = p.isGroup;
    startOn = p.startOn;
    dueOn = p.dueOn;
    status = p.status;
  }

  Future<void> _save() async {
    final l = context.l;
    if (startOn != null && dueOn != null && dueOn!.isBefore(startOn!)) return toast(context, l.tr('err_due_before_assigned'));
    try {
      await ref.read(repoProvider)!.save('projects', {
        'id': widget.projectId,
        'title': title.text.trim(),
        'description': desc.text.trim(),
        'supervisor': supervisor.text.trim(),
        'team': lines(team.text).join('\n'),
        'is_group': isGroup,
        'course_id': courseId,
        'start_on': startOn == null ? null : dateKey(startOn!),
        'due_on': dueOn == null ? null : dateKey(dueOn!),
        'status': status,
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
      title: l.tr(widget.projectId == null ? 'add_project' : 'edit_project'),
      formKey: _form,
      onSave: _save,
      children: [
        Field(title, l.tr('project_title'), icon: Icons.account_tree_rounded, validator: V.required),
        Pick<String>(
          label: l.tr('course'),
          icon: Icons.menu_book_rounded,
          value: courseId,
          allowNone: true,
          items: [for (final c in a?.activeCourses ?? <Course>[]) (c.id, c.name)],
          onChanged: (v) => setState(() => courseId = v),
        ),
        Field(desc, l.tr('description'), maxLines: 4, icon: Icons.notes_rounded),
        Field(supervisor, l.tr('supervisor'), icon: Icons.person_rounded),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: isGroup, onChanged: (v) => setState(() => isGroup = v), title: Text(l.tr('group_project'))),
        if (isGroup) Field(team, l.tr('team_members'), maxLines: 5, icon: Icons.groups_rounded, hint: l.tr('one_per_line')),
        Row(
          children: [
            Expanded(
              child: DateTimeField(label: l.tr('start_date'), value: startOn, onChanged: (v) => setState(() => startOn = v)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DateTimeField(label: l.tr('due_date'), value: dueOn, icon: Icons.flag_rounded, onChanged: (v) => setState(() => dueOn = v)),
            ),
          ],
        ),
        Pick<String>(
          label: l.tr('status'),
          value: status,
          items: [for (final s in kProjectStatuses) (s, l.tr('ps_$s'))],
          onChanged: (v) => setState(() => status = v ?? status),
        ),
      ],
    );
  }
}
