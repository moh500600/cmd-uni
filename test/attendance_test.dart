import 'package:flutter_test/flutter_test.dart';
import 'package:uni_planner/domain/services/attendance.dart';

void main() {
  test('counts and rate', () {
    final s = AttendanceStats.fromStatuses(['present', 'present', 'absent', 'late', 'excused'], totalLectures: 30);
    expect(s.recorded, 5);
    expect(s.counted, 4);
    expect(s.effectiveAbsences, 1); // 1 late < 3
    expect(s.attendanceRate, 75);
  });

  test('limit: 25% of 30 lectures = 7 allowed', () {
    final s = AttendanceStats.fromStatuses(List.filled(5, 'absent'), totalLectures: 30);
    expect(s.maxAllowed, 7);
    expect(s.remainingAllowed, 2);
    expect(s.risk, AbsenceRisk.safe);
  });

  test('three lates make one absence', () {
    final s = AttendanceStats.fromStatuses(['late', 'late', 'late', 'late', 'absent'], totalLectures: 32);
    expect(s.effectiveAbsences, 2);
    expect(s.maxAllowed, 8);
    final noLates = AttendanceStats.fromStatuses(['late', 'late', 'late'], latePerAbsence: 0, totalLectures: 32);
    expect(noLates.effectiveAbsences, 0);
  });

  test('exactly at the limit is allowed, one more crosses it', () {
    final at = AttendanceStats.fromStatuses(List.filled(8, 'absent'), totalLectures: 32);
    expect(at.remainingAllowed, 0);
    expect(at.risk, AbsenceRisk.warning);
    final over = AttendanceStats.fromStatuses(List.filled(9, 'absent'), totalLectures: 32);
    expect(over.remainingAllowed, -1);
    expect(over.risk, AbsenceRisk.exceeded);
  });

  test('warning at 75% of the allowance', () {
    final s = AttendanceStats.fromStatuses(List.filled(6, 'absent'), totalLectures: 32); // 6 of 8
    expect(s.risk, AbsenceRisk.warning);
    final ok = AttendanceStats.fromStatuses(List.filled(5, 'absent'), totalLectures: 32); // 5 of 8, 3 left
    expect(ok.risk, AbsenceRisk.safe);
  });

  test('custom limit percent and floating point safety', () {
    // 20% of 45 = 9 exactly
    expect(AttendanceStats.fromStatuses([], totalLectures: 45, limitPct: 20).maxAllowed, 9);
    // 15% of 20 = 3 exactly (0.15*20 = 2.9999999 in floats)
    expect(AttendanceStats.fromStatuses([], totalLectures: 20, limitPct: 15).maxAllowed, 3);
  });

  test('unknown term length', () {
    final s = AttendanceStats.fromStatuses(['absent']);
    expect(s.maxAllowed, isNull);
    expect(s.risk, AbsenceRisk.unknown);
    expect(s.lecturesLeft, isNull);
  });

  test('lectures left', () {
    final s = AttendanceStats.fromStatuses(['present', 'absent'], totalLectures: 10);
    expect(s.lecturesLeft, 8);
  });

  test('estimate lectures from weekly sessions', () {
    // Sun 2026-09-06 … Thu 2026-12-31: Sunday + Tuesday sessions
    final n = estimateLectures([7, 2], DateTime(2026, 9, 6), DateTime(2026, 12, 31));
    // Sundays: Sep 6 … Dec 27 = 17; Tuesdays: Sep 8 … Dec 29 = 17
    expect(n, 34);
    expect(estimateLectures([1], DateTime(2026, 1, 10), DateTime(2026, 1, 1)), 0);
  });
}
