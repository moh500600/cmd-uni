import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/services/gpa.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

class GpaSettingsScreen extends ConsumerStatefulWidget {
  const GpaSettingsScreen({super.key});
  @override
  ConsumerState<GpaSettingsScreen> createState() => _GpaSettingsScreenState();
}

class _Band {
  final TextEditingController min, letter, points;
  bool pass;
  _Band(GradeBand b)
    : min = TextEditingController(text: b.min.toString()),
      letter = TextEditingController(text: b.letter),
      points = TextEditingController(text: b.points.toString()),
      pass = b.passing;
}

class _GpaSettingsScreenState extends ConsumerState<GpaSettingsScreen> {
  String system = '4';
  List<_Band> bands = [];
  final priorHours = TextEditingController(), priorGpa = TextEditingController();
  bool _loaded = false;

  void _load() {
    if (_loaded) return;
    final a = ref.read(academicProvider).value;
    if (a == null) return;
    _loaded = true;
    system = a.profile.gpaSystem;
    bands = [for (final b in a.scale.bands) _Band(b)];
    priorHours.text = a.profile.priorHours == dec(0) ? '' : a.profile.priorHours.toString();
    priorGpa.text = a.profile.priorGpa?.toString() ?? '';
  }

  void _setSystem(String s) => setState(() {
    system = s;
    bands = [for (final b in GradeScale.defaults[s]!.bands) _Band(b)];
  });

  Future<void> _save() async {
    final l = context.l;
    final list = <GradeBand>[];
    for (final b in bands) {
      final m = parseNum(b.min.text), p = parseNum(system == '100' ? '0' : b.points.text);
      if (m == null || p == null) return toast(context, l.tr('v_number'));
      list.add(
        GradeBand(
          dec(normalizeDigits(b.min.text.trim())),
          b.letter.text.trim(),
          dec(system == '100' ? '0' : normalizeDigits(b.points.text.trim())),
          passing: b.pass,
        ),
      );
    }
    final err = GradeScale.validate(list);
    if (err != null) return toast(context, l.tr(err));
    final ph = priorHours.text.trim(), pg = priorGpa.text.trim();
    if (pg.isNotEmpty && (parseNum(pg) == null || parseNum(pg)! < 0)) return toast(context, l.tr('v_number'));
    final scale = GradeScale(system, list);
    final isDefault = scale.toJsonString() == GradeScale.defaults[system]!.toJsonString();
    final a = ref.read(academicProvider).value!;
    await ref.read(repoProvider)!.save('profiles', {
      'id': a.uid,
      'gpa_system': system,
      'grade_scale': isDefault ? '' : scale.toJsonString(),
      'prior_hours': ph.isEmpty ? '0' : normalizeDigits(ph),
      'prior_gpa': pg.isEmpty ? null : normalizeDigits(pg),
    });
    if (mounted) {
      toast(context, l.tr('saved'));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    ref.watch(academicProvider);
    _load();
    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('gpa_settings')),
        actions: [IconButton(icon: const Icon(Icons.check_rounded), onPressed: _save)],
      ),
      body: PageList(
        children: [
          Text(l.tr('gpa_system'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              for (final s in ['4', '5', '100']) ButtonSegment(value: s, label: Text(l.tr('sys_$s'))),
            ],
            selected: {system},
            onSelectionChanged: (v) => _setSystem(v.first),
          ),
          const SizedBox(height: 6),
          Text(l.tr('sys_${system}_hint'), style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          SectionTitle(
            l.tr('grade_scale'),
            icon: Icons.table_rows_rounded,
            trailing: TextButton(onPressed: () => _setSystem(system), child: Text(l.tr('reset_default'))),
          ),
          for (var i = 0; i < bands.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 4, 0),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Field(bands[i].letter, l.tr('letter'))),
                    const SizedBox(width: 6),
                    Expanded(flex: 3, child: Field(bands[i].min, l.tr('from_pct'), keyboard: const TextInputType.numberWithOptions(decimal: true))),
                    if (system != '100') ...[
                      const SizedBox(width: 6),
                      Expanded(flex: 3, child: Field(bands[i].points, l.tr('points'), keyboard: const TextInputType.numberWithOptions(decimal: true))),
                    ],
                    Column(
                      children: [
                        Checkbox(value: bands[i].pass, onChanged: (v) => setState(() => bands[i].pass = v ?? true)),
                        Text(l.tr('pass'), style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.danger),
                      onPressed: () => setState(() => bands.removeAt(i)),
                    ),
                  ],
                ),
              ),
            ),
          TextButton.icon(
            onPressed: () => setState(() => bands.add(_Band(GradeBand(dec(0), '', dec(0))))),
            icon: const Icon(Icons.add_rounded),
            label: Text(l.tr('add_band')),
          ),
          SectionTitle(l.tr('prior_record'), icon: Icons.history_edu_rounded),
          Text(l.tr('prior_record_hint'), style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Field(priorHours, l.tr('prior_hours'), keyboard: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 10),
              Expanded(child: Field(priorGpa, l.tr('prior_gpa'), keyboard: const TextInputType.numberWithOptions(decimal: true))),
            ],
          ),
          FilledButton(onPressed: _save, child: Text(l.tr('save'))),
        ],
      ),
    );
  }
}
