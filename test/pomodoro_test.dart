import 'package:flutter_test/flutter_test.dart';
import 'package:uni_planner/domain/services/pomodoro.dart';

void main() {
  const c = PomodoroConfig();
  const m = PomodoroMachine(c);

  test('25/5 with a long break after 4 focus sessions', () {
    var s = PomodoroState.initial(c);
    final phases = <PomoPhase>[];
    for (var i = 0; i < 8; i++) {
      s = m.next(s);
      phases.add(s.phase);
    }
    expect(phases, [
      PomoPhase.shortBreak,
      PomoPhase.focus,
      PomoPhase.shortBreak,
      PomoPhase.focus,
      PomoPhase.shortBreak,
      PomoPhase.focus,
      PomoPhase.longBreak,
      PomoPhase.focus,
    ]);
    expect(s.completedFocus, 4);
  });

  test('tick logs focus minutes and carries over', () {
    var s = PomodoroState.initial(c).copyWith(running: true);
    final (s2, mins) = m.tick(s, 25 * 60 + 60);
    expect(mins, 25);
    expect(s2.phase, PomoPhase.shortBreak);
    expect(s2.remainingSec, 4 * 60);
    final (s3, mins2) = m.tick(s2.copyWith(running: false), 999);
    expect(mins2, 0);
    expect(s3.remainingSec, 4 * 60);
  });

  test('validation', () {
    expect(c.validate(), isNull);
    expect(const PomodoroConfig(longBreakMin: 10).validate(), 'pomo_bad_long');
    expect(const PomodoroConfig(longBreakMin: 31).validate(), 'pomo_bad_long');
    expect(const PomodoroConfig(focusMin: 0).validate(), 'pomo_bad_focus');
  });
}
