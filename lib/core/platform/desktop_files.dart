import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';
import 'platform_support.dart';

/// Shares an exported file (PDF, CSV, JSON backup…).
///
/// Android/iOS: the system share sheet. Windows/Linux: a "Save as…" dialog,
/// then a snackbar with an "Open" button.
Future<void> shareOrSaveFile(BuildContext context, File file, {String? text, String? subject}) async {
  if (PlatformSupport.shareFiles) {
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: text, subject: subject));
    return;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  final openLabel = context.tr('open_file');
  final uri = await FilePicker.saveFile(fileName: p.basename(file.path), bytes: await file.readAsBytes(), dialogTitle: subject ?? text);
  if (uri == null) return;
  final path = uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
  if (!context.mounted) return;
  final msg = context.tr('saved_to', {'path': path});
  messenger?.showSnackBar(
    SnackBar(
      content: Text(msg),
      action: SnackBarAction(label: openLabel, onPressed: () => OpenFilex.open(path)),
    ),
  );
}
