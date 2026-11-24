import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/ids.dart';
import '../../domain/entities/entities.dart';
import '../repositories/uni_repository.dart';

/// File type from a file name's extension.
String fileTypeOf(String name) {
  final e = p.extension(name).toLowerCase().replaceFirst('.', '');
  return switch (e) {
    'pdf' => 'pdf',
    'doc' || 'docx' || 'odt' || 'rtf' || 'txt' => 'word',
    'ppt' || 'pptx' || 'odp' || 'key' => 'ppt',
    'xls' || 'xlsx' || 'ods' || 'csv' => 'excel',
    'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' || 'heic' || 'bmp' => 'image',
    'mp3' || 'm4a' || 'wav' || 'aac' || 'ogg' || 'opus' || 'amr' || 'flac' => 'audio',
    _ => 'other',
  };
}

const kMaxFileBytes = 50 * 1024 * 1024; // the bucket's limit

/// Course files on the device, kept on the device only.
class FileService {
  final UniRepository repo;
  FileService(this.repo);

  static Future<Directory> filesDir() async {
    final d = Directory(p.join((await getApplicationSupportDirectory()).path, 'uni_files'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static String _ext(String name) {
    final e = p.extension(name).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(e) ? e : '';
  }

  Future<File> localFile(Resource r) async => File(p.join((await filesDir()).path, '${r.id}${_ext(r.fileName)}'));

  /// Asks the student for a file. Null when cancelled.
  Future<PlatformFile?> pick({List<String>? extensions}) =>
      FilePicker.pickFile(type: extensions == null ? FileType.any : FileType.custom, allowedExtensions: extensions);

  /// Stores a picked file as a resource (optionally attached to an assignment, note…).
  Future<String> addPicked(
    PlatformFile f, {
    String? title,
    String? courseId,
    String category = 'other',
    String? ownerKind,
    String? ownerId,
    String notes = '',
  }) async {
    final bytes = await f.readAsBytes();
    return addBytes(f.name, bytes, title: title, courseId: courseId, category: category, ownerKind: ownerKind, ownerId: ownerId, notes: notes);
  }

  Future<String> addBytes(
    String name,
    Uint8List bytes, {
    String? title,
    String? courseId,
    String category = 'other',
    String? ownerKind,
    String? ownerId,
    String notes = '',
  }) async {
    if (bytes.length > kMaxFileBytes) throw const AppException('err_file_too_big');
    final id = newId();
    final file = File(p.join((await filesDir()).path, '$id${_ext(name)}'));
    await file.writeAsBytes(bytes, flush: true);
    await repo.save('resources', {
      'id': id,
      'title': (title == null || title.trim().isEmpty) ? p.basenameWithoutExtension(name) : title.trim(),
      'file_name': name,
      'file_type': fileTypeOf(name),
      'size_bytes': bytes.length,
      'course_id': courseId,
      'category': category,
      'owner_kind': ownerKind,
      'owner_id': ownerId,
      'notes': notes,
    });
    return id;
  }

  Future<String> addLink(String url, {required String title, String? courseId, String category = 'other', String? ownerKind, String? ownerId}) =>
      repo.save('resources', {
        'title': title.trim().isEmpty ? url : title.trim(),
        'url': url.trim(),
        'file_type': 'link',
        'course_id': courseId,
        'category': category,
        'owner_kind': ownerKind,
        'owner_id': ownerId,
      });

  /// The file's bytes: from the device, .
  Future<Uint8List> bytes(Resource r) async {
    final f = await localFile(r);
    if (await f.exists()) return f.readAsBytes();
    throw const AppException('err_file_missing');
  }

  Future<bool> isLocal(Resource r) async => (await localFile(r)).exists();

  Future<void> open(Resource r) async {
    if (r.isLink) {
      final u = Uri.tryParse(r.url);
      if (u == null || !await launchUrl(u, mode: LaunchMode.externalApplication)) throw const AppException('err_open_link');
      return;
    }
    await bytes(r);
    final f = await localFile(r);
    final res = await OpenFilex.open(f.path);
    if (res.type != ResultType.done) throw AppException('err_open_file', res.message);
  }

  Future<void> remove(Resource r) async {
    final f = await localFile(r);
    if (await f.exists()) await f.delete();
    await repo.delete('resources', r.id);
  }
}
