import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import 'note_editor_screen.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.tr('nav_notes'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'note_add',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoteEditorScreen())),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.tr('add_note')),
      ),
      body: const NotesList(),
    );
  }
}

class NotesList extends ConsumerStatefulWidget {
  final String? courseId;
  final bool compact;
  const NotesList({super.key, this.courseId, this.compact = false});
  @override
  ConsumerState<NotesList> createState() => _NotesListState();
}

class _NotesListState extends ConsumerState<NotesList> {
  String query = '';
  String? category;
  bool archived = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    if (a == null) return const Center(child: CircularProgressIndicator());
    final all = a.notes.where((n) => widget.courseId == null || n.courseId == widget.courseId).toList();
    final cats = all.map((n) => n.category).where((c) => c.isNotEmpty).toSet().toList()..sort();
    final q = query.toLowerCase();
    final list =
        all
            .where((n) => n.archived == archived)
            .where((n) => category == null || n.category == category)
            .where((n) => q.isEmpty || '${n.title}\n${n.lectureTitle}\n${n.body}\n${n.keyPoints}\n${n.summary}\n${n.category}'.toLowerCase().contains(q))
            .toList()
          ..sort((x, y) {
            if (x.pinned != y.pinned) return x.pinned ? -1 : 1;
            return (y.updatedAt ?? DateTime(0)).compareTo(x.updatedAt ?? DateTime(0));
          });
    return PageList(
      padding: widget.compact ? EdgeInsets.zero : const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        if (!widget.compact) ...[
          TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.tr('search_notes')),
            onChanged: (v) => setState(() => query = v.trim()),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilterChip(label: Text(l.tr('archived')), selected: archived, onSelected: (v) => setState(() => archived = v)),
              for (final c in cats) ChoiceChip(label: Text(c), selected: category == c, onSelected: (v) => setState(() => category = v ? c : null)),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (list.isEmpty) EmptyState(icon: Icons.sticky_note_2_rounded, title: l.tr('no_notes')),
        for (final n in list)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorScreen(noteId: n.id))),
              leading: Icon(
                n.pinned ? Icons.push_pin_rounded : Icons.sticky_note_2_outlined,
                color: n.pinned ? AppColors.accent : AppColors.course(a.course(n.courseId)?.color ?? 0),
              ),
              title: Text(
                n.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  if (a.course(n.courseId) != null) a.course(n.courseId)!.name,
                  if (n.lectureTitle.isNotEmpty) n.lectureTitle,
                  if (n.category.isNotEmpty) '#${n.category}',
                  n.body.replaceAll('\n', ' '),
                ].where((e) => e.isNotEmpty).join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: n.summary.isNotEmpty ? const Icon(Icons.summarize_rounded, size: 18) : null,
            ),
          ),
        if (widget.courseId != null && !widget.compact)
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorScreen(courseId: widget.courseId))),
            icon: const Icon(Icons.add_rounded),
            label: Text(l.tr('add_note')),
          ),
      ],
    );
  }
}
