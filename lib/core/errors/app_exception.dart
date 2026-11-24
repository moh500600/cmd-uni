/// A failure the UI can explain: [key] is an l10n key, [detail] optional raw text.
class AppException implements Exception {
  final String key;
  final String? detail;
  const AppException(this.key, [this.detail]);
  @override
  String toString() => detail == null ? key : '$key: $detail';
}
