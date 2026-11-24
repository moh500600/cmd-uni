import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

/// Academic terms (semesters) and which one is current.
class TermsScreen extends ConsumerWidget {
  const TermsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    final terms = [...?a?.terms]..sort((x, y) => y.position.compareTo(x.position));
    return Scaffold(
      appBar: AppBar(title: Text(l.tr('terms'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'term_add',
        onPressed: () => _edit(context, ref, null, terms.length),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.tr('add_term')),
      ),
      body: PageList(
        children: [
          if (terms.isEmpty) EmptyState(icon: Icons.date_range_rounded, title: l.tr('no_terms'), subtitle: l.tr('terms_hint')),
          for (final t in terms)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(a?.currentTerm?.id == t.id ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: AppColors.primary),
                title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text([if (t.startDate != null) l.date(t.startDate!), if (t.endDate != null) l.date(t.endDate!)].join(' → ')),
                onTap: () => ref.read(repoProvider)!.save('profiles', {'id': a!.uid, 'current_term_id': t.id}),
                trailing: IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () => _edit(context, ref, t, terms.length)),
              ),
            ),
          if (terms.isNotEmpty) Text(l.tr('tap_to_make_current'), style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Term? t, int count) async {
    final l = context.l;
    final name = TextEditingController(text: t?.name ?? '');
    DateTime? s = t?.startDate, e = t?.endDate;
    final r = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(l.tr(t == null ? 'add_term' : 'edit_term')),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l.tr('term_name'), hintText: l.tr('term_name_hint')),
                ),
                const SizedBox(height: 12),
                DateTimeField(label: l.tr('start_date'), value: s, onChanged: (v) => set(() => s = v)),
                DateTimeField(label: l.tr('end_date'), value: e, onChanged: (v) => set(() => e = v)),
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
    if (r == 'delete' && t != null && context.mounted && await confirm(context, l.tr('delete_term_confirm'))) await repo.delete('terms', t.id);
    if (r == 'save') {
      if (name.text.trim().isEmpty) return;
      if (s != null && e != null && e!.isBefore(s!)) {
        if (context.mounted) toast(context, l.tr('err_end_before_start'));
        return;
      }
      final id = await repo.save('terms', {
        'id': t?.id,
        'name': name.text.trim(),
        'start_date': s == null ? null : dateKey(s!),
        'end_date': e == null ? null : dateKey(e!),
        if (t == null) 'position': count,
      });
      final a = ref.read(academicProvider).value;
      if (t == null && a != null) await repo.save('profiles', {'id': a.uid, 'current_term_id': id});
    }
  }
}
