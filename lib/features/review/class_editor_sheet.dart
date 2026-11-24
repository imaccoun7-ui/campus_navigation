import 'package:flutter/material.dart';

import '../../core/format/time_format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/campus_data.dart';
import '../../data/models/scheduled_class.dart';
import '../../services/matching/room_matcher.dart';
import 'draft_class.dart';

/// What the editor sheet returned.
class ClassEditorOutcome {
  const ClassEditorOutcome.saved(DraftClass this.draft) : removed = false;

  const ClassEditorOutcome.removed() : draft = null, removed = true;

  final DraftClass? draft;
  final bool removed;
}

/// Bottom sheet for editing (or removing) one scanned class.
Future<ClassEditorOutcome?> showClassEditor(
  BuildContext context, {
  required DraftClass draft,
  required CampusData data,
}) {
  return showModalBottomSheet<ClassEditorOutcome>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (_) => ClassEditorSheet(draft: draft, data: data),
  );
}

class ClassEditorSheet extends StatefulWidget {
  const ClassEditorSheet({super.key, required this.draft, required this.data});

  final DraftClass draft;
  final CampusData data;

  @override
  State<ClassEditorSheet> createState() => _ClassEditorSheetState();
}

class _ClassEditorSheetState extends State<ClassEditorSheet> {
  late final TextEditingController _subject;
  late final TextEditingController _room;
  late ClassDay? _day;
  late int? _start;
  late int? _end;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subject = TextEditingController(text: widget.draft.subject);
    _room = TextEditingController(text: widget.draft.room);
    _day = widget.draft.day;
    _start = widget.draft.startMinutes;
    _end = widget.draft.endMinutes;
  }

  @override
  void dispose() {
    _subject.dispose();
    _room.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = (isStart ? _start : _end) ?? (isStart ? 9 * 60 : 10 * 60);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      final value = picked.hour * 60 + picked.minute;
      if (isStart) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  void _save() {
    final subject = _subject.text.trim();
    final room = _room.text.trim();
    if (subject.isEmpty || room.isEmpty || _day == null) {
      setState(() => _error = 'Subject, room and day are required.');
      return;
    }
    final matcher = RoomMatcher(widget.data);
    final match = matcher.match(room);
    final start = _start ?? 9 * 60;
    final end = _end ?? start + 60;

    final updated = widget.draft.copyWith(
      subject: subject,
      room: match?.room.name ?? room,
      day: _day,
      startMinutes: start,
      endMinutes: end,
      buildingId: match?.building.id,
      roomIndex: match?.room.indexInBuilding,
      needsReview: match == null,
      note: match == null ? 'Room not found on campus' : null,
      clearMatch: match == null,
      clearNote: match != null,
    );
    Navigator.of(context).pop(ClassEditorOutcome.saved(updated));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Edit class',
              style: AppTypography.cardTitle.copyWith(fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _subject,
              hintText: 'Subject (for example CS 101)',
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _room,
              hintText: 'Room (for example T-201)',
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Day', style: AppTypography.cardBody),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final day in ClassDay.values)
                  AppChip(
                    label: day.shortLabel,
                    selected: _day == day,
                    onTap: () => setState(() => _day = day),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: 'Starts',
                    minutes: _start,
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _TimeField(
                    label: 'Ends',
                    minutes: _end,
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: AppTypography.cardBody.copyWith(
                  color: AppColors.routeEnd,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            PillButton(label: 'Save', onPressed: _save),
            const SizedBox(height: AppSpacing.sm),
            PillButton(
              label: 'Remove class',
              variant: PillButtonVariant.muted,
              onPressed: () =>
                  Navigator.of(context).pop(const ClassEditorOutcome.removed()),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.minutes,
    required this.onTap,
  });

  final String label;
  final int? minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = minutes == null ? 'Set time' : formatClock(minutes!);
    return Semantics(
      button: true,
      label: '$label $text',
      child: Material(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          child: Container(
            height: AppSpacing.controlHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$label: $text',
                    style: AppTypography.cardBody.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const Icon(Icons.schedule, size: 16, color: AppColors.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
