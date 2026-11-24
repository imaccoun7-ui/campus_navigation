import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/screen_layout.dart';
import '../../data/models/scheduled_class.dart';
import '../../data/repositories/repository_providers.dart';
import '../../services/matching/room_matcher.dart';

/// Manually builds a schedule by queuing multiple classes, then saves them
/// all at once. Room text is resolved against `buildings.json` so each class
/// gets building + room match data for directions.
///
/// When [editItemId] is provided, the screen edits that single class instead of
/// creating new ones: it shows one pre-filled entry and saves with `upsert`.
class CreateClassScreen extends ConsumerStatefulWidget {
  const CreateClassScreen({super.key, this.editItemId});

  /// When set, edits this existing class instead of creating new ones.
  final String? editItemId;

  @override
  ConsumerState<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _PendingClass {
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController roomController = TextEditingController();
  ClassDay day;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String? buildingId;
  int? roomIndex;
  String? buildingName;

  _PendingClass({required this.day});

  void dispose() {
    subjectController.dispose();
    roomController.dispose();
  }
}

class _CreateClassScreenState extends ConsumerState<CreateClassScreen> {
  final List<_PendingClass> _entries = [];
  bool _busy = false;
  bool get _editing => widget.editItemId != null;
  ScheduledClass? _editItem;

  @override
  void initState() {
    super.initState();
    if (_editing) {
      _editItem = ref
          .read(scheduleProvider)
          .firstWhere((c) => c.id == widget.editItemId);
      _addEditingEntry();
    } else {
      _addEntry();
    }
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _addEditingEntry() {
    final item = _editItem!;
    final entry = _PendingClass(day: item.day);
    entry.subjectController.text = item.subject;
    entry.roomController.text = item.room;
    entry.startTime = _timeOfDay(item.startMinutes);
    entry.endTime = _timeOfDay(item.endMinutes);
    entry.buildingId = item.buildingId;
    entry.roomIndex = item.roomIndex;
    entry.buildingName = item.buildingId == null
        ? null
        : ref.read(campusDataProvider).buildingById(item.buildingId)?.name;
    entry.roomController.addListener(() => _resolveBuilding(entry));
    _entries.add(entry);
  }

  _PendingClass _newEntry() {
    final entry = _PendingClass(
      day: ClassDay.fromDateTime(DateTime.now()),
    );
    entry.roomController.addListener(() => _resolveBuilding(entry));
    return entry;
  }

  void _addEntry() {
    if (_editing) return;
    setState(() {
      _entries.add(_newEntry());
    });
  }

  void _removeEntry(int index) {
    if (_editing) return;
    setState(() {
      _entries.removeAt(index).dispose();
    });
  }

  TimeOfDay _timeOfDay(int? minutes) {
    if (minutes == null) return TimeOfDay.now();
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  void _resolveBuilding(_PendingClass entry) {
    final roomText = entry.roomController.text.trim();
    if (roomText.isEmpty) {
      entry.buildingId = null;
      entry.roomIndex = null;
      entry.buildingName = null;
      return;
    }
    final data = ref.read(campusDataProvider);
    final match = RoomMatcher(data).match(roomText);
    if (match == null) {
      entry.buildingId = null;
      entry.roomIndex = null;
      entry.buildingName = null;
      return;
    }
    entry.buildingId = match.building.id;
    entry.roomIndex = match.room.indexInBuilding;
    entry.buildingName = match.building.name;
  }

  int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

  Future<void> _pickTime(_PendingClass entry, {required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (entry.startTime ?? TimeOfDay.now())
          : (entry.endTime ?? TimeOfDay.now()),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        entry.startTime = picked;
        if (entry.endTime != null &&
            _minutes(entry.endTime!) <= _minutes(picked)) {
          entry.endTime = null;
        }
      } else {
        entry.endTime = picked;
      }
    });
  }

  bool _validateEntry(_PendingClass entry) {
    if (entry.subjectController.text.trim().isEmpty ||
        entry.roomController.text.trim().isEmpty) {
      return false;
    }
    if (entry.startTime == null || entry.endTime == null) {
      return false;
    }
    return _minutes(entry.endTime!) > _minutes(entry.startTime!);
  }

  Future<void> _saveAll() async {
    if (_busy) return;
    if (_entries.isEmpty) return;

    for (final entry in _entries) {
      if (!_validateEntry(entry)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please complete every class before saving.')),
          );
        }
        return;
      }
    }

    setState(() => _busy = true);
    try {
      if (_editing) {
        final entry = _entries.first;
        final start = _minutes(entry.startTime!);
        final end = _minutes(entry.endTime!);
        final updated = ScheduledClass(
          id: _editItem!.id,
          subject: entry.subjectController.text.trim(),
          room: entry.roomController.text.trim(),
          day: entry.day,
          startMinutes: start,
          endMinutes: end,
          buildingId: entry.buildingId,
          roomIndex: entry.roomIndex,
        );
        await ref.read(scheduleProvider.notifier).upsert(updated);
      } else {
        final classes = <ScheduledClass>[];
        for (final entry in _entries) {
          final start = _minutes(entry.startTime!);
          final end = _minutes(entry.endTime!);
          classes.add(
            ScheduledClass(
              id: 'manual_${DateTime.now().millisecondsSinceEpoch}_${classes.length}',
              subject: entry.subjectController.text.trim(),
              room: entry.roomController.text.trim(),
              day: entry.day,
              startMinutes: start,
              endMinutes: end,
              buildingId: entry.buildingId,
              roomIndex: entry.roomIndex,
            ),
          );
        }
        await ref.read(scheduleProvider.notifier).replaceAll([
          ...ref.read(scheduleProvider),
          ...classes,
        ]);
      }
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _entryCard(_PendingClass entry, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        controller: entry.subjectController,
                        hintText: 'Subject (e.g. Introduction to Programming)',
                        prefixIcon: Icons.book_outlined,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: entry.roomController,
                        hintText: 'Room (e.g. T-302)',
                        prefixIcon: Icons.class_outlined,
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                if (!_editing)
                  Column(
                    children: [
                      InkWell(
                        onTap: () => _removeEntry(index),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.delete_outline,
                            color: AppColors.inkMuted,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (entry.buildingName != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.field,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 18,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Building matched',
                            style: AppTypography.eyebrowMuted,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.buildingName!,
                            style: AppTypography.cardTitle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Text('Day', style: AppTypography.sectionTitle),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final day in ClassDay.values.take(7)) ...[
                          AppChip(
                            label: day.shortLabel,
                            selected: entry.day == day,
                            onTap: () => setState(() => entry.day = day),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    color: AppColors.field,
                    child: InkWell(
                      onTap: () => _pickTime(entry, isStart: true),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start', style: AppTypography.eyebrowMuted),
                            const SizedBox(height: 2),
                            Text(
                              entry.startTime == null
                                  ? 'Pick a time'
                                  : entry.startTime!.format(context),
                              style: AppTypography.cardTitle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppCard(
                    color: AppColors.field,
                    child: InkWell(
                      onTap: () => _pickTime(entry, isStart: false),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('End', style: AppTypography.eyebrowMuted),
                            const SizedBox(height: 2),
                            Text(
                              entry.endTime == null
                                  ? 'Pick a time'
                                  : entry.endTime!.format(context),
                              style: AppTypography.cardTitle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenShell(
      header: ScreenHeader(
        title: _editing ? 'Edit Class' : 'Add Classes',
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._entries.asMap().entries.map(
            (entry) => _entryCard(entry.value, entry.key),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!_editing) ...[
            PillButton(
              label: 'Add Another Class',
              variant: PillButtonVariant.surface,
              icon: Icons.add_circle_outline,
              onPressed: _busy ? null : _addEntry,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          PillButton(
            label: _editing ? 'Save Changes' : 'Save All Classes',
            variant: PillButtonVariant.primary,
            icon: Icons.save_outlined,
            onPressed: _busy || _entries.isEmpty ? null : _saveAll,
          ),
        ],
      ),
    );
  }
}
