import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

/// Exact academic math (no floating point): grade scales, course totals,
/// term GPA, cumulative GPA, earned hours and "what do I need" targets.
///
/// Every number is a [Decimal] / [Rational]; results are rounded half-up only
/// for display (see [roundTo]).

Decimal dec(Object v) => Decimal.parse(v.toString());
Rational _r(Decimal d) => d.toRational();
Decimal _toDec(Rational r) => r.toDecimal(scaleOnInfinitePrecision: 12);

/// Half-up rounding for display: 3.145 → 3.15.
Decimal roundTo(Decimal d, [int scale = 2]) => d.round(scale: scale);

/// One band of a grade scale: a percentage from [min] up to the next band's min.
class GradeBand {
  final Decimal min; // inclusive lower bound, in percent
  final String letter;
  final Decimal points; // grade points on the 4/5 scale (ignored by the percentage system)
  final bool passing;
  const GradeBand(this.min, this.letter, this.points, {this.passing = true});

  Map<String, Object> toJson() => {'min': min.toString(), 'letter': letter, 'points': points.toString(), 'pass': passing};
  static GradeBand fromJson(Map<String, dynamic> j) => GradeBand(dec(j['min']), j['letter'].toString(), dec(j['points'] ?? 0), passing: j['pass'] != false);
}

/// A university's grading system.
///
/// * `'4'`   — 4-point GPA (A+ 4.0 … F 0)
/// * `'5'`   — 5-point GPA (A+ 5.0 … D 2.0, F 1.0 as in many Saudi universities)
/// * `'100'` — percentage system (Yemen and others): the "GPA" is the
///             credit-weighted average percentage; letters are the Arabic ratings.
class GradeScale {
  final String system;
  final List<GradeBand> bands; // sorted by min, highest first
  GradeScale(this.system, List<GradeBand> bands) : bands = [...bands]..sort((a, b) => b.min.compareTo(a.min));

  bool get isPercentage => system == '100';
  Decimal get maxPoints => isPercentage ? Decimal.fromInt(100) : (bands.isEmpty ? Decimal.zero : bands.map((b) => b.points).reduce((a, b) => a > b ? a : b));

  static final Map<String, GradeScale> defaults = {
    '4': GradeScale('4', [
      GradeBand(dec(95), 'A+', dec('4.0')),
      GradeBand(dec(90), 'A', dec('3.75')),
      GradeBand(dec(85), 'B+', dec('3.5')),
      GradeBand(dec(80), 'B', dec('3.0')),
      GradeBand(dec(75), 'C+', dec('2.5')),
      GradeBand(dec(70), 'C', dec('2.0')),
      GradeBand(dec(65), 'D+', dec('1.5')),
      GradeBand(dec(60), 'D', dec('1.0')),
      GradeBand(dec(0), 'F', dec('0'), passing: false),
    ]),
    '5': GradeScale('5', [
      GradeBand(dec(95), 'A+', dec('5.0')),
      GradeBand(dec(90), 'A', dec('4.75')),
      GradeBand(dec(85), 'B+', dec('4.5')),
      GradeBand(dec(80), 'B', dec('4.0')),
      GradeBand(dec(75), 'C+', dec('3.5')),
      GradeBand(dec(70), 'C', dec('3.0')),
      GradeBand(dec(65), 'D+', dec('2.5')),
      GradeBand(dec(60), 'D', dec('2.0')),
      GradeBand(dec(0), 'F', dec('1.0'), passing: false),
    ]),
    '100': GradeScale('100', [
      GradeBand(dec(90), 'ممتاز', dec(0)),
      GradeBand(dec(80), 'جيد جداً', dec(0)),
      GradeBand(dec(65), 'جيد', dec(0)),
      GradeBand(dec(50), 'مقبول', dec(0)),
      GradeBand(dec(0), 'راسب', dec(0), passing: false),
    ]),
  };

  /// The profile's scale: its custom JSON when set and valid, else the system default.
  static GradeScale resolve(String system, String customJson) {
    final sys = defaults.containsKey(system) ? system : '4';
    if (customJson.trim().isNotEmpty) {
      try {
        final j = jsonDecode(customJson) as Map<String, dynamic>;
        if (j['system'] == sys) {
          final bands = [for (final b in j['bands'] as List) GradeBand.fromJson(Map<String, dynamic>.from(b as Map))];
          if (validate(bands) == null) return GradeScale(sys, bands);
        }
      } catch (_) {}
    }
    return defaults[sys]!;
  }

  String toJsonString() => jsonEncode({
    'system': system,
    'bands': [for (final b in bands) b.toJson()],
  });

  /// Null when the bands make a usable scale, else an l10n key for the problem.
  static String? validate(List<GradeBand> bands) {
    if (bands.isEmpty) return 'scale_empty';
    final mins = bands.map((b) => b.min).toList();
    if (mins.toSet().length != mins.length) return 'scale_duplicate_min';
    if (!mins.any((m) => m == Decimal.zero)) return 'scale_needs_zero';
    if (mins.any((m) => m < Decimal.zero || m > Decimal.fromInt(100))) return 'scale_range';
    if (bands.any((b) => b.letter.trim().isEmpty)) return 'scale_letter';
    return null;
  }

  GradeBand bandFor(Decimal percent) {
    for (final b in bands) {
      if (percent >= b.min) return b;
    }
    return bands.last;
  }

  GradeBand? bandForLetter(String letter) {
    for (final b in bands) {
      if (b.letter.toLowerCase() == letter.trim().toLowerCase()) return b;
    }
    return null;
  }
}

/// One graded component of a course.
class GradeComponent {
  final Decimal score;
  final Decimal max;
  final Decimal? weight; // % of the course; null = raw marks (weight = max)
  const GradeComponent(this.score, this.max, [this.weight]);
}

/// A course total from its components.
///
/// Each component counts `score / max × w` where `w` is its weight, or its max
/// mark when no weight is given — so raw marks that add up to 100 (e.g.
/// assignments 10 + midterm 20 + attendance 10 + final 60) and percentage
/// weights both work, and so does a mix.
class CourseTotal {
  final Decimal earned; // points earned (in weight units)
  final Decimal possible; // weight of the components graded so far
  const CourseTotal(this.earned, this.possible);

  static CourseTotal of(Iterable<GradeComponent> items) {
    var earned = Rational.zero, possible = Rational.zero;
    for (final c in items) {
      if (c.max <= Decimal.zero) continue;
      final w = _r(c.weight ?? c.max);
      earned += _r(c.score) / _r(c.max) * w;
      possible += w;
    }
    return CourseTotal(_toDec(earned), _toDec(possible));
  }

  bool get isEmpty => possible == Decimal.zero;

  /// Standing so far, in percent of what has been graded (null when nothing is graded).
  Decimal? get percent => isEmpty ? null : _toDec(_r(earned) / _r(possible) * Rational.fromInt(100));

  /// Score needed on the [remainingWeight] still to come to finish at [targetPercent]
  /// of the full course, as a percent of that remaining part. Null when nothing remains.
  /// Above 100 means the target is out of reach; at or below 0, it is already secured.
  Decimal? neededOnRest(Decimal targetPercent, Decimal remainingWeight) {
    if (remainingWeight <= Decimal.zero) return null;
    final full = _r(possible) + _r(remainingWeight);
    final needed = _r(targetPercent) / Rational.fromInt(100) * full - _r(earned);
    return _toDec(needed / _r(remainingWeight) * Rational.fromInt(100));
  }
}

/// A finished (or in-progress) course as the GPA needs it.
class CourseResult {
  final String id;
  final Decimal hours;
  final Decimal? percent; // course total in percent
  final String? letterOverride;
  final bool included; // counts toward GPA (not withdrawn / excluded / pass-fail)
  const CourseResult({required this.id, required this.hours, this.percent, this.letterOverride, this.included = true});
}

class GradedCourse {
  final CourseResult course;
  final GradeBand band;
  final Decimal points; // 4/5 systems: grade points; percentage system: the percent
  const GradedCourse(this.course, this.band, this.points);
}

class GpaSummary {
  final Decimal? gpa; // exact; round for display
  final Decimal hours; // attempted hours that counted
  final Decimal earnedHours; // hours of passed courses
  final Decimal qualityPoints; // Σ points × hours
  final List<GradedCourse> courses;
  const GpaSummary(this.gpa, this.hours, this.earnedHours, this.qualityPoints, this.courses);
}

class GpaCalculator {
  final GradeScale scale;
  const GpaCalculator(this.scale);

  /// Grades one course; null when it has no result yet.
  GradedCourse? grade(CourseResult c) {
    GradeBand? band;
    Decimal? points;
    if (c.letterOverride != null && c.letterOverride!.trim().isNotEmpty) {
      band = scale.bandForLetter(c.letterOverride!);
      if (band != null) points = scale.isPercentage ? (c.percent ?? band.min) : band.points;
    }
    if (band == null && c.percent != null) {
      band = scale.bandFor(c.percent!);
      points = scale.isPercentage ? c.percent! : band.points;
    }
    if (band == null || points == null) return null;
    return GradedCourse(c, band, points);
  }

  /// GPA over [courses] (one term, or all of them), credit-hour weighted.
  /// [priorHours]/[priorGpa] fold in a record from before the app was used.
  GpaSummary summarize(Iterable<CourseResult> courses, {Decimal? priorHours, Decimal? priorGpa}) {
    var qp = Rational.zero, hours = Rational.zero, earned = Rational.zero;
    final graded = <GradedCourse>[];
    for (final c in courses) {
      final g = grade(c);
      if (g == null) continue;
      graded.add(g);
      if (!c.included || c.hours <= Decimal.zero) continue;
      qp += _r(g.points) * _r(c.hours);
      hours += _r(c.hours);
      if (g.band.passing) earned += _r(c.hours);
    }
    if (priorHours != null && priorHours > Decimal.zero && priorGpa != null) {
      qp += _r(priorGpa) * _r(priorHours);
      hours += _r(priorHours);
      earned += _r(priorHours);
    }
    final gpa = hours == Rational.zero ? null : _toDec(qp / hours);
    return GpaSummary(gpa, _toDec(hours), _toDec(earned), _toDec(qp), graded);
  }

  /// The term GPA needed over [nextHours] to lift the cumulative GPA to [target].
  /// Null when there are no next hours.
  Decimal? neededTermGpa({required GpaSummary current, required Decimal nextHours, required Decimal target}) {
    if (nextHours <= Decimal.zero) return null;
    final total = _r(current.hours) + _r(nextHours);
    return _toDec((_r(target) * total - _r(current.qualityPoints)) / _r(nextHours));
  }
}
