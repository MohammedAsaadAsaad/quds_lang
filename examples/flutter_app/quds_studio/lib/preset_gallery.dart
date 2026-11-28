/// Redesigned 3-Tier Domain -> Folder -> Examples Library Explorer & Quick Bar
/// for Quds Studio (120+ Register-VM-accelerated presets across 16 categories).
library;

import 'package:flutter/material.dart';

import 'presets.dart';

enum StudioFilterKind {
  all,
  animatedOnly,
  apps,
  games,
  simulations,
  engineering,
  finance,
  benchmarks,
  physics,
  chemistry,
  mathematics,
  waves,
  geometry,
  astronomy,
  biology,
  math3d,
  algorithms,
  language,
  tools,
}

extension StudioFilterExt on StudioFilterKind {
  String label(bool isArabic) => switch (this) {
        StudioFilterKind.all => isArabic ? 'الكل' : 'All',
        StudioFilterKind.animatedOnly => isArabic ? '⚡ حركة حية' : '⚡ Motion',
        StudioFilterKind.apps => StudioCategory.apps.shortLabel(isArabic),
        StudioFilterKind.games => StudioCategory.games.shortLabel(isArabic),
        StudioFilterKind.simulations =>
          StudioCategory.simulations.shortLabel(isArabic),
        StudioFilterKind.engineering =>
          StudioCategory.engineering.shortLabel(isArabic),
        StudioFilterKind.finance => StudioCategory.finance.shortLabel(isArabic),
        StudioFilterKind.benchmarks =>
          StudioCategory.benchmarks.shortLabel(isArabic),
        StudioFilterKind.physics => StudioCategory.physics.shortLabel(isArabic),
        StudioFilterKind.chemistry =>
          StudioCategory.chemistry.shortLabel(isArabic),
        StudioFilterKind.mathematics =>
          StudioCategory.mathematics.shortLabel(isArabic),
        StudioFilterKind.waves => StudioCategory.waves.shortLabel(isArabic),
        StudioFilterKind.geometry =>
          StudioCategory.geometry.shortLabel(isArabic),
        StudioFilterKind.astronomy =>
          StudioCategory.astronomy.shortLabel(isArabic),
        StudioFilterKind.biology => StudioCategory.biology.shortLabel(isArabic),
        StudioFilterKind.math3d => StudioCategory.math3d.shortLabel(isArabic),
        StudioFilterKind.algorithms =>
          StudioCategory.algorithms.shortLabel(isArabic),
        StudioFilterKind.language =>
          StudioCategory.language.shortLabel(isArabic),
        StudioFilterKind.tools => StudioCategory.tools.shortLabel(isArabic),
      };

  StudioCategory? get category => switch (this) {
        StudioFilterKind.apps => StudioCategory.apps,
        StudioFilterKind.games => StudioCategory.games,
        StudioFilterKind.simulations => StudioCategory.simulations,
        StudioFilterKind.engineering => StudioCategory.engineering,
        StudioFilterKind.finance => StudioCategory.finance,
        StudioFilterKind.benchmarks => StudioCategory.benchmarks,
        StudioFilterKind.physics => StudioCategory.physics,
        StudioFilterKind.chemistry => StudioCategory.chemistry,
        StudioFilterKind.mathematics => StudioCategory.mathematics,
        StudioFilterKind.waves => StudioCategory.waves,
        StudioFilterKind.geometry => StudioCategory.geometry,
        StudioFilterKind.astronomy => StudioCategory.astronomy,
        StudioFilterKind.biology => StudioCategory.biology,
        StudioFilterKind.math3d => StudioCategory.math3d,
        StudioFilterKind.algorithms => StudioCategory.algorithms,
        StudioFilterKind.language => StudioCategory.language,
        StudioFilterKind.tools => StudioCategory.tools,
        _ => null,
      };

  bool matches(StudioPreset p) => switch (this) {
        StudioFilterKind.all => true,
        StudioFilterKind.animatedOnly => p.isAnimated,
        StudioFilterKind.apps => p.category == StudioCategory.apps,
        StudioFilterKind.games => p.category == StudioCategory.games,
        StudioFilterKind.simulations =>
          p.category == StudioCategory.simulations,
        StudioFilterKind.engineering =>
          p.category == StudioCategory.engineering,
        StudioFilterKind.finance => p.category == StudioCategory.finance,
        StudioFilterKind.benchmarks => p.category == StudioCategory.benchmarks,
        StudioFilterKind.physics => p.category == StudioCategory.physics,
        StudioFilterKind.chemistry => p.category == StudioCategory.chemistry,
        StudioFilterKind.mathematics =>
          p.category == StudioCategory.mathematics,
        StudioFilterKind.waves => p.category == StudioCategory.waves,
        StudioFilterKind.geometry => p.category == StudioCategory.geometry,
        StudioFilterKind.astronomy => p.category == StudioCategory.astronomy,
        StudioFilterKind.biology => p.category == StudioCategory.biology,
        StudioFilterKind.math3d => p.category == StudioCategory.math3d,
        StudioFilterKind.algorithms => p.category == StudioCategory.algorithms,
        StudioFilterKind.language => p.category == StudioCategory.language,
        StudioFilterKind.tools => p.category == StudioCategory.tools,
      };
}

StudioFilterKind filterForCategory(StudioCategory c) => switch (c) {
      StudioCategory.apps => StudioFilterKind.apps,
      StudioCategory.games => StudioFilterKind.games,
      StudioCategory.simulations => StudioFilterKind.simulations,
      StudioCategory.engineering => StudioFilterKind.engineering,
      StudioCategory.finance => StudioFilterKind.finance,
      StudioCategory.benchmarks => StudioFilterKind.benchmarks,
      StudioCategory.physics => StudioFilterKind.physics,
      StudioCategory.chemistry => StudioFilterKind.chemistry,
      StudioCategory.mathematics => StudioFilterKind.mathematics,
      StudioCategory.waves => StudioFilterKind.waves,
      StudioCategory.geometry => StudioFilterKind.geometry,
      StudioCategory.astronomy => StudioFilterKind.astronomy,
      StudioCategory.biology => StudioFilterKind.biology,
      StudioCategory.math3d => StudioFilterKind.math3d,
      StudioCategory.algorithms => StudioFilterKind.algorithms,
      StudioCategory.language => StudioFilterKind.language,
      StudioCategory.tools => StudioFilterKind.tools,
    };

List<StudioPreset> filterStudioPresets(StudioFilterKind filter) => [
      for (final p in studioPresets)
        if (filter.matches(p)) p,
    ];

/// Compact horizontal quick-access bar with the prominent Library launcher,
/// thematic category pills, and instant 1-tap preset switching.
class QudsPresetQuickBar extends StatelessWidget {
  const QudsPresetQuickBar({
    super.key,
    required this.activeFilter,
    required this.activePresetId,
    required this.isArabic,
    required this.isDark,
    required this.onFilterChanged,
    required this.onSelectPreset,
    required this.onOpenGallery,
  });

  final StudioFilterKind activeFilter;
  final String activePresetId;
  final bool isArabic;
  final bool isDark;
  final ValueChanged<StudioFilterKind> onFilterChanged;
  final ValueChanged<StudioPreset> onSelectPreset;
  final VoidCallback onOpenGallery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9);
    final filtered = filterStudioPresets(activeFilter);

    return Container(
      key: const Key('preset_quick_bar'),
      height: 42,
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Always-visible pinned Library Hub launcher
          Padding(
            padding: const EdgeInsetsDirectional.only(
                start: 8, end: 6, top: 4, bottom: 4),
            child: ActionChip(
              key: const Key('btn_preset_gallery'),
              avatar: const Icon(Icons.auto_awesome_mosaic_rounded,
                  size: 15, color: Color(0xFF38BDF8)),
              label: Text(
                isArabic
                    ? 'المكتبة (${studioPresets.length})'
                    : 'Library (${studioPresets.length})',
                style: const TextStyle(
                    fontSize: 11.2, fontWeight: FontWeight.w800),
              ),
              backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.16),
              side: BorderSide(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.55),
              ),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              onPressed: onOpenGallery,
            ),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              children: [
                // Category filter pills with live counts
                for (final kind in StudioFilterKind.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 5),
                    child: ChoiceChip(
                      key: Key('filter_${kind.name}'),
                      avatar: kind.category != null
                          ? Icon(
                              _categoryIcon(kind.category!),
                              size: 13,
                              color: activeFilter == kind
                                  ? Colors.white
                                  : _categoryColor(kind.category!),
                            )
                          : null,
                      label: Text(
                        kind == StudioFilterKind.all
                            ? kind.label(isArabic)
                            : '${kind.label(isArabic)} (${filterStudioPresets(kind).length})',
                        style: const TextStyle(
                            fontSize: 10.8, fontWeight: FontWeight.w600),
                      ),
                      selected: activeFilter == kind,
                      onSelected: (_) => onFilterChanged(kind),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                VerticalDivider(
                  width: 14,
                  thickness: 1,
                  color: theme.dividerColor.withValues(alpha: 0.35),
                ),
                // Direct 1-tap preset chips for the currently selected folder
                for (final p in filtered)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 5),
                    child: InputChip(
                      key: Key('quick_preset_${p.id}'),
                      label: Text(
                        isArabic
                            ? _shortTitle(p.titleAr)
                            : _shortTitle(p.titleEn),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: p.id == activePresetId
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      avatar: p.category == StudioCategory.games
                          ? const Icon(Icons.sports_esports_rounded,
                              size: 13, color: Color(0xFFA855F7))
                          : (p.isAnimated
                              ? const Icon(Icons.bolt_rounded,
                                  size: 13, color: Color(0xFFF59E0B))
                              : null),
                      selected: p.id == activePresetId,
                      showCheckmark: false,
                      selectedColor:
                          const Color(0xFF2563EB).withValues(alpha: 0.22),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      onPressed: () => onSelectPreset(p),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _shortTitle(String full) {
    final idx = full.indexOf(':');
    return idx >= 0 ? full.substring(idx + 1).trim() : full;
  }
}

/// Result returned when picking an example from the Library Explorer.
class QudsGallerySelection {
  const QudsGallerySelection({required this.preset, required this.filter});
  final StudioPreset preset;
  final StudioFilterKind filter;
}

/// Opens the redesigned 3-Tier Domain -> Folder -> Examples Library Explorer.
///
/// - Groups all 16 categories cleanly under 4 thematic Super-Domains
///   (Games & Real-World Sims, Sciences & Nature, Math/AI/CS, Quds 1.2 & VM).
/// - Provides instant bilingual search across all 120+ presets, 1-tap
///   highlighted filters, motion-only toggle inside folders, and VM badges.
Future<QudsGallerySelection?> showQudsPresetGalleryDialog(
  BuildContext context, {
  required String activePresetId,
  required StudioFilterKind initialFilter,
  required bool isArabic,
  required bool isDark,
}) {
  StudioFilterKind? openFolder =
      initialFilter == StudioFilterKind.all ? null : initialFilter;
  var searchQuery = '';
  var animatedOnlyInFolder = false;
  final searchController = TextEditingController();

  return showDialog<QudsGallerySelection>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final q = searchQuery.trim().toLowerCase();
        final isSearching = q.isNotEmpty;

        final List<StudioPreset> items = isSearching
            ? studioPresets
                .where((p) =>
                    p.titleAr.toLowerCase().contains(q) ||
                    p.titleEn.toLowerCase().contains(q) ||
                    p.subtitleAr.toLowerCase().contains(q) ||
                    p.fileName.toLowerCase().contains(q) ||
                    p.category.label(true).toLowerCase().contains(q) ||
                    p.category.label(false).toLowerCase().contains(q) ||
                    p.category.domain.label(true).toLowerCase().contains(q))
                .toList()
            : openFolder != null
                ? filterStudioPresets(openFolder!)
                    .where((p) => !animatedOnlyInFolder || p.isAnimated)
                    .toList()
                : const <StudioPreset>[];

        final totalAnimated = studioPresets.where((p) => p.isAnimated).length;
        final totalGames = studioPresets
            .where((p) => p.category == StudioCategory.games)
            .length;

        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Header with title + VM speed pill + close
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome_mosaic_rounded,
                            size: 20, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic
                                  ? 'مكتبة قدس التفاعلية (${studioPresets.length} مثال)'
                                  : 'Quds Interactive Library (${studioPresets.length} presets)',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              isArabic
                                  ? '16 تصنيفاً منظماً · $totalGames ألعاب · $totalAnimated محاكاة حية · محرك ⚡ Register VM'
                                  : '16 categories · $totalGames games · $totalAnimated animated · ⚡ Register VM',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Theme.of(ctx).hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search input with clear button
                  TextField(
                    key: const Key('gallery_search_input'),
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: isArabic
                          ? 'ابحث في ${studioPresets.length} مثالاً (لعبة، مرور، روبوت، بورصة، فيزياء، قدس...)'
                          : 'Search ${studioPresets.length} presets (game, traffic, robot, finance, physics...)',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: isSearching
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                searchController.clear();
                                setState(() => searchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(() => searchQuery = v),
                  ),
                  const SizedBox(height: 8),

                  // Quick spotlight filter bar when browsing folders
                  if (!isSearching && openFolder == null)
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _spotlightChip(
                            label: isArabic
                                ? '🎮 ألعاب ($totalGames)'
                                : '🎮 Games ($totalGames)',
                            color: const Color(0xFFA855F7),
                            onTap: () => setState(() {
                              openFolder = StudioFilterKind.games;
                              animatedOnlyInFolder = false;
                            }),
                          ),
                          _spotlightChip(
                            label: isArabic
                                ? '🏙️ محاكاة واقعية (${filterStudioPresets(StudioFilterKind.simulations).length})'
                                : '🏙️ Real Sims (${filterStudioPresets(StudioFilterKind.simulations).length})',
                            color: const Color(0xFF0EA5E9),
                            onTap: () => setState(() {
                              openFolder = StudioFilterKind.simulations;
                              animatedOnlyInFolder = false;
                            }),
                          ),
                          _spotlightChip(
                            label: isArabic
                                ? '⚡ حركة حية ($totalAnimated)'
                                : '⚡ Live Motion ($totalAnimated)',
                            color: const Color(0xFFF59E0B),
                            onTap: () => setState(() {
                              openFolder = StudioFilterKind.animatedOnly;
                              animatedOnlyInFolder = false;
                            }),
                          ),
                          _spotlightChip(
                            label: isArabic
                                ? '🚀 اختبارات VM (${filterStudioPresets(StudioFilterKind.benchmarks).length})'
                                : '🚀 VM Bench (${filterStudioPresets(StudioFilterKind.benchmarks).length})',
                            color: const Color(0xFFF97316),
                            onTap: () => setState(() {
                              openFolder = StudioFilterKind.benchmarks;
                              animatedOnlyInFolder = false;
                            }),
                          ),
                          _spotlightChip(
                            label: isArabic
                                ? '✨ قدس 1.2 (${filterStudioPresets(StudioFilterKind.language).length})'
                                : '✨ Quds 1.2 (${filterStudioPresets(StudioFilterKind.language).length})',
                            color: const Color(0xFF10B981),
                            onTap: () => setState(() {
                              openFolder = StudioFilterKind.language;
                              animatedOnlyInFolder = false;
                            }),
                          ),
                        ],
                      ),
                    ),

                  // Breadcrumb bar when inside a folder or searching
                  if (openFolder != null || isSearching)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          TextButton.icon(
                            key: const Key('btn_gallery_back_folders'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: Icon(
                              isArabic
                                  ? Icons.arrow_forward_rounded
                                  : Icons.arrow_back_rounded,
                              size: 16,
                            ),
                            label: Text(
                              isArabic ? 'كل التصنيفات' : 'All Categories',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            onPressed: () {
                              searchController.clear();
                              setState(() {
                                openFolder = null;
                                searchQuery = '';
                                animatedOnlyInFolder = false;
                              });
                            },
                          ),
                          const SizedBox(width: 6),
                          if (openFolder?.category != null && !isSearching) ...[
                            Icon(
                              _categoryIcon(openFolder!.category!),
                              size: 16,
                              color: _categoryColor(openFolder!.category!),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Expanded(
                            child: Text(
                              isSearching
                                  ? (isArabic
                                      ? 'نتائج البحث (${items.length})'
                                      : 'Search results (${items.length})')
                                  : (openFolder == StudioFilterKind.animatedOnly
                                      ? (isArabic
                                          ? '⚡ حركة حية (${items.length})'
                                          : '⚡ Live Motion (${items.length})')
                                      : '${openFolder!.category!.label(isArabic)} (${items.length})'),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w800),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isSearching &&
                              openFolder != null &&
                              openFolder != StudioFilterKind.animatedOnly &&
                              filterStudioPresets(openFolder!)
                                  .any((p) => p.isAnimated))
                            FilterChip(
                              label: Text(
                                isArabic ? '⚡ حركي فقط' : '⚡ Live only',
                                style: const TextStyle(fontSize: 10.5),
                              ),
                              selected: animatedOnlyInFolder,
                              onSelected: (v) =>
                                  setState(() => animatedOnlyInFolder = v),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ),

                  if (!isSearching && openFolder == null)
                    const SizedBox(height: 8),

                  // Body: Either Grouped 4-Domain Folder Hub OR Examples List
                  Expanded(
                    child: (!isSearching && openFolder == null)
                        ? _buildGroupedFoldersHub(
                            ctx: ctx,
                            isArabic: isArabic,
                            isDark: isDark,
                            onOpenFolder: (f) => setState(() {
                              openFolder = f;
                              animatedOnlyInFolder = false;
                            }),
                          )
                        : _buildExamplesList(
                            ctx: ctx,
                            items: items,
                            activePresetId: activePresetId,
                            isArabic: isArabic,
                            isDark: isDark,
                            onSelect: (p) => Navigator.of(ctx).pop(
                              QudsGallerySelection(
                                preset: p,
                                filter:
                                    openFolder ?? filterForCategory(p.category),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

Widget _spotlightChip({
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return Padding(
    padding: const EdgeInsetsDirectional.only(end: 6),
    child: ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      onPressed: onTap,
    ),
  );
}

Widget _buildGroupedFoldersHub({
  required BuildContext ctx,
  required bool isArabic,
  required bool isDark,
  required ValueChanged<StudioFilterKind> onOpenFolder,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final crossCount = constraints.maxWidth >= 640 ? 3 : 2;
      final slivers = <Widget>[];

      for (final domain in StudioDomain.values) {
        final cats = domain.categories;
        final domainTotal = cats.fold<int>(
          0,
          (sum, c) => sum + studioPresets.where((p) => p.category == c).length,
        );

        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 7),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      domain.label(isArabic),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$domainTotal',
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        slivers.add(
          SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossCount,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: crossCount == 3 ? 1.52 : 1.30,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, idx) {
                final cat = cats[idx];
                final color = _categoryColor(cat);
                final allInCat =
                    studioPresets.where((p) => p.category == cat).toList();
                final animCount = allInCat.where((p) => p.isAnimated).length;

                return InkWell(
                  key: Key('folder_card_${cat.name}'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onOpenFolder(filterForCategory(cat)),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: color.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _categoryIcon(cat),
                                size: 17,
                                color: color,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '${allInCat.length}',
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cat.label(isArabic),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Expanded(
                          child: Text(
                            cat.description(isArabic),
                            style: TextStyle(
                              fontSize: 9.8,
                              color: Theme.of(ctx).hintColor,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            if (animCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  '⚡ $animCount',
                                  style: const TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFF59E0B),
                                  ),
                                ),
                              ),
                            const Spacer(),
                            Icon(
                              isArabic
                                  ? Icons.chevron_left_rounded
                                  : Icons.chevron_right_rounded,
                              size: 16,
                              color: color.withValues(alpha: 0.8),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: cats.length,
            ),
          ),
        );
      }

      return CustomScrollView(
        key: const Key('gallery_folders_grid'),
        slivers: slivers,
      );
    },
  );
}

Widget _buildExamplesList({
  required BuildContext ctx,
  required List<StudioPreset> items,
  required String activePresetId,
  required bool isArabic,
  required bool isDark,
  required ValueChanged<StudioPreset> onSelect,
}) {
  if (items.isEmpty) {
    return Center(
      child: Text(
        isArabic ? 'لا توجد أمثلة مطابقة للبحث' : 'No matching presets found',
        style: TextStyle(fontSize: 13, color: Theme.of(ctx).hintColor),
      ),
    );
  }
  return ListView.separated(
    key: const Key('gallery_examples_list'),
    itemCount: items.length,
    separatorBuilder: (_, __) => const SizedBox(height: 6),
    itemBuilder: (ctx, i) {
      final p = items[i];
      final selected = p.id == activePresetId;
      final lineCount = p.code.trim().split('\n').length;
      final color = _categoryColor(p.category);
      return InkWell(
        key: Key('gallery_item_${p.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => onSelect(p),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF2563EB).withValues(alpha: 0.16)
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF38BDF8)
                  : color.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(_categoryIcon(p.category), size: 19, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? p.titleAr : p.titleEn,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.subtitleAr,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(ctx).hintColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (p.isAnimated)
                        Container(
                          margin: const EdgeInsetsDirectional.only(end: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFF59E0B).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            isArabic ? '⚡ حي' : '⚡ Live',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF2563EB).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'VM',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isArabic ? '$lineCount سطر' : '$lineCount lines',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10,
                      color: Theme.of(ctx).hintColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Color _categoryColor(StudioCategory c) => switch (c) {
      StudioCategory.apps => const Color(0xFF10B981),
      StudioCategory.games => const Color(0xFFA855F7),
      StudioCategory.simulations => const Color(0xFF0EA5E9),
      StudioCategory.engineering => const Color(0xFF3B82F6),
      StudioCategory.finance => const Color(0xFF22C55E),
      StudioCategory.physics => const Color(0xFFEF4444),
      StudioCategory.chemistry => const Color(0xFF14B8A6),
      StudioCategory.mathematics => const Color(0xFF6366F1),
      StudioCategory.waves => const Color(0xFF06B6D4),
      StudioCategory.geometry => const Color(0xFFEC4899),
      StudioCategory.astronomy => const Color(0xFFF59E0B),
      StudioCategory.biology => const Color(0xFF10B981),
      StudioCategory.math3d => const Color(0xFF8B5CF6),
      StudioCategory.algorithms => const Color(0xFFEAB308),
      StudioCategory.language => const Color(0xFF34D399),
      StudioCategory.tools => const Color(0xFF64748B),
      StudioCategory.benchmarks => const Color(0xFFF97316),
    };

IconData _categoryIcon(StudioCategory c) => switch (c) {
      StudioCategory.apps => Icons.widgets_rounded,
      StudioCategory.games => Icons.sports_esports_rounded,
      StudioCategory.simulations => Icons.location_city_rounded,
      StudioCategory.engineering => Icons.precision_manufacturing_rounded,
      StudioCategory.finance => Icons.trending_up_rounded,
      StudioCategory.physics => Icons.science_rounded,
      StudioCategory.chemistry => Icons.biotech_rounded,
      StudioCategory.mathematics => Icons.functions_rounded,
      StudioCategory.waves => Icons.waves_rounded,
      StudioCategory.geometry => Icons.auto_awesome_rounded,
      StudioCategory.astronomy => Icons.public_rounded,
      StudioCategory.biology => Icons.monitor_heart_rounded,
      StudioCategory.math3d => Icons.view_in_ar_rounded,
      StudioCategory.algorithms => Icons.account_tree_rounded,
      StudioCategory.language => Icons.code_rounded,
      StudioCategory.tools => Icons.build_circle_outlined,
      StudioCategory.benchmarks => Icons.speed_rounded,
    };
