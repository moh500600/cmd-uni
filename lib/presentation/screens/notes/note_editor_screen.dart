import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ids.dart';
import '../../../core/utils/time.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';
import '../../widgets/attachments.dart';
import '../../widgets/common.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId;
  final String? courseId;
  const NoteEditorScreen({super.key, this.noteId, this.courseId});
  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _form = GlobalKey<FormState>();
  final title = TextEditingController(), lecture = TextEditingController(), body = TextEditingController();
  final points = TextEditingController(), summary = TextEditingController(), category = TextEditingController(), links = TextEditingController();
  late String id = widget.noteId ?? newId();
  String? courseId;
  DateTime? lectureOn = DateTime.now();
  bool pinned = false, archived = false, _loaded = false, _exists = false;

  void _load() {
    if (_loaded) return;
    final a = ref.read(academicProvider).value;
    if (a == null) return;
    _loaded = true;
    courseId = widget.courseId;
    final n = a.notes.where((n) => n.id == widget.noteId).firstOrNull;
    if (n == null) return;
    _exists = true;
    title.text = n.title;
    lecture.text = n.lectureTitle;
    body.text = n.body;
    points.text = n.keyPoints;
    summary.text = n.summary;
    category.text = n.category;
    links.text = n.links;
    courseId = n.courseId;
    lectureOn = n.lectureOn;
    pinned = n.pinned;
    archived = n.archived;
  }

  Future<void> _save({bool close = true}) async {
    if (!(_form.currentState?.validate() ?? false)) return;
    for (final ln in lines(links.text)) {
      if (V.url(ln) != null) return toast(context, '${context.tr('v_url')}: $ln');
    }
    await ref.read(repoProvider)!.save('notes', {
      'id': id,
      'title': title.text.trim(),
      'lecture_title': lecture.text.trim(),
      'lecture_on': lectureOn == null ? null : dateKey(lectureOn!),
      'body': body.text,
      'key_points': points.text,
      'summary': summary.text,
      'category': category.text.trim(),
      'links': links.text.trim(),
      'course_id': courseId,
      'pinned': pinned,
      'archived': archived,
    });
    _exists = true;
    if (close && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    _load();
    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr(widget.noteId == null ? 'add_note' : 'edit_note')),
        actions: [
          IconButton(
            tooltip: l.tr(pinned ? 'unpin' : 'pin'),
            icon: Icon(pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, color: pinned ? AppColors.accent : null),
            onPressed: () => setState(() => pinned = !pinned),
          ),
          IconButton(
            tooltip: l.tr(archived ? 'unarchive' : 'archive'),
            icon: Icon(archived ? Icons.unarchive_rounded : Icons.archive_outlined),
            onPressed: () => setState(() => archived = !archived),
          ),
          if (widget.noteId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                if (await confirm(context, l.tr('delete_confirm'))) {
                  await ref.read(repoProvider)!.delete('notes', id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          IconButton(key: const Key('save_note'), icon: const Icon(Icons.check_rounded), onPressed: _save),
        ],
      ),
      body: Form(
        key: _form,
        child: PageList(
          children: [
            Field(title, l.tr('title'), validator: V.required),
            Row(
              children: [
                Expanded(
                  child: Pick<String>(
                    label: l.tr('course'),
                    value: courseId,
                    allowNone: true,
                    items: [for (final c in a?.activeCourses ?? <Course>[]) (c.id, c.name)],
                    onChanged: (v) => setState(() => courseId = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Field(category, l.tr('category'), hint: l.tr('category_hint'))),
              ],
            ),
            Row(
              children: [
                Expanded(child: Field(lecture, l.tr('lecture_title'))),
                const SizedBox(width: 10),
                Expanded(
                  child: DateTimeField(label: l.tr('lecture_date'), value: lectureOn, onChanged: (v) => setState(() => lectureOn = v)),
                ),
              ],
            ),
            Field(body, l.tr('note_body'), maxLines: 12),
            Field(points, l.tr('key_points'), maxLines: 5, icon: Icons.star_rounded, hint: l.tr('one_per_line')),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Field(summary, l.tr('lecture_summary'), maxLines: 6, icon: Icons.summarize_rounded)),
              ],
            ),
            Field(links, l.tr('links_refs'), maxLines: 3, icon: Icons.link_rounded, hint: l.tr('one_per_line'), textDirection: TextDirection.ltr),
            for (final u in lines(links.text))
              if (V.url(u) == null)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.open_in_new_rounded),
                  title: Text(u, textDirection: TextDirection.ltr),
                  onTap: () => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication),
                ),
            if (_exists)
              AttachmentSection(ownerKind: 'note', ownerId: id, courseId: courseId, titleKey: 'note_files')
            else
              OutlinedButton.icon(
                onPressed: () async {
                  await _save(close: false);
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(l.tr('save_to_attach')),
              ),
          ],
        ),
      ),
    );
  }
}
