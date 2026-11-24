import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'domain/services/academic.dart';
import 'presentation/providers/providers.dart';
import 'presentation/screens/shell/home_shell.dart';

class UniPlannerApp extends ConsumerStatefulWidget {
  const UniPlannerApp({super.key});
  @override
  ConsumerState<UniPlannerApp> createState() => _UniPlannerAppState();
}

class _UniPlannerAppState extends ConsumerState<UniPlannerApp> with WidgetsBindingObserver {
  Timer? _remindersDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(notificationServiceProvider).init();
    });
  }

  @override
  void dispose() {
    _remindersDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    // Re-plan OS reminders a moment after the data changes.
    ref.listen<AsyncValue<Academic>>(academicProvider, (_, next) {
      final a = next.value;
      if (a == null || a.uid.isEmpty) return;
      _remindersDebounce?.cancel();
      _remindersDebounce = Timer(const Duration(seconds: 2), () => rescheduleReminders(ref, a));
    });
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: s.lang == 'ar' ? 'CMD Uni' : 'CMD Uni',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: s.theme,
      locale: Locale(s.lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: const HomeShell(),
    );
  }
}
