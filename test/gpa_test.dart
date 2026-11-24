import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_planner/domain/services/gpa.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  group('CourseTotal', () {
    test('raw marks that add up to 100', () {
      final t = CourseTotal.of([
        GradeComponent(d('8'), d('10')), // assignments
        GradeComponent(d('17'), d('20')), // midterm
        GradeComponent(d('10'), d('10')), // attendance
        GradeComponent(d('51'), d('60')), // final
      ]);
      expect(t.earned, d('86'));
      expect(t.possible, d('100'));
      expect(t.percent, d('86'));
    });

    test('percentage weights', () {
      final t = CourseTotal.of([
        GradeComponent(d('45'), d('50'), d('30')), // 90% of 30 = 27
        GradeComponent(d('70'), d('100'), d('70')), // 70% of 70 = 49
      ]);
      expect(t.earned, d('76'));
      expect(t.percent, d('76'));
    });

    test('standing so far is relative to what was graded', () {
      final t = CourseTotal.of([GradeComponent(d('18'), d('20'))]);
      expect(t.percent, d('90'));
      expect(t.possible, d('20'));
    });

    test('no float drift: 0.1 + 0.2 style sums stay exact', () {
      final t = CourseTotal.of([GradeComponent(d('0.1'), d('1'), d('1')), GradeComponent(d('0.2'), d('1'), d('1'))]);
      expect(t.earned, d('0.3'));
    });

    test('repeating decimals keep enough precision and round half-up', () {
      final t = CourseTotal.of([GradeComponent(d('2'), d('3'))]);
      expect(roundTo(t.percent!), d('66.67'));
      expect(roundTo(d('3.145')), d('3.15'));
      expect(roundTo(d('3.144')), d('3.14'));
    });

    test('empty / zero max are ignored', () {
      expect(CourseTotal.of([]).percent, isNull);
      expect(CourseTotal.of([GradeComponent(d('5'), d('0'))]).percent, isNull);
    });

    test('needed on the rest', () {
      // 40 of 50 earned so far; 50 still to come; target 85 overall → need 45/50 = 90%
      final t = CourseTotal.of([GradeComponent(d('40'), d('50'))]);
      expect(t.neededOnRest(d('85'), d('50')), d('90'));
      expect(t.neededOnRest(d('85'), d('0')), isNull);
      // target already secured
      expect(t.neededOnRest(d('30'), d('50'))! <= Decimal.zero, isTrue);
    });
  });

  group('GradeScale', () {
    test('4-point bands', () {
      final s = GradeScale.defaults['4']!;
      expect(s.bandFor(d('100')).letter, 'A+');
      expect(s.bandFor(d('95')).letter, 'A+');
      expect(s.bandFor(d('94.999')).letter, 'A');
      expect(s.bandFor(d('60')).letter, 'D');
      expect(s.bandFor(d('59.99')).letter, 'F');
      expect(s.bandFor(d('59.99')).passing, isFalse);
      expect(s.maxPoints, d('4'));
    });

    test('5-point bands (F = 1)', () {
      final s = GradeScale.defaults['5']!;
      expect(s.bandFor(d('92')).points, d('4.75'));
      expect(s.bandFor(d('10')).points, d('1'));
      expect(s.maxPoints, d('5'));
    });

    test('percentage system ratings', () {
      final s = GradeScale.defaults['100']!;
      expect(s.bandFor(d('90')).letter, 'ممتاز');
      expect(s.bandFor(d('79.9')).letter, 'جيد');
      expect(s.bandFor(d('49.9')).passing, isFalse);
    });

    test('custom scale round-trips through JSON and is validated', () {
      final custom = GradeScale('4', [GradeBand(d('90'), 'A', d('4')), GradeBand(d('0'), 'F', d('0'), passing: false)]);
      final back = GradeScale.resolve('4', custom.toJsonString());
      expect(back.bands.length, 2);
      expect(back.bandFor(d('89')).letter, 'F');
      // invalid custom scale (no 0 band) falls back to the default
      final bad = GradeScale('4', [GradeBand(d('90'), 'A', d('4'))]).toJsonString();
      expect(GradeScale.resolve('4', bad).bands.length, 9);
      // a custom scale saved for another system is ignored
      expect(GradeScale.resolve('5', custom.toJsonString()).system, '5');
      expect(GradeScale.validate([GradeBand(d('0'), 'F', d('0')), GradeBand(d('0'), 'E', d('0'))]), 'scale_duplicate_min');
      expect(GradeScale.validate([GradeBand(d('0'), ' ', d('0'))]), 'scale_letter');
      expect(GradeScale.validate([GradeBand(d('0'), 'F', d('0')), GradeBand(d('101'), 'X', d('0'))]), 'scale_range');
    });
  });

  group('GpaCalculator', () {
    final calc4 = GpaCalculator(GradeScale.defaults['4']!);

    test('credit-hour weighted term GPA', () {
      final s = calc4.summarize([
        CourseResult(id: 'a', hours: d('3'), percent: d('96')), // 4.0 × 3 = 12
        CourseResult(id: 'b', hours: d('4'), percent: d('82')), // 3.0 × 4 = 12
        CourseResult(id: 'c', hours: d('2'), percent: d('71')), // 2.0 × 2 = 4
      ]);
      // 28 / 9 = 3.111…
      expect(s.qualityPoints, d('28'));
      expect(s.hours, d('9'));
      expect(roundTo(s.gpa!), d('3.11'));
      expect(s.earnedHours, d('9'));
    });

    test('failed course counts in GPA but not in earned hours', () {
      final s = calc4.summarize([
        CourseResult(id: 'a', hours: d('3'), percent: d('90')), // 3.75
        CourseResult(id: 'b', hours: d('3'), percent: d('40')), // 0
      ]);
      expect(s.gpa, d('1.875'));
      expect(s.earnedHours, d('3'));
      expect(s.hours, d('6'));
    });

    test('excluded / ungraded courses are skipped', () {
      final s = calc4.summarize([
        CourseResult(id: 'a', hours: d('3'), percent: d('85')),
        CourseResult(id: 'b', hours: d('3'), percent: d('50'), included: false),
        CourseResult(id: 'c', hours: d('3')),
      ]);
      expect(s.gpa, d('3.5'));
      expect(s.courses.length, 2);
    });

    test('letter override wins over the percent', () {
      final g = calc4.grade(CourseResult(id: 'a', hours: d('3'), percent: d('70'), letterOverride: 'b+'))!;
      expect(g.band.letter, 'B+');
      expect(g.points, d('3.5'));
      expect(calc4.grade(CourseResult(id: 'x', hours: d('3'), letterOverride: 'ZZ')), isNull);
    });

    test('cumulative folds in the prior record', () {
      final s = calc4.summarize(
        [CourseResult(id: 'a', hours: d('3'), percent: d('96'))],
        priorHours: d('30'),
        priorGpa: d('3.2'),
      );
      // (3.2×30 + 4×3) / 33 = 108/33 = 3.2727…
      expect(roundTo(s.gpa!), d('3.27'));
      expect(s.hours, d('33'));
      expect(s.earnedHours, d('33'));
    });

    test('5-point system', () {
      final calc5 = GpaCalculator(GradeScale.defaults['5']!);
      final s = calc5.summarize([
        CourseResult(id: 'a', hours: d('3'), percent: d('95')), // 5
        CourseResult(id: 'b', hours: d('3'), percent: d('86')), // 4.5
      ]);
      expect(s.gpa, d('4.75'));
    });

    test('percentage system: credit-weighted average percent', () {
      final calcP = GpaCalculator(GradeScale.defaults['100']!);
      final s = calcP.summarize([CourseResult(id: 'a', hours: d('3'), percent: d('90')), CourseResult(id: 'b', hours: d('2'), percent: d('75.5'))]);
      // (270 + 151) / 5 = 84.2
      expect(s.gpa, d('84.2'));
      expect(calcP.grade(CourseResult(id: 'b', hours: d('2'), percent: d('75.5')))!.band.letter, 'جيد');
    });

    test('no graded hours → no GPA', () {
      expect(calc4.summarize([]).gpa, isNull);
      expect(calc4.summarize([CourseResult(id: 'a', hours: d('0'), percent: d('99'))]).gpa, isNull);
    });

    test('needed term GPA to reach a target', () {
      final cur = calc4.summarize([CourseResult(id: 'a', hours: d('30'), percent: d('80'))]); // 3.0 over 30h
      // to reach 3.2 over 45h: (3.2×45 − 90) / 15 = 3.6
      expect(calc4.neededTermGpa(current: cur, nextHours: d('15'), target: d('3.2')), d('3.6'));
      expect(calc4.neededTermGpa(current: cur, nextHours: d('0'), target: d('3.2')), isNull);
    });
  });
}
