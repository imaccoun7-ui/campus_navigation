import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/screen_layout.dart';
import '../../data/models/building.dart';
import '../../data/models/campus_data.dart';
import '../../data/repositories/repository_providers.dart';
import '../../services/matching/room_matcher.dart';

/// `highfi/09-results.png` plus the empty state the brief asks for
/// (recent searches and browse-by-building).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  bool _showRooms = true;
  bool _showOffices = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.text != _query) {
        setState(() => _query = _controller.text);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<SearchHit> _hits(CampusData data) {
    final query = _query.trim();
    if (query.isEmpty) {
      return const <SearchHit>[];
    }
    var hits = data.search(query);
    if (hits.isEmpty) {
      final match = RoomMatcher(data).match(query);
      if (match != null) {
        hits = [SearchHit.room(match.building, match.room)];
      }
    }
    return hits
        .where((hit) {
          final room = hit.room;
          if (room == null) {
            return true;
          }
          if (room.looksLikeOffice) {
            return _showOffices;
          }
          return _showRooms;
        })
        .toList(growable: false);
  }

  void _remember(String term) {
    if (term.trim().isEmpty) {
      return;
    }
    ref.read(searchHistoryProvider.notifier).remember(term);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(campusDataProvider);
    final history = ref.watch(searchHistoryProvider);
    final savedBuildings = ref
        .watch(savedBuildingsProvider)
        .map((id) => data.buildingById(id))
        .whereType<Building>()
        .toList(growable: false);
    final hits = _hits(data);
    final searching = _query.trim().isNotEmpty;

    return ScreenShell(
      navIndex: 2,
      header: const ScreenHeader(title: 'Search', showBack: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _controller,
            hintText: 'Room, office or building',
            prefixIcon: Icons.search,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!searching) ...[
            if (history.isNotEmpty) ...[
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recent searches',
                      style: AppTypography.sectionTitle,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(searchHistoryProvider.notifier).clear(),
                    child: Text(
                      'Clear',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.onCanvas,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final term in history)
                    AppChip(
                      label: term,
                      onTap: () {
                        _controller.text = term;
                        _controller.selection = TextSelection.collapsed(
                          offset: term.length,
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            if (savedBuildings.isNotEmpty) ...[
              const Text('Saved buildings', style: AppTypography.sectionTitle),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final building in savedBuildings)
                    AppChip(
                      label: building.name,
                      selected: true,
                      onTap: () => context.push('/map?building=${building.id}'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            const Text('Browse by building', style: AppTypography.sectionTitle),
            const SizedBox(height: AppSpacing.sm),
            for (final building in data.buildings) ...[
              AppCard(
                onTap: () {
                  _remember(building.name);
                  context.push('/map?building=${building.id}');
                },
                semanticLabel: 'Browse ${building.name}',
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(building.name, style: AppTypography.cardTitle),
                          const SizedBox(height: 2),
                          Text(
                            building.hasRoomData
                                ? '${building.roomCount} rooms'
                                : 'No room details yet',
                            style: AppTypography.cardBody,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.inkMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${hits.length} result${hits.length == 1 ? '' : 's'} found',
                    style: AppTypography.canvasBody.copyWith(
                      color: AppColors.onCanvas,
                    ),
                  ),
                ),
                AppChip(
                  label: 'Rooms',
                  selected: _showRooms,
                  onTap: () => setState(() => _showRooms = !_showRooms),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppChip(
                  label: 'Offices',
                  selected: _showOffices,
                  onTap: () => setState(() => _showOffices = !_showOffices),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (hits.isEmpty)
              const AppCard(
                child: Text(
                  'Nothing matched that search.',
                  style: AppTypography.cardBody,
                ),
              )
            else
              for (final hit in hits) ...[
                AppCard(
                  onTap: () => _open(hit),
                  semanticLabel: hit.title,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hit.title, style: AppTypography.cardTitle),
                      const SizedBox(height: 2),
                      Text(hit.subtitle, style: AppTypography.cardBody),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ],
      ),
    );
  }

  void _open(SearchHit hit) {
    _remember(_query.trim());
    final room = hit.room;
    if (room != null) {
      context.push('/room/${hit.building.id}/${room.indexInBuilding}');
      return;
    }
    context.push('/map?building=${hit.building.id}');
  }
}
