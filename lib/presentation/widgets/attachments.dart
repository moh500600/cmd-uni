import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/utils/validators.dart';
import '../../domain/entities/entities.dart';
import '../providers/providers.dart';
import 'common.dart';

/// Files and links attached to an assignment / note / exam / project.
class AttachmentSection extends ConsumerWidget {
  final String ownerKind;
  final String ownerId;
  final String? courseId;
  final String titleKey;
  const AttachmentSection({super.key, required this.ownerKind, required this.ownerId, this.courseId, this.titleKey = 'attachments'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    final items = a?.resources.where((r) => r.ownerKind == ownerKind && r.ownerId == ownerId).toList() ?? <Resource>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          l.tr(titleKey),
          icon: Icons.attach_file_rounded,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(tooltip: l.tr('attach_file'), icon: const Icon(Icons.upload_file_rounded), onPressed: () => addFile(context, ref)),
              IconButton(tooltip: l.tr('add_link'), icon: const Icon(Icons.add_link_rounded), onPressed: () => addLink(context, ref)),
            ],
          ),
        ),
        if (items.isEmpty) Text(l.tr('no_attachments'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        for (final r in items) ResourceTile(r),
      ],
    );
  }

  Future<void> addFile(BuildContext context, WidgetRef ref) async {
    final fs = ref.read(fileServiceProvider);
    if (fs == null) return;
    try {
      final f = await fs.pick();
      if (f == null) return;
      await fs.addPicked(f, courseId: courseId, ownerKind: ownerKind, ownerId: ownerId);
    } catch (e) {
      if (context.mounted) toast(context, errorText(context, e));
    }
  }

  Future<void> addLink(BuildContext context, WidgetRef ref) async {
    final r = await askLink(context);
    if (r == null) return;
    await ref.read(fileServiceProvider)?.addLink(r.$2, title: r.$1, courseId: courseId, ownerKind: ownerKind, ownerId: ownerId);
  }
}

Future<(String, String)?> askLink(BuildContext context) async {
  final l = context.l;
  final t = TextEditingController(), u = TextEditingController();
  final key = GlobalKey<FormState>();
  return showDialog<(String, String)>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l.tr('add_link')),
      content: Form(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Field(t, l.tr('title')),
            Field(u, l.tr('url'), textDirection: TextDirection.ltr, keyboard: TextInputType.url, validator: (v) => V.required(v) ?? V.url(v)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(l.tr('cancel'))),
        FilledButton(
          onPressed: () {
            if (key.currentState!.validate()) Navigator.pop(c, (t.text.trim(), u.text.trim()));
          },
          child: Text(l.tr('save')),
        ),
      ],
    ),
  );
}

class ResourceTile extends ConsumerWidget {
  final Resource r;
  const ResourceTile(this.r, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    final size = r.sizeBytes == 0 ? '' : (r.sizeBytes > 1048576 ? '${(r.sizeBytes / 1048576).toStringAsFixed(1)} MB' : '${(r.sizeBytes / 1024).ceil()} KB');
    final sub = [
      if (a?.course(r.courseId) != null) a!.course(r.courseId)!.name,
      l.tr('rc_${r.category}'),
      if (size.isNotEmpty) size,
      if (!r.isLink) l.tr(r.storagePath == null ? 'file_local_only' : 'file_in_cloud'),
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Icon(fileIcon(r.fileType), color: Theme.of(context).colorScheme.primary),
        title: Text(
          r.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () async {
          try {
            await ref.read(fileServiceProvider)?.open(r);
          } catch (e) {
            if (context.mounted) toast(context, errorText(context, e));
          }
        },
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () async {
            if (await confirm(context, l.tr('delete_file_confirm'))) await ref.read(fileServiceProvider)?.remove(r);
          },
        ),
      ),
    );
  }
}
