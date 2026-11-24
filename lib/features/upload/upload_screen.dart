import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/screen_layout.dart';
import '../../services/ocr/study_load_scanner.dart';
import '../scan/scan_providers.dart';

/// `highfi/05-upload-study-load.png`
class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  bool _busy = false;

  Future<void> _takePhoto() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
      );
      if (shot == null) {
        return;
      }
      _startScan(
        StudyLoadFile(path: shot.path, isPdf: false, label: shot.name),
      );
    } on Exception catch (error) {
      _showError('Could not open the camera (${error.runtimeType}).');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _chooseFile() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (files.isEmpty) {
        return; // Student cancelled the picker.
      }
      final file = files.first;
      final path = file.path;
      if (path == null) {
        return; // Not a local file — nothing to scan.
      }
      final extension = (file.extension ?? '').toLowerCase();
      _startScan(
        StudyLoadFile(path: path, isPdf: extension == 'pdf', label: file.name),
      );
    } on Exception catch (error) {
      _showError('Could not open that file (${error.runtimeType}).');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _startScan(StudyLoadFile file) {
    ref.read(pendingScanFileProvider.notifier).set(file);
    if (mounted) {
      context.push('/scan');
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ScreenShell(
      header: const ScreenHeader(title: 'Upload Study Load'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        AppSpacing.lg,
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PillButton(
            label: 'Take Photo',
            variant: PillButtonVariant.primary,
            icon: Icons.photo_camera_outlined,
            onPressed: _busy ? null : _takePhoto,
          ),
          const SizedBox(height: AppSpacing.md),
          PillButton(
            label: 'Choose File',
            variant: PillButtonVariant.muted,
            icon: Icons.folder_open_outlined,
            onPressed: _busy ? null : _chooseFile,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('Supported: JPG, PNG, PDF', style: AppTypography.caption),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Upload or take a photo of your study load to create your class '
            'schedule',
            style: AppTypography.canvasBody,
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: AppColors.dropZone,
              borderRadius: BorderRadius.circular(AppSpacing.dropZoneRadius),
              border: Border.all(
                color: AppColors.onCanvas.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, size: 34, color: AppColors.ink),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Study Load image or PDF',
                  style: AppTypography.cardBody.copyWith(
                    color: AppColors.ink,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
