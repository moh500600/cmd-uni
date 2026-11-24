import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../grades/gpa_settings_screen.dart';
import '../grades/grades_screen.dart' show fmtDec;
import '../settings/terms_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  final c = {
    for (final k in ['full_name', 'student_number', 'university', 'college', 'department', 'major', 'level', 'academic_year']) k: TextEditingController(),
  };
  bool _loaded = false;

  void _load() {
    if (_loaded) return;
    final a = ref.read(academicProvider).value;
    if (a == null) return;
    _loaded = true;
    final p = a.profile;
    c['full_name']!.text = p.fullName;
    c['student_number']!.text = p.studentNumber;
    c['university']!.text = p.university;
    c['college']!.text = p.college;
    c['department']!.text = p.department;
    c['major']!.text = p.major;
    c['level']!.text = p.level;
    c['academic_year']!.text = p.academicYear;
  }

  Future<void> _save() async {
    final a = ref.read(academicProvider).value!;
    await ref.read(repoProvider)!.save('profiles', {'id': a.uid, for (final e in c.entries) e.key: e.value.text.trim()});
    if (mounted) toast(context, context.tr('saved'));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    _load();
    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('nav_profile')),
        actions: [IconButton(key: const Key('save_profile'), icon: const Icon(Icons.check_rounded), onPressed: _save)],
      ),
      body: a == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: PageList(
                children: [
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          a.profile.fullName.isEmpty ? '🎓' : a.profile.fullName.characters.first,
                          style: const TextStyle(color: Colors.white, fontSize: 22),
                        ),
                      ),
                      title: Text(a.profile.fullName.isEmpty ? l.tr('student') : a.profile.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(l.tr('offline_mode')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  StatGrid(
                    children: [
                      StatTile(
                        icon: Icons.workspace_premium_rounded,
                        label: l.tr('cumulative_gpa'),
                        value: fmtDec(a.cumulative.gpa),
                        color: const Color(0xFFB45309),
                      ),
                      StatTile(
                        icon: Icons.hourglass_bottom_rounded,
                        label: l.tr('earned_hours'),
                        value: l.numText(a.completedHours.toDouble()),
                        color: AppColors.success,
                      ),
                    ],
                  ),
                  SectionTitle(l.tr('student_info'), icon: Icons.badge_rounded),
                  for (final e in c.entries) Field(e.value, l.tr('pf_${e.key}')),
                  SectionTitle(l.tr('academic_setup'), icon: Icons.school_rounded),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.date_range_rounded),
                          title: Text(l.tr('terms')),
                          subtitle: Text(a.currentTerm?.name ?? l.tr('no_term')),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
                        ),
                        ListTile(
                          leading: const Icon(Icons.rule_rounded),
                          title: Text(l.tr('gpa_settings')),
                          subtitle: Text(l.tr('sys_${a.profile.gpaSystem}')),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GpaSettingsScreen())),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _save, child: Text(l.tr('save'))),
                ],
              ),
            ),
    );
  }
}
