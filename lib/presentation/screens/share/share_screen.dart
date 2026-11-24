import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/platform/desktop_files.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

/// Sharing without a server: export a file, send it by any app, the other
/// person imports it here (merged into their own data).
class ShareScreen extends ConsumerWidget {
  const ShareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.tr('nav_groups'))),
      body: PageList(
        children: [
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l.tr('share_file_note')))),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.ios_share_rounded),
                  title: Text(l.tr('share_export')),
                  subtitle: Text(l.tr('share_export_sub')),
                  onTap: () async {
                    final e = ref.read(exportServiceProvider);
                    if (e == null) return;
                    try {
                      final f = await e.backupJson();
                      if (context.mounted) await shareOrSaveFile(context, f);
                    } catch (err) {
                      if (context.mounted) toast(context, errorText(context, err));
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.file_open_rounded),
                  title: Text(l.tr('share_import')),
                  subtitle: Text(l.tr('share_import_sub')),
                  onTap: () async {
                    final fs = ref.read(fileServiceProvider), ex = ref.read(exportServiceProvider);
                    if (fs == null || ex == null) return;
                    final f = await fs.pick(extensions: ['json']);
                    if (f == null || !context.mounted) return;
                    try {
                      final n = await ex.restoreJson(utf8.decode(await f.readAsBytes()));
                      if (context.mounted) toast(context, l.tr('restored_n', {'n': '$n'}));
                    } catch (err) {
                      if (context.mounted) toast(context, errorText(context, err));
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
