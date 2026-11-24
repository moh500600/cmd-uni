import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../settings/terms_screen.dart';

class CourseFormScreen extends ConsumerStatefulWidget {
  final String? courseId;
  const CourseFormScreen({super.key, this.courseId});
  @override
  ConsumerState<CourseFormScreen> createState() => _CourseFormScreenState();
}

class _CourseFormScreenState extends ConsumerState<CourseFormScreen> {
  final _form = GlobalKey<FormState>();
  final name = TextEditingController(), code = TextEditingController(), instructor = TextEditingController();
  final dept = TextEditingController(), hours = TextEditingController(text: '3'), desc = TextEditingController();
  final refs = TextEditingController(), links = TextEditingController(), lectures = TextEditingController();
  final limit = TextEditingController(), finalPct = TextEditingController(), finalLetter = TextEditingController();
  String? termId;
  int color = AppColors.courseColors.first.toARGB32();
  String status = 'ongoing';
  bool includeInGpa = true;
  bool _loaded = false;

  void _load() {
    if (_loaded) return;
    final a = ref.read(academicProvider).value;
    if (a == null) return;
    _loaded = true;
    final c = widget.courseId == null ? null : a.course(widget.courseId);
    if (c == null) {
      termId = a.currentTerm?.id;
      color = AppColors.courseColors[a.courses.length % AppColors.courseColors.length].toARGB32();
      return;
    }
    name.text = c.name;
    code.text = c.code;
    instructor.text = c.instructor;
    dept.text = c.department;
    hours.text = c.creditHours.toString();
    desc.text = c.description;
    refs.text = c.referencesText;
    links.text = c.links;
    lectures.text = c.totalLectures == 0 ? '' : '${c.totalLectures}';
    limit.text = c.absenceLimitPct?.toString() ?? '';
    finalPct.text = c.finalPercent?.toString() ?? '';
    finalLetter.text = c.finalLetter ?? '';
    termId = c.termId;
    color = c.color == 0 ? color : c.color;
    status = c.status;
    includeInGpa = c.includeInGpa;
  }

  Future<void> _save() async {
    final repo = ref.read(repoProvider)!;
    final l = context.l;
    if (await repo.courseExists(name: name.text, code: code.text, termId: termId, exceptId: widget.courseId)) {
      if (mounted) toast(context, l.tr('course_duplicate'));
      return;
    }
    for (final ln in lines(links.text)) {
      if (V.url(ln) != null) {
        if (mounted) toast(context, '${l.tr('v_url')}: $ln');
        return;
      }
    }
    try {
      await repo.save('courses', {
        'id': widget.courseId,
        'name': name.text.trim(),
        'code': code.text.trim(),
        'instructor': instructor.text.trim(),
        'department': dept.text.trim(),
        'credit_hours': normalizeDigits(hours.text.trim()),
        'description': desc.text.trim(),
        'references_text': refs.text.trim(),
        'links': links.text.trim(),
        'total_lectures': int.tryParse(normalizeDigits(lectures.text.trim())) ?? 0,
        'absence_limit_pct': limit.text.trim().isEmpty ? null : normalizeDigits(limit.text.trim()),
        'final_percent': finalPct.text.trim().isEmpty ? null : normalizeDigits(finalPct.text.trim()),
        'final_letter': finalLetter.text.trim().isEmpty ? null : finalLetter.text.trim(),
        'term_id': termId,
        'color': color,
        'status': status,
        'include_in_gpa': includeInGpa,
      }, log: name.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, errorText(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    _load();
    return FormPage(
      title: l.tr(widget.courseId == null ? 'add_course' : 'edit_course'),
      formKey: _form,
      onSave: _save,
      children: [
        Field(name, l.tr('course_name'), icon: Icons.menu_book_rounded, validator: V.required),
        Row(
          children: [
            Expanded(child: Field(code, l.tr('course_code'), icon: Icons.tag_rounded)),
            const SizedBox(width: 10),
            Expanded(
              child: Field(
                hours,
                l.tr('credit_hours'),
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => V.number(v, required: true, max: 30, positive: true),
              ),
            ),
          ],
        ),
        Field(instructor, l.tr('instructor'), icon: Icons.person_rounded),
        Field(dept, l.tr('department'), icon: Icons.account_balance_rounded),
        Row(
          children: [
            Expanded(
              child: Pick<String>(
                label: l.tr('term'),
                icon: Icons.date_range_rounded,
                value: termId,
                allowNone: true,
                items: [for (final t in a?.terms ?? <Term>[]) (t.id, t.name)],
                onChanged: (v) => setState(() => termId = v),
              ),
            ),
            IconButton(
              tooltip: l.tr('manage_terms'),
              icon: const Icon(Icons.edit_calendar_rounded),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
            ),
          ],
        ),
        Text(l.tr('course_color'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in AppColors.courseColors)
              InkWell(
                onTap: () => setState(() => color = c.toARGB32()),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: c,
                  child: color == c.toARGB32() ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Field(desc, l.tr('description'), maxLines: 3, icon: Icons.notes_rounded),
        Field(refs, l.tr('references_books'), maxLines: 3, icon: Icons.library_books_rounded),
        Field(links, l.tr('lecture_links'), maxLines: 3, icon: Icons.link_rounded, hint: l.tr('one_per_line'), textDirection: TextDirection.ltr),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(l.tr('attendance_rules'), style: const TextStyle(fontWeight: FontWeight.w700)),
          children: [
            Field(
              lectures,
              l.tr('total_lectures'),
              keyboard: TextInputType.number,
              hint: l.tr('total_lectures_hint'),
              validator: (v) => V.integer(v, max: 500),
            ),
            Field(
              limit,
              l.tr('absence_limit_pct_course'),
              keyboard: const TextInputType.numberWithOptions(decimal: true),
              hint: l.tr('absence_limit_hint'),
              validator: (v) => V.number(v, max: 100),
            ),
          ],
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(l.tr('final_result'), style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(l.tr('final_result_hint')),
          children: [
            Pick<String>(
              label: l.tr('course_status'),
              value: status,
              items: [
                for (final s in ['ongoing', 'completed', 'withdrawn']) (s, l.tr('cs_$s')),
              ],
              onChanged: (v) => setState(() => status = v ?? 'ongoing'),
            ),
            Field(finalPct, l.tr('final_percent'), keyboard: const TextInputType.numberWithOptions(decimal: true), validator: (v) => V.number(v, max: 100)),
            Field(finalLetter, l.tr('final_letter'), hint: l.tr('final_letter_hint')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: includeInGpa,
              onChanged: (v) => setState(() => includeInGpa = v),
              title: Text(l.tr('include_in_gpa')),
            ),
          ],
        ),
      ],
    );
  }
}
