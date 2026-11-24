import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/screen_layout.dart';
import '../../data/repositories/repository_providers.dart';
import '../../services/matching/room_matcher.dart';
import '../../services/ocr/study_load_parser.dart';
import '../../services/ocr/study_load_scanner.dart';
import '../review/draft_class.dart';
import 'scan_providers.dart';

/// `highfi/06-scanning-study-load.png`
class ScanningScreen extends ConsumerStatefulWidget {
  const ScanningScreen({super.key, this.scanner = const StudyLoadScanner()});

  /// Injectable so the screen can be widget-tested without ML Kit.
  final StudyLoadScanner scanner;

  @override
  ConsumerState<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends ConsumerState<ScanningScreen> {
  double _progress = 0;
  ScanStage _stage = ScanStage.reading;
  String? _error;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final file = ref.read(pendingScanFileProvider);
    if (file == null) {
      context.go('/upload');
      return;
    }
    try {
      final classes = await widget.scanner.scan(
        file,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _progress = progress.value;
            _stage = progress.stage;
          });
        },
      );
      final drafts = _toDrafts(classes);
      ref.read(scanDraftsProvider.notifier).replaceAll(drafts);
      if (!mounted) {
        return;
      }
      _finished = true;
      context.go('/review');
    } on ScanException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(
          () =>
              _error = 'The scan stopped unexpectedly (${error.runtimeType}).',
        );
      }
    }
  }

  List<DraftClass> _toDrafts(List<ParsedClass> classes) {
    final data = ref.read(campusDataProvider);
    final matcher = RoomMatcher(data);
    final drafts = <DraftClass>[];
    for (var index = 0; index < classes.length; index++) {
      final parsed = classes[index];
      final match = matcher.match(parsed.roomText);
      final issues = [...parsed.issues];
      if (match == null) {
        issues.add('Room not found on campus');
      } else if (!match.isExact) {
        issues.add('Check the room code');
      }
      drafts.add(
        DraftClass(
          id: 'scan_$index',
          subject: parsed.subject,
          room: match?.room.name ?? parsed.roomText,
          day: parsed.days.isEmpty ? null : parsed.days.first,
          startMinutes: parsed.startMinutes,
          endMinutes: parsed.endMinutes,
          buildingId: match?.building.id,
          roomIndex: match?.room.indexInBuilding,
          needsReview: issues.isNotEmpty,
          note: issues.isEmpty ? null : issues.join(' · '),
        ),
      );
    }
    return drafts;
  }

  bool _stageDone(ScanStage stage) => _stage.index >= stage.index;

  @override
  Widget build(BuildContext context) {
    return ScreenShell(
      header: const ScreenHeader(title: 'Scanning Study Load'),
      bottom: PillButton(
        label: _error == null ? 'Cancel' : 'Back to upload',
        variant: PillButtonVariant.muted,
        onPressed: () {
          if (_finished) {
            return;
          }
          ref.read(pendingScanFileProvider.notifier).set(null);
          context.go('/upload');
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: const Center(
              child: Icon(
                Icons.description_outlined,
                size: 40,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _error == null ? _progress.clamp(0.02, 1) : 1,
                    minHeight: 4,
                    backgroundColor: AppColors.canvasDeep,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.onCanvas,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _error == null ? '${(_progress * 100).round()}%' : '—',
                style: AppTypography.caption.copyWith(
                  color: AppColors.onCanvas,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _error == null ? 'Scanning Progress' : 'Scan stopped',
            style: AppTypography.cardTitle.copyWith(color: AppColors.onCanvas),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _error ?? 'Reading subjects, rooms, and class times...',
            style: AppTypography.canvasBody,
          ),
          const SizedBox(height: AppSpacing.xl),
          _StageRow(
            label: 'Detecting subjects',
            done: _stageDone(ScanStage.subjects),
          ),
          _StageRow(
            label: 'Reading schedule',
            done: _stageDone(ScanStage.schedule),
          ),
          _StageRow(
            label: 'Matching campus rooms',
            done: _stageDone(ScanStage.rooms),
          ),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: done ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: AppColors.onCanvas),
            ),
            child: done
                ? const Icon(Icons.check, size: 11, color: AppColors.ink)
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTypography.canvasBody.copyWith(color: AppColors.onCanvas),
          ),
        ],
      ),
    );
  }
}
