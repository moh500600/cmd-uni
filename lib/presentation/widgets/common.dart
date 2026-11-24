import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/entities.dart';

/// Width breakpoints: phone < 600 ≤ tablet < 1000 ≤ desktop.
extension Responsive on BuildContext {
  double get width => MediaQuery.sizeOf(this).width;
  bool get isPhone => width < 600;
  bool get isWide => width >= 840;
  int get gridColumns => width >= 1300 ? 4 : (width >= 900 ? 3 : (width >= 600 ? 2 : 1));
}

/// Page body with max width and padding, scrolling.
class PageList extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  final Future<void> Function()? onRefresh;
  const PageList({super.key, required this.children, this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 96), this.onRefresh});
  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: padding,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ],
    );
    return onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  final IconData? icon;
  const SectionTitle(this.text, {super.key, this.trailing, this.icon});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Row(
      children: [
        if (icon != null) ...[Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8)],
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
        ?trailing,
      ],
    ),
  );
}

class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  const StatTile({super.key, required this.icon, required this.label, required this.value, required this.color, this.onTap});
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Grid of stat tiles that adapts to the width.
class StatGrid extends StatelessWidget {
  final List<Widget> children;
  const StatGrid({super.key, required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cols = c.maxWidth >= 1000 ? 5 : (c.maxWidth >= 700 ? 4 : (c.maxWidth >= 420 ? 3 : 2));
      final w = (c.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    },
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
    child: Column(
      children: [
        Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
        if (action != null) ...[const SizedBox(height: 14), action!],
      ],
    ),
  );
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Pill(this.text, this.color, {super.key, this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 3)],
        Text(
          text,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class CourseDot extends StatelessWidget {
  final Course? course;
  final double size;
  const CourseDot(this.course, {super.key, this.size = 10});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: course == null ? Colors.grey : AppColors.course(course!.color), shape: BoxShape.circle),
  );
}

class ProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color? color;
  const ProgressBar(this.value, {super.key, this.color});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: LinearProgressIndicator(
      value: value.clamp(0, 1),
      minHeight: 7,
      color: color,
      backgroundColor: (color ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.12),
    ),
  );
}

class Ring extends StatelessWidget {
  final double value;
  final String label;
  final Color color;
  final double size;
  const Ring({super.key, required this.value, required this.label, required this.color, this.size = 64});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(value: value.clamp(0, 1), strokeWidth: 6, color: color, backgroundColor: color.withValues(alpha: 0.14)),
        ),
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: size / 4.6),
        ),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, String message, {String? okLabel, bool danger = true}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.tr('cancel'))),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(okLabel ?? c.tr('delete')),
        ),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg) =>
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

/// Text field with l10n validator keys.
class Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboard;
  final int maxLines;
  final IconData? icon;
  final String? hint;
  final bool obscure;
  final TextDirection? textDirection;
  const Field(
    this.controller,
    this.label, {
    super.key,
    this.validator,
    this.keyboard,
    this.maxLines = 1,
    this.icon,
    this.hint,
    this.obscure = false,
    this.textDirection,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: obscure ? 1 : maxLines,
      minLines: 1,
      obscureText: obscure,
      textDirection: textDirection,
      decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: icon == null ? null : Icon(icon), alignLabelWithHint: maxLines > 1),
      validator: validator == null
          ? null
          : (v) {
              final k = validator!(v);
              return k == null ? null : context.tr(k);
            },
    ),
  );
}

/// A dropdown that stores ids/values and shows labels.
class Pick<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;
  final IconData? icon;
  final bool allowNone;
  const Pick({super.key, required this.label, required this.value, required this.items, required this.onChanged, this.icon, this.allowNone = false});
  @override
  Widget build(BuildContext context) {
    final values = items.map((e) => e.$1).toSet();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T?>(
        initialValue: values.contains(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon)),
        items: [
          if (allowNone) DropdownMenuItem<T?>(value: null, child: Text(context.tr('none'))),
          for (final (v, t) in items)
            DropdownMenuItem<T?>(
              value: v,
              child: Text(t, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// A tappable row that shows a date / time and opens the picker.
class DateTimeField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final bool withTime;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;
  final IconData icon;
  const DateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.withTime = false,
    this.clearable = true,
    this.icon = Icons.event_rounded,
  });
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final text = value == null ? '—' : (withTime ? l.dateTime(value!) : l.date(value!));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final now = DateTime.now();
          final d = await showDatePicker(context: context, initialDate: value ?? now, firstDate: DateTime(now.year - 10), lastDate: DateTime(now.year + 10));
          if (d == null || !context.mounted) return;
          if (!withTime) return onChanged(d);
          final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(value ?? DateTime(now.year, now.month, now.day, 9)));
          if (t == null) return;
          onChanged(DateTime(d.year, d.month, d.day, t.hour, t.minute));
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            suffixIcon: clearable && value != null ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => onChanged(null)) : null,
          ),
          child: Text(text),
        ),
      ),
    );
  }
}

class TimeField extends StatelessWidget {
  final String label;
  final int? minutes;
  final ValueChanged<int?> onChanged;
  final bool compact;
  const TimeField({super.key, required this.label, required this.minutes, required this.onChanged, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final m = minutes;
    if (compact) {
      return TextButton.icon(
        icon: const Icon(Icons.schedule_rounded),
        label: Text(m == null ? '—' : TimeOfDay(hour: m ~/ 60, minute: m % 60).format(context)),
        onPressed: () async {
          final t = await showTimePicker(
            context: context,
            initialTime: m == null ? const TimeOfDay(hour: 8, minute: 0) : TimeOfDay(hour: m ~/ 60, minute: m % 60),
          );
          if (t != null) onChanged(t.hour * 60 + t.minute);
        },
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final t = await showTimePicker(
            context: context,
            initialTime: m == null ? const TimeOfDay(hour: 8, minute: 0) : TimeOfDay(hour: m ~/ 60, minute: m % 60),
          );
          if (t != null) onChanged(t.hour * 60 + t.minute);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.schedule_rounded)),
          child: Text(m == null ? '—' : TimeOfDay(hour: m ~/ 60, minute: m % 60).format(context)),
        ),
      ),
    );
  }
}

/// Standard form page: scrolling form + save button in the app bar and at the bottom.
class FormPage extends StatelessWidget {
  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final Future<void> Function() onSave;
  final List<Widget>? actions;
  const FormPage({super.key, required this.title, required this.formKey, required this.children, required this.onSave, this.actions});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...children,
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const Key('save'),
                    onPressed: () async {
                      if (formKey.currentState?.validate() ?? false) await onSave();
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: Text(context.tr('save')),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String courseName(BuildContext context, Course? c) => c?.name ?? context.tr('no_course');

IconData fileIcon(String type) => switch (type) {
  'pdf' => Icons.picture_as_pdf_rounded,
  'word' => Icons.description_rounded,
  'ppt' => Icons.slideshow_rounded,
  'excel' => Icons.table_chart_rounded,
  'image' => Icons.image_rounded,
  'audio' => Icons.audiotrack_rounded,
  'link' => Icons.link_rounded,
  _ => Icons.insert_drive_file_rounded,
};
