import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';
import '../../widgets/attachments.dart';
import '../../widgets/common.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('nav_resources'))),
    body: const ResourceList(),
  );
}

class ResourceList extends ConsumerStatefulWidget {
  final String? courseId;
  const ResourceList({super.key, this.courseId});
  @override
  ConsumerState<ResourceList> createState() => _ResourceListState();
}

class _ResourceListState extends ConsumerState<ResourceList> {
  String query = '';
  String? course, category, type;
  String sort = 'date';

  Future<void> _add() async {
    final l = context.l;
    final a = ref.read(academicProvider).value;
    final fs = ref.read(fileServiceProvider);
    if (a == null || fs == null) return;
    String cat = category ?? 'lecture';
    String? cid = widget.courseId ?? course;
    final isLink = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file_rounded),
              title: Text(l.tr('upload_file')),
              subtitle: Text(l.tr('upload_file_sub')),
              onTap: () => Navigator.pop(c, false),
            ),
            ListTile(leading: const Icon(Icons.add_link_rounded), title: Text(l.tr('add_link')), onTap: () => Navigator.pop(c, true)),
          ],
        ),
      ),
    );
    if (isLink == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(l.tr('file_details')),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Pick<String>(
                  label: l.tr('category'),
                  value: cat,
                  items: [for (final k in kResourceCategories) (k, l.tr('rc_$k'))],
                  onChanged: (v) => set(() => cat = v ?? cat),
                ),
                if (widget.courseId == null)
                  Pick<String>(
                    label: l.tr('course'),
                    value: cid,
                    allowNone: true,
                    items: [for (final x in a.activeCourses) (x.id, x.name)],
                    onChanged: (v) => set(() => cid = v),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.tr('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.tr('next'))),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      if (isLink) {
        final r = await askLink(context);
        if (r != null) await fs.addLink(r.$2, title: r.$1, courseId: cid, category: cat);
      } else {
        final f = await fs.pick();
        if (f != null) await fs.addPicked(f, courseId: cid, category: cat);
      }
    } catch (e) {
      if (mounted) toast(context, errorText(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    if (a == null) return const Center(child: CircularProgressIndicator());
    final q = query.toLowerCase();
    final cid = widget.courseId ?? course;
    final list =
        a.resources
            .where((r) => cid == null || r.courseId == cid)
            .where((r) => category == null || r.category == category)
            .where((r) => type == null || r.fileType == type)
            .where((r) => q.isEmpty || '${r.title} ${r.fileName} ${r.notes}'.toLowerCase().contains(q))
            .toList()
          ..sort(
            (x, y) => switch (sort) {
              'name' => x.title.toLowerCase().compareTo(y.title.toLowerCase()),
              'type' => x.fileType.compareTo(y.fileType),
              _ => (y.createdAt ?? DateTime(0)).compareTo(x.createdAt ?? DateTime(0)),
            },
          );
    return Stack(
      children: [
        PageList(
          children: [
            TextField(
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.tr('search_files')),
              onChanged: (v) => setState(() => query = v.trim()),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (widget.courseId == null)
                    _menu(l.tr('course'), course == null ? null : a.course(course)?.name, [
                      for (final c in a.activeCourses) (c.id, c.name),
                    ], (v) => setState(() => course = v)),
                  _menu(l.tr('category'), category == null ? null : l.tr('rc_$category'), [
                    for (final k in kResourceCategories) (k, l.tr('rc_$k')),
                  ], (v) => setState(() => category = v)),
                  _menu(l.tr('file_type'), type == null ? null : l.tr('ft_$type'), [
                    for (final k in kFileTypes) (k, l.tr('ft_$k')),
                  ], (v) => setState(() => type = v)),
                  PopupMenuButton<String>(
                    initialValue: sort,
                    onSelected: (v) => setState(() => sort = v),
                    itemBuilder: (_) => [
                      for (final s in ['date', 'name', 'type']) PopupMenuItem(value: s, child: Text(l.tr('sort_$s'))),
                    ],
                    child: Chip(avatar: const Icon(Icons.sort_rounded, size: 18), label: Text(l.tr('sort_$sort'))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (list.isEmpty) EmptyState(icon: Icons.folder_open_rounded, title: l.tr('no_files'), subtitle: l.tr('files_hint')),
            for (final r in list) ResourceTile(r),
          ],
        ),
        PositionedDirectional(
          end: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'res_add_${widget.courseId}',
            onPressed: _add,
            icon: const Icon(Icons.add_rounded),
            label: Text(l.tr('add_file')),
          ),
        ),
      ],
    );
  }

  Widget _menu(String label, String? current, List<(String, String)> items, ValueChanged<String?> onSel) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 6),
    child: PopupMenuButton<String>(
      onSelected: (v) => onSel(v.isEmpty ? null : v),
      itemBuilder: (_) => [
        PopupMenuItem<String>(value: '', child: Text(context.tr('all'))),
        for (final (v, t) in items) PopupMenuItem<String>(value: v, child: Text(t)),
      ],
      child: Chip(
        label: Text(current ?? label),
        avatar: Icon(Icons.filter_list_rounded, size: 18, color: current == null ? null : Theme.of(context).colorScheme.primary),
      ),
    ),
  );
}
