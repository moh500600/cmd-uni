import 'package:decimal/decimal.dart';

import '../../core/utils/time.dart';

/// Column types shared by the local SQLite schema and the server (`uni` schema).
enum ColType { uuid, text, integer, boolean, decimal, date, timestamp }

class Col {
  final String name;
  final ColType type;
  final bool nullable;
  final Object? def;
  const Col(this.name, this.type, {this.nullable = false, this.def});

  String get sqliteType => switch (type) {
    ColType.integer || ColType.boolean => 'INTEGER',
    _ => 'TEXT',
  };

  /// Default for a non-null column when a row does not set it.
  Object? get localDefault {
    if (def != null) return def;
    if (nullable) return null;
    return switch (type) {
      ColType.text => '',
      ColType.boolean || ColType.integer => 0,
      ColType.decimal => '0',
      _ => null,
    };
  }
}

/// One synced table. Every table also has the common columns
/// id, user_id, created_at, updated_at, deleted (+ local `dirty`).
class TableDef {
  final String name;
  final List<Col> cols;
  const TableDef(this.name, this.cols);

  static const common = [
    Col('id', ColType.uuid),
    Col('user_id', ColType.text),
    Col('created_at', ColType.timestamp),
    Col('updated_at', ColType.timestamp),
    Col('deleted', ColType.boolean),
  ];

  List<Col> get allCols => [...common, ...cols];

  String createSql() {
    final b = StringBuffer(
      'CREATE TABLE IF NOT EXISTS $name (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, '
      'created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1',
    );
    for (final c in cols) {
      b.write(', ${c.name} ${c.sqliteType}');
      if (!c.nullable) {
        final d = c.localDefault;
        b.write(' NOT NULL');
        if (d != null) b.write(d is String ? " DEFAULT '${d.replaceAll("'", "''")}'" : ' DEFAULT $d');
      }
    }
    b.write(')');
    return b.toString();
  }

  /// Local row → JSON for the server (drops `dirty`; booleans become true/false).
  Map<String, Object?> toRemote(Map<String, Object?> row) {
    final out = <String, Object?>{};
    for (final c in allCols) {
      final v = row[c.name];
      out[c.name] = switch (c.type) {
        ColType.boolean => v == null ? (c.nullable ? null : false) : (v == 1 || v == true),
        ColType.decimal => v?.toString(),
        _ => v,
      };
    }
    return out;
  }

  /// Server JSON → local row (normalised timestamps, decimals as exact text).
  Map<String, Object?> fromRemote(Map<String, dynamic> json) {
    final out = <String, Object?>{};
    for (final c in allCols) {
      if (!json.containsKey(c.name)) continue;
      final v = json[c.name];
      out[c.name] = switch (c.type) {
        ColType.boolean => v == true ? 1 : 0,
        ColType.integer => v == null ? null : (v as num).toInt(),
        ColType.decimal => v == null ? null : _decText(v),
        ColType.timestamp => normalizeIso(v),
        ColType.date => v?.toString().substring(0, 10),
        _ => v?.toString(),
      };
    }
    return out;
  }

  static String _decText(Object v) {
    final d = Decimal.tryParse(v.toString());
    return d == null ? v.toString() : d.toString();
  }
}

const _t = ColType.text, _i = ColType.integer, _b = ColType.boolean, _d = ColType.decimal, _u = ColType.uuid;
const _date = ColType.date, _ts = ColType.timestamp;

/// Every synced table, parents before children (push order).
const kTables = <TableDef>[
  TableDef('profiles', [
    Col('full_name', _t),
    Col('student_number', _t),
    Col('university', _t),
    Col('college', _t),
    Col('department', _t),
    Col('major', _t),
    Col('level', _t),
    Col('academic_year', _t),
    Col('current_term_id', _u, nullable: true),
    Col('prior_hours', _d),
    Col('prior_gpa', _d, nullable: true),
    Col('gpa_system', _t, def: '4'),
    Col('grade_scale', _t),
    Col('late_per_absence', _i, def: 3),
    Col('absence_limit_pct', _d, def: '25'),
    Col('week_start', _i, def: 6),
  ]),
  TableDef('terms', [Col('name', _t), Col('start_date', _date, nullable: true), Col('end_date', _date, nullable: true), Col('position', _i), Col('notes', _t)]),
  TableDef('courses', [
    Col('term_id', _u, nullable: true),
    Col('name', _t),
    Col('code', _t),
    Col('instructor', _t),
    Col('department', _t),
    Col('credit_hours', _d, def: '3'),
    Col('color', _i),
    Col('description', _t),
    Col('references_text', _t),
    Col('links', _t),
    Col('status', _t, def: 'ongoing'),
    Col('archived', _b),
    Col('total_lectures', _i),
    Col('absence_limit_pct', _d, nullable: true),
    Col('final_percent', _d, nullable: true),
    Col('final_letter', _t, nullable: true),
    Col('include_in_gpa', _b, def: 1),
  ]),
  TableDef('course_units', [Col('course_id', _u), Col('title', _t), Col('position', _i), Col('difficulty', _i, def: 2), Col('done', _b)]),
  TableDef('class_sessions', [
    Col('course_id', _u),
    Col('weekday', _i),
    Col('start_min', _i),
    Col('end_min', _i),
    Col('room', _t),
    Col('instructor', _t),
    Col('kind', _t, def: 'lecture'),
    Col('mode', _t, def: 'in_person'),
    Col('link', _t),
    Col('reminder_min', _i, nullable: true),
  ]),
  TableDef('assignments', [
    Col('course_id', _u, nullable: true),
    Col('title', _t),
    Col('description', _t),
    Col('assigned_on', _date, nullable: true),
    Col('due_at', _ts, nullable: true),
    Col('priority', _i, def: 1),
    Col('max_grade', _d, nullable: true),
    Col('score', _d, nullable: true),
    Col('progress', _i),
    Col('status', _t, def: 'not_started'),
    Col('submitted_at', _ts, nullable: true),
    Col('links', _t),
    Col('solution_note', _t),
    Col('reminder_min', _i, nullable: true),
  ]),
  TableDef('exams', [
    Col('course_id', _u, nullable: true),
    Col('title', _t),
    Col('kind', _t, def: 'quiz'),
    Col('starts_at', _ts, nullable: true),
    Col('duration_min', _i, def: 60),
    Col('location', _t),
    Col('max_grade', _d, nullable: true),
    Col('score', _d, nullable: true),
    Col('topics', _t),
    Col('notes', _t),
    Col('reminder_min', _i, nullable: true),
  ]),
  TableDef('projects', [
    Col('course_id', _u, nullable: true),
    Col('title', _t),
    Col('description', _t),
    Col('supervisor', _t),
    Col('team', _t),
    Col('is_group', _b),
    Col('start_on', _date, nullable: true),
    Col('due_on', _date, nullable: true),
    Col('status', _t, def: 'active'),
  ]),
  TableDef('project_phases', [Col('project_id', _u), Col('title', _t), Col('due_on', _date, nullable: true), Col('position', _i), Col('done', _b)]),
  TableDef('subtasks', [
    Col('parent_kind', _t),
    Col('parent_id', _u),
    Col('phase_id', _u, nullable: true),
    Col('title', _t),
    Col('assignee', _t),
    Col('due_on', _date, nullable: true),
    Col('done', _b),
    Col('position', _i),
  ]),
  TableDef('grade_items', [
    Col('course_id', _u),
    Col('category', _t, def: 'exam'),
    Col('title', _t),
    Col('score', _d),
    Col('max_score', _d, def: '100'),
    Col('weight', _d, nullable: true),
    Col('graded_on', _date, nullable: true),
    Col('source_kind', _t, nullable: true),
    Col('source_id', _u, nullable: true),
  ]),
  TableDef('attendance', [Col('course_id', _u), Col('session_id', _u, nullable: true), Col('on_date', _date), Col('status', _t), Col('note', _t)]),
  TableDef('notes', [
    Col('course_id', _u, nullable: true),
    Col('title', _t),
    Col('lecture_title', _t),
    Col('lecture_on', _date, nullable: true),
    Col('body', _t),
    Col('key_points', _t),
    Col('summary', _t),
    Col('category', _t),
    Col('links', _t),
    Col('pinned', _b),
    Col('archived', _b),
  ]),
  TableDef('resources', [
    Col('course_id', _u, nullable: true),
    Col('title', _t),
    Col('category', _t, def: 'other'),
    Col('file_type', _t, def: 'other'),
    Col('file_name', _t),
    Col('storage_path', _t, nullable: true),
    Col('url', _t),
    Col('size_bytes', _i),
    Col('owner_kind', _t, nullable: true),
    Col('owner_id', _u, nullable: true),
    Col('notes', _t),
  ]),
  TableDef('study_sessions', [
    Col('course_id', _u, nullable: true),
    Col('unit_id', _u, nullable: true),
    Col('title', _t),
    Col('planned_on', _date),
    Col('start_min', _i, nullable: true),
    Col('planned_min', _i),
    Col('actual_min', _i),
    Col('difficulty', _i, def: 2),
    Col('done', _b),
    Col('source', _t, def: 'plan'),
    Col('notes', _t),
  ]),
  TableDef('events', [
    Col('course_id', _u, nullable: true),
    Col('title', _t),
    Col('kind', _t, def: 'event'),
    Col('starts_at', _ts),
    Col('ends_at', _ts, nullable: true),
    Col('all_day', _b),
    Col('location', _t),
    Col('notes', _t),
    Col('reminder_min', _i, nullable: true),
  ]),
  TableDef('activity_log', [Col('entity_kind', _t), Col('entity_id', _u, nullable: true), Col('action', _t), Col('detail', _t)]),
];

TableDef tableDef(String name) => kTables.firstWhere((t) => t.name == name);
