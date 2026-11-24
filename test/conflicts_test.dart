import 'package:flutter_test/flutter_test.dart';
import 'package:uni_planner/domain/services/conflicts.dart';

void main() {
  test('overlap is half-open: back-to-back classes do not clash', () {
    expect(overlaps(480, 570, 570, 660), isFalse);
    expect(overlaps(480, 571, 570, 660), isTrue);
    expect(overlaps(600, 620, 480, 700), isTrue); // contained
  });

  test('finds every clashing pair on the same day only', () {
    final slots = [
      const Slot('a', 1, 480, 570),
      const Slot('b', 1, 540, 630),
      const Slot('c', 1, 600, 690),
      const Slot('d', 2, 480, 570),
      const Slot('e', 1, 700, 760),
    ];
    final pairs = findConflicts(slots).map((p) => '${p.$1.id}${p.$2.id}').toSet();
    expect(pairs, {'ab', 'bc'});
  });

  test('candidate check ignores itself (editing)', () {
    final existing = [const Slot('a', 3, 600, 690), const Slot('b', 3, 700, 800)];
    expect(conflictsWith(const Slot('a', 3, 600, 690), existing), isEmpty);
    expect(conflictsWith(const Slot('x', 3, 680, 710), existing).map((s) => s.id), ['a', 'b']);
  });

  test('overlap minutes', () {
    expect(overlapMinutes(const Slot('a', 1, 480, 570), const Slot('b', 1, 540, 630)), 30);
    expect(overlapMinutes(const Slot('a', 1, 480, 570), const Slot('b', 2, 540, 630)), 0);
  });

  test('timed clashes (exams)', () {
    final items = [
      (DateTime(2026, 1, 5, 9), DateTime(2026, 1, 5, 11)),
      (DateTime(2026, 1, 5, 10), DateTime(2026, 1, 5, 12)),
      (DateTime(2026, 1, 5, 12), DateTime(2026, 1, 5, 13)),
    ];
    final c = findTimeClashes(items, (e) => e.$1, (e) => e.$2);
    expect(c.length, 1);
  });
}
