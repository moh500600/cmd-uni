import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import 'project_detail_screen.dart';
import 'project_form_screen.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});
  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  bool showDone = false;
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    final list = a == null
        ? []
        : a.projects.where((p) => showDone ? (p.status == 'done' || p.status == 'cancelled') : (p.status != 'done' && p.status != 'cancelled')).toList();
    return Scaffold(
      appBar: AppBar(title: Text(l.tr('nav_projects'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'proj_add',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectFormScreen())),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.tr('add_project')),
      ),
      body: a == null
          ? const Center(child: CircularProgressIndicator())
          : PageList(
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(l.tr('active'))),
                    ButtonSegment(value: true, label: Text(l.tr('finished'))),
                  ],
                  selected: {showDone},
                  onSelectionChanged: (v) => setState(() => showDone = v.first),
                ),
                const SizedBox(height: 10),
                if (list.isEmpty) EmptyState(icon: Icons.account_tree_rounded, title: l.tr('no_projects')),
                for (final p in list)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: p.id))),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Ring(value: a.projectProgress(p) / 100, label: '${a.projectProgress(p)}%', color: AppColors.purple, size: 54),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                  Text(
                                    [courseName(context, a.course(p.courseId)), if (p.dueOn != null) '${l.tr('due')}: ${l.date(p.dueOn!)}'].join(' · '),
                                    style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      Pill(l.tr('ps_${p.status}'), AppColors.purple),
                                      Pill(
                                        l.tr(p.isGroup ? 'group_project' : 'solo_project'),
                                        AppColors.info,
                                        icon: p.isGroup ? Icons.groups_rounded : Icons.person_rounded,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
