import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uni_planner/core/l10n/strings.dart';

/// Every literal key passed to tr('…') in lib/ must exist in both languages,
/// with the same {placeholders}. Dynamic keys (tr('st_$s')) are covered by the
/// screen tests, which fail on any key L10n reports missing.
void main() {
  test('every string has Arabic and English with matching placeholders', () {
    final ph = RegExp(r'\{(\w+)\}');
    for (final e in kStrings.entries) {
      expect(e.value.length, 2, reason: e.key);
      expect(e.value[0].trim(), isNotEmpty, reason: '${e.key} ar');
      expect(e.value[1].trim(), isNotEmpty, reason: '${e.key} en');
      final a = ph.allMatches(e.value[0]).map((m) => m[1]).toSet();
      final b = ph.allMatches(e.value[1]).map((m) => m[1]).toSet();
      expect(a, b, reason: 'placeholders of ${e.key}');
    }
  });

  test('every literal tr key used in lib/ is translated', () {
    final re = RegExp(r"""\btr\(\s*'([^'$]+)'""");
    final missing = <String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      for (final m in re.allMatches(f.readAsStringSync())) {
        if (!kStrings.containsKey(m[1])) missing.add('${m[1]} (${f.path})');
      }
    }
    expect(missing, isEmpty);
  });

  test('every enum-like value has a label', () {
    final families = {
      'st_': ['not_started', 'in_progress', 'completed', 'submitted', 'late', 'cancelled'],
      'ek_': ['quiz', 'monthly', 'midterm', 'final', 'practical', 'oral'],
      'ps_': ['planning', 'active', 'review', 'done', 'cancelled'],
      'gc_': ['quiz', 'exam', 'midterm', 'final', 'assignment', 'participation', 'project', 'lab', 'other'],
      'att_': ['present', 'absent', 'late', 'excused'],
      'rc_': ['book', 'lecture', 'handout', 'summary', 'research', 'project', 'exam_sample', 'other'],
      'ft_': ['pdf', 'word', 'ppt', 'excel', 'image', 'audio', 'link', 'other'],
      'evk_': ['meeting', 'event', 'deadline', 'other'],
      'sk_': ['lecture', 'lab', 'tutorial', 'seminar'],
      'kind_': ['lecture', 'assignment', 'exam', 'project', 'study', 'event'],
      'cs_': ['ongoing', 'completed', 'withdrawn'],
      'prio_': ['0', '1', '2', '3'],
      'diff_': ['1', '2', '3'],
      'sys_': ['4', '5', '100', '4_hint', '5_hint', '100_hint'],
    };
    for (final f in families.entries) {
      for (final v in f.value) {
        expect(kStrings.containsKey('${f.key}$v'), isTrue, reason: '${f.key}$v');
      }
    }
  });
}
