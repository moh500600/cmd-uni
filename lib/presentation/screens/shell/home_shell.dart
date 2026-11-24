import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../widgets/common.dart';
import '../analytics/analytics_screen.dart';
import '../assignments/assignments_screen.dart';
import '../attendance/attendance_screen.dart';
import '../calendar/calendar_screen.dart';
import '../courses/courses_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../exams/exams_screen.dart';
import '../grades/grades_screen.dart';
import '../share/share_screen.dart';
import '../notes/notes_screen.dart';
import '../profile/profile_screen.dart';
import '../projects/projects_screen.dart';
import '../resources/resources_screen.dart';
import '../settings/settings_screen.dart';
import '../study/study_screen.dart';
import '../timetable/timetable_screen.dart';

class Section {
  final String key;
  final IconData icon;
  final IconData selected;
  final Widget Function() build;
  const Section(this.key, this.icon, this.selected, this.build);
}

final kSections = <Section>[
  Section('nav_dashboard', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, () => const DashboardScreen()),
  Section('nav_timetable', Icons.view_week_outlined, Icons.view_week_rounded, () => const TimetableScreen()),
  Section('nav_assignments', Icons.assignment_outlined, Icons.assignment_rounded, () => const AssignmentsScreen()),
  Section('nav_calendar', Icons.calendar_month_outlined, Icons.calendar_month_rounded, () => const CalendarScreen()),
  Section('nav_courses', Icons.menu_book_outlined, Icons.menu_book_rounded, () => const CoursesScreen()),
  Section('nav_exams', Icons.quiz_outlined, Icons.quiz_rounded, () => const ExamsScreen()),
  Section('nav_projects', Icons.account_tree_outlined, Icons.account_tree_rounded, () => const ProjectsScreen()),
  Section('nav_grades', Icons.workspace_premium_outlined, Icons.workspace_premium_rounded, () => const GradesScreen()),
  Section('nav_attendance', Icons.fact_check_outlined, Icons.fact_check_rounded, () => const AttendanceScreen()),
  Section('nav_notes', Icons.sticky_note_2_outlined, Icons.sticky_note_2_rounded, () => const NotesScreen()),
  Section('nav_resources', Icons.folder_outlined, Icons.folder_rounded, () => const ResourcesScreen()),
  Section('nav_study', Icons.timer_outlined, Icons.timer_rounded, () => const StudyScreen()),
  Section('nav_groups', Icons.groups_outlined, Icons.groups_rounded, () => const ShareScreen()),
  Section('nav_analytics', Icons.insights_outlined, Icons.insights_rounded, () => const AnalyticsScreen()),
  Section('nav_profile', Icons.badge_outlined, Icons.badge_rounded, () => const ProfileScreen()),
  Section('nav_settings', Icons.settings_outlined, Icons.settings_rounded, () => const SettingsScreen()),
];

/// Opens a section as its own page (phone "More" menu, dashboard shortcuts).
void openSection(BuildContext context, String key) {
  final s = kSections.firstWhere((s) => s.key == key);
  Navigator.push(context, MaterialPageRoute(builder: (_) => s.build()));
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    if (context.isWide) {
      // Tablet landscape / desktop: a side rail with every section.
      final extended = context.width >= 1200;
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: LayoutBuilder(
                builder: (context, c) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: c.maxHeight),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        extended: extended,
                        minExtendedWidth: 220,
                        selectedIndex: index,
                        labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                        leading: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: extended
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.school_rounded, color: Theme.of(context).colorScheme.primary, size: 30),
                                    const SizedBox(width: 8),
                                    Text(l.tr('app_name'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                                  ],
                                )
                              : Icon(Icons.school_rounded, color: Theme.of(context).colorScheme.primary, size: 30),
                        ),
                        onDestinationSelected: (i) => setState(() => index = i),
                        destinations: [
                          for (final s in kSections) NavigationRailDestination(icon: Icon(s.icon), selectedIcon: Icon(s.selected), label: Text(l.tr(s.key))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: KeyedSubtree(key: ValueKey(index), child: kSections[index].build()),
            ),
          ],
        ),
      );
    }
    // Phone / portrait tablet: bottom bar with 4 sections + "More".
    final pages = [for (var i = 0; i < 4; i++) kSections[i].build(), const MoreScreen()];
    return Scaffold(
      body: IndexedStack(index: index.clamp(0, 4), children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index.clamp(0, 4),
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: [
          for (var i = 0; i < 4; i++)
            NavigationDestination(icon: Icon(kSections[i].icon), selectedIcon: Icon(kSections[i].selected), label: l.tr(kSections[i].key)),
          NavigationDestination(icon: const Icon(Icons.grid_view_outlined), selectedIcon: const Icon(Icons.grid_view_rounded), label: l.tr('nav_more')),
        ],
      ),
    );
  }
}

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final rest = kSections.sublist(4);
    return Scaffold(
      appBar: AppBar(title: Text(l.tr('nav_more'))),
      body: PageList(
        children: [
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 500 ? 4 : 3;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.05,
                children: [
                  for (final s in rest)
                    Card(
                      child: InkWell(
                        key: Key('more_${s.key}'),
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => s.build())),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(s.selected, size: 30, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(height: 8),
                            Text(
                              l.tr(s.key),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
