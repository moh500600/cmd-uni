import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/platform/database_bootstrap.dart';
import 'data/db/app_database.dart';
import 'presentation/providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  await initializeDateFormatting('en');
  final prefs = await SharedPreferences.getInstance();
  // sqflite on Android/iOS, sqflite_common_ffi on Windows/Linux (same schema).
  final loc = await resolveDatabase('uni_planner.db');
  final db = await AppDatabase.open(loc.factory, loc.path);
  runApp(ProviderScope(overrides: [databaseProvider.overrideWithValue(db), prefsProvider.overrideWithValue(prefs)], child: const UniPlannerApp()));
}
