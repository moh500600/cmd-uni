/// Pomodoro timer as a pure state machine (the screen drives the clock).
library;

enum PomoPhase { focus, shortBreak, longBreak }

class PomodoroConfig {
  final int focusMin, shortBreakMin, longBreakMin, longEvery;
  const PomodoroConfig({this.focusMin = 25, this.shortBreakMin = 5, this.longBreakMin = 15, this.longEvery = 4});

  /// Null when valid, else an l10n key.
  String? validate() {
    if (focusMin < 1 || focusMin > 180) return 'pomo_bad_focus';
    if (shortBreakMin < 1 || shortBreakMin > 60) return 'pomo_bad_break';
    if (longBreakMin < 15 || longBreakMin > 30) return 'pomo_bad_long';
    if (longEvery < 2 || longEvery > 10) return 'pomo_bad_every';
    return null;
  }

  int minutesOf(PomoPhase p) => switch (p) {
    PomoPhase.focus => focusMin,
    PomoPhase.shortBreak => shortBreakMin,
    PomoPhase.longBreak => longBreakMin,
  };
}

class PomodoroState {
  final PomoPhase phase;
  final int completedFocus; // focus sessions finished so far
  final int remainingSec;
  final bool running;
  const PomodoroState(this.phase, this.completedFocus, this.remainingSec, this.running);

  factory PomodoroState.initial(PomodoroConfig c) => PomodoroState(PomoPhase.focus, 0, c.focusMin * 60, false);

  PomodoroState copyWith({PomoPhase? phase, int? completedFocus, int? remainingSec, bool? running}) =>
      PomodoroState(phase ?? this.phase, completedFocus ?? this.completedFocus, remainingSec ?? this.remainingSec, running ?? this.running);
}

class PomodoroMachine {
  final PomodoroConfig config;
  const PomodoroMachine(this.config);

  /// The phase after the current one ends.
  PomodoroState next(PomodoroState s) {
    if (s.phase == PomoPhase.focus) {
      final done = s.completedFocus + 1;
      final phase = done % config.longEvery == 0 ? PomoPhase.longBreak : PomoPhase.shortBreak;
      return PomodoroState(phase, done, config.minutesOf(phase) * 60, s.running);
    }
    return PomodoroState(PomoPhase.focus, s.completedFocus, config.focusMin * 60, s.running);
  }

  /// Advances the clock by [seconds]; returns the new state and the focus minutes
  /// completed during this tick (to be logged as study time).
  (PomodoroState, int) tick(PomodoroState s, int seconds) {
    if (!s.running) return (s, 0);
    var st = s;
    var left = seconds;
    var focusMinutes = 0;
    while (left > 0) {
      if (left < st.remainingSec) {
        st = st.copyWith(remainingSec: st.remainingSec - left);
        left = 0;
      } else {
        left -= st.remainingSec;
        if (st.phase == PomoPhase.focus) focusMinutes += config.focusMin;
        st = next(st);
      }
    }
    return (st, focusMinutes);
  }
}
