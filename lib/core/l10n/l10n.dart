import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'strings.dart';

/// Arabic / English strings. Keys live in strings.dart ([ar, en] pairs);
/// test/l10n_test.dart checks every key used in lib/ exists.
class L10n {
  final String lang;
  const L10n(this.lang);
  bool get ar => lang == 'ar';

  static L10n of(BuildContext context) => L10n(Localizations.localeOf(context).languageCode);

  /// Keys asked for that have no translation (checked by the screen tests).
  static final missing = <String>{};

  String tr(String key, [Map<String, String> args = const {}]) {
    final pair = kStrings[key];
    if (pair == null) missing.add(key);
    var s = pair == null ? key : (ar ? pair[0] : pair[1]);
    args.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  /// Dates use Western digits in both languages, like the rest of the app's numbers.
  static String latin(String s) => s.replaceAllMapped(RegExp('[٠-٩]'), (m) => '${m[0]!.codeUnitAt(0) - 0x0660}');

  String date(DateTime d) => latin(DateFormat.yMMMd(lang).format(d));
  String dateShort(DateTime d) => latin(DateFormat.MMMd(lang).format(d));
  String weekday(DateTime d) => DateFormat.EEEE(lang).format(d);
  String weekdayShort(DateTime d) => DateFormat.E(lang).format(d);
  String time(DateTime d) => latin(DateFormat.jm(lang).format(d));
  String dateTime(DateTime d) => '${dateShort(d)} · ${time(d)}';
  String month(DateTime d) => latin(DateFormat.yMMMM(lang).format(d));

  /// ISO weekday (1 = Monday … 7 = Sunday) name.
  String weekdayName(int iso) => DateFormat.EEEE(lang).format(DateTime(2024, 1, iso)); // 2024-01-01 is a Monday
  String weekdayAbbr(int iso) => DateFormat.E(lang).format(DateTime(2024, 1, iso));

  String minutes(int m) {
    if (m < 60) return tr('n_min', {'n': '$m'});
    final h = m ~/ 60, r = m % 60;
    return r == 0 ? tr('n_hours', {'n': '$h'}) : tr('n_h_m', {'h': '$h', 'm': '$r'});
  }

  String numText(num n, [int digits = 2]) {
    final f = NumberFormat.decimalPattern('en')..maximumFractionDigits = digits;
    return f.format(n);
  }

  String pct(double v) => '${v.round()}%';
}

extension L10nX on BuildContext {
  L10n get l => L10n.of(this);
  String tr(String key, [Map<String, String> args = const {}]) => L10n.of(this).tr(key, args);
}
