import '../services/academic.dart';

/// Domain-side contract for the student's data. The data layer implements it
/// over SQLite (offline-first) + Supabase sync.
abstract class AcademicRepository {
  Future<Academic> load();
  Future<String> save(String table, Map<String, Object?> row, {String? log});
  Future<void> delete(String table, String id, {String? log});
}
