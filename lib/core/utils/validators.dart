/// Form validators. They return a l10n key (or null when the value is fine);
/// screens translate the key.
class V {
  V._();
  static String? required(String? v) => (v == null || v.trim().isEmpty) ? 'v_required' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'v_required';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? null : 'v_email';
  }

  static String? password(String? v) => (v == null || v.length < 6) ? 'v_password' : null;

  /// Optional non-negative number (accepts Arabic-Indic digits and the Arabic decimal comma).
  static String? number(String? v, {bool required = false, double? max, bool positive = false}) {
    if (v == null || v.trim().isEmpty) return required ? 'v_required' : null;
    final n = parseNum(v);
    if (n == null) return 'v_number';
    if (n < 0 || (positive && n == 0)) return 'v_positive';
    if (max != null && n > max) return 'v_too_big';
    return null;
  }

  static String? integer(String? v, {bool required = false, int min = 0, int? max}) {
    if (v == null || v.trim().isEmpty) return required ? 'v_required' : null;
    final n = int.tryParse(normalizeDigits(v.trim()));
    if (n == null) return 'v_number';
    if (n < min) return 'v_positive';
    if (max != null && n > max) return 'v_too_big';
    return null;
  }

  static String? url(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final u = Uri.tryParse(v.trim());
    return (u != null && (u.isScheme('http') || u.isScheme('https'))) ? null : 'v_url';
  }
}

/// Arabic-Indic / Persian digits → ASCII, Arabic decimal separator → '.'.
String normalizeDigits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩', fa = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final ch in s.runes) {
    final c = String.fromCharCode(ch);
    final i = ar.indexOf(c), j = fa.indexOf(c);
    if (i >= 0) {
      b.write(i);
    } else if (j >= 0) {
      b.write(j);
    } else if (c == '٫' || c == ',') {
      b.write('.');
    } else {
      b.write(c);
    }
  }
  return b.toString();
}

double? parseNum(String? s) => s == null ? null : double.tryParse(normalizeDigits(s.trim()));
