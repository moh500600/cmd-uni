import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/errors/app_exception.dart';
import '../../core/utils/time.dart';
import '../../domain/services/academic.dart';

import 'package:decimal/decimal.dart';

import '../../domain/services/gpa.dart';
import '../repositories/uni_repository.dart';

/// Backup (JSON), CSV exports and the PDF academic record.
class ExportService {
  final UniRepository repo;
  ExportService(this.repo);

  static const format = 'uni_planner_backup';

  Future<Directory> _out() async {
    final d = Directory(p.join((await getTemporaryDirectory()).path, 'uni_exports'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  String get _stamp => dateKey(DateTime.now());

  Future<File> backupJson() async {
    final data = await repo.dump();
    final f = File(p.join((await _out()).path, 'uni_planner_backup_$_stamp.json'));
    await f.writeAsString(jsonEncode({'format': format, 'version': 1, 'exported_at': nowIso(), 'data': data}));
    return f;
  }

  /// Merges a backup file into this student's data. Returns the rows restored.
  Future<int> restoreJson(String text) async {
    final Map<String, dynamic> j;
    try {
      j = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw const AppException('err_bad_backup');
    }
    if (j['format'] != format || j['data'] is! Map) throw const AppException('err_bad_backup');
    return repo.restore(Map<String, dynamic>.from(j['data'] as Map));
  }

  static String _csvCell(Object? v) {
    final s = v?.toString() ?? '';
    return (s.contains(',') || s.contains('"') || s.contains('\n')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  static String csv(List<List<Object?>> rows) => '\uFEFF${rows.map((r) => r.map(_csvCell).join(',')).join('\r\n')}\r\n';

  Future<File> _write(String name, String body) async {
    final f = File(p.join((await _out()).path, name));
    await f.writeAsString(body);
    return f;
  }

  Future<File> gradesCsv(Academic a) async {
    final rows = <List<Object?>>[
      ['term', 'course_code', 'course', 'credit_hours', 'item', 'category', 'score', 'max', 'weight', 'date'],
    ];
    for (final c in a.courses) {
      final term = a.terms.where((t) => t.id == c.termId).firstOrNull?.name ?? '';
      for (final g in a.gradesOf(c.id)) {
        rows.add([
          term,
          c.code,
          c.name,
          c.creditHours,
          g.title,
          g.category,
          g.score,
          g.maxScore,
          g.weight ?? '',
          g.gradedOn == null ? '' : dateKey(g.gradedOn!),
        ]);
      }
    }
    return _write('grades_$_stamp.csv', csv(rows));
  }

  Future<File> assignmentsCsv(Academic a) async {
    final now = DateTime.now();
    final rows = <List<Object?>>[
      ['course', 'title', 'status', 'due', 'priority', 'progress', 'score', 'max', 'submitted_at'],
    ];
    for (final x in a.assignments) {
      rows.add([
        a.course(x.courseId)?.name ?? '',
        x.title,
        effectiveStatus(x, now),
        x.dueAt?.toIso8601String() ?? '',
        x.priority,
        a.progressOf(x),
        x.score ?? '',
        x.maxGrade ?? '',
        x.submittedAt?.toIso8601String() ?? '',
      ]);
    }
    return _write('assignments_$_stamp.csv', csv(rows));
  }

  Future<File> attendanceCsv(Academic a) async {
    final rows = <List<Object?>>[
      ['course', 'date', 'status', 'note'],
    ];
    for (final r in a.attendance) {
      rows.add([a.course(r.courseId)?.name ?? '', dateKey(r.onDate), r.status, r.note]);
    }
    return _write('attendance_$_stamp.csv', csv(rows));
  }

  /// The academic record (transcript) as a PDF, in the app's language.
  Future<File> transcriptPdf(Academic a, {required bool arabic, required String Function(String) tr}) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    final dir = arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final pr = a.profile;
    String fmt(Decimal? d) => d == null ? '—' : roundTo(d).toString();
    final cum = a.cumulative;
    final terms = [...a.terms];
    doc.addPage(
      pw.MultiPage(
        textDirection: dir,
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Text(tr('transcript'), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text([pr.fullName, pr.studentNumber, pr.university, pr.college, pr.major].where((e) => e.isNotEmpty).join(' · ')),
          pw.SizedBox(height: 4),
          pw.Text('${tr('cumulative_gpa')}: ${fmt(cum.gpa)}   ${tr('earned_hours')}: ${cum.earnedHours}   ${tr('gpa_system')}: ${pr.gpaSystem}'),
          pw.SizedBox(height: 14),
          for (final t in [...terms, null])
            ...() {
              final courses = a.courses.where((c) => c.termId == t?.id).toList();
              if (courses.isEmpty) return <pw.Widget>[];
              final s = a.termGpa(t?.id);
              return <pw.Widget>[
                pw.Text('${t?.name ?? tr('no_term')} — ${tr('term_gpa')}: ${fmt(s.gpa)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.SizedBox(height: 4),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.center,
                  headers: [tr('course_code'), tr('course'), tr('credit_hours'), tr('percent'), tr('grade'), tr('points')],
                  data: [
                    for (final c in courses)
                      () {
                        final g = a.gradedOf(c);
                        return [
                          c.code,
                          c.name,
                          c.creditHours.toString(),
                          a.percentOf(c) == null ? '—' : roundTo(a.percentOf(c)!).toString(),
                          g?.band.letter ?? '—',
                          g == null || a.scale.isPercentage ? '—' : g.points.toString(),
                        ];
                      }(),
                  ],
                ),
                pw.SizedBox(height: 12),
              ];
            }(),
          pw.SizedBox(height: 8),
          pw.Text('${tr('generated_by')} — ${dateKey(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ],
      ),
    );
    final f = File(p.join((await _out()).path, 'transcript_$_stamp.pdf'));
    await f.writeAsBytes(await doc.save());
    return f;
  }
}
