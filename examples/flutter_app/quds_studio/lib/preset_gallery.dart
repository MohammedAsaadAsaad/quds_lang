/// Creative 2-Level Folder -> Examples Browser & Quick-Switch Bar for Quds Studio.
///
/// Organizes all 54 curated examples (including 45 real-time animated simulations)
/// into 9 color-coded scientific folders (Physics, Chemistry, Mathematics, Waves
/// & Optics, Geometry & Art, Space & Radar, Biology & Medicine, AI/3D, Tools)
/// with instant search, motion-only toggle, breadcrumb drill-in, and 1-tap launch.
library;

import 'package:flutter/material.dart';

import 'presets.dart';

enum StudioFilterKind {
  all,
  animatedOnly,
  physics,
  chemistry,
  mathematics,
  waves,
  geometry,
  astronomy,
  biology,
  math3d,
  tools,
}

extension StudioFilterExt on StudioFilterKind {
  String label(bool isArabic) => switch (this) {
        StudioFilterKind.all => isArabic ? 'الكل' : 'All',
        StudioFilterKind.animatedOnly => isArabic ? '⚡ حركة حية' : '⚡ Motion',
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
        StudioFilterKind.tools => StudioCategory.tools.shortLabel(isArabic),
      };

  StudioCategory? get category => switch (this) {
        StudioFilterKind.physics => StudioCategory.physics,
        StudioFilterKind.chemistry => StudioCategory.chemistry,
        StudioFilterKind.mathematics => StudioCategory.mathematics,
        StudioFilterKind.waves => StudioCategory.waves,
        StudioFilterKind.geometry => StudioCategory.geometry,
        StudioFilterKind.astronomy => StudioCategory.astronomy,
        StudioFilterKind.biology => StudioCategory.biology,
        StudioFilterKind.math3d => StudioCategory.math3d,
        StudioFilterKind.tools => StudioCategory.tools,
        _ => null,
      };

  bool matches(StudioPreset p) => switch (this) {
        StudioFilterKind.all => true,
        StudioFilterKind.animatedOnly => p.isAnimated,
        StudioFilterKind.physics => p.category == StudioCategory.physics,
        StudioFilterKind.chemistry => p.category == StudioCategory.chemistry,
        StudioFilterKind.mathematics =>
          p.category == StudioCategory.mathematics,
        StudioFilterKind.waves => p.category == StudioCategory.waves,
        StudioFilterKind.geometry => p.category == StudioCategory.geometry,
        StudioFilterKind.astronomy => p.category == StudioCategory.astronomy,
        StudioFilterKind.biology => p.category == StudioCategory.biology,
        StudioFilterKind.math3d => p.category == StudioCategory.math3d,
        StudioFilterKind.tools => p.category == StudioCategory.tools,
      };
}

StudioFilterKind filterForCategory(StudioCategory c) => switch (c) {
      StudioCategory.physics => StudioFilterKind.physics,
      StudioCategory.chemistry => StudioFilterKind.chemistry,
      StudioCategory.mathematics => StudioFilterKind.mathematics,
      StudioCategory.waves => StudioFilterKind.waves,
      StudioCategory.geometry => StudioFilterKind.geometry,
      StudioCategory.astronomy => StudioFilterKind.astronomy,
      StudioCategory.biology => StudioFilterKind.biology,
      StudioCategory.math3d => StudioFilterKind.math3d,
      StudioCategory.tools => StudioFilterKind.tools,
    };

List<StudioPreset> filterStudioPresets(StudioFilterKind filter) => [
      for (final p in studioPresets)
        if (filter.matches(p)) p,
    ];

/// Compact 40px horizontal folder strip & 1-tap preset switcher bar.
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
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        children: [
          // Creative 2-Level Folder Hub launcher
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: ActionChip(
              key: const Key('btn_preset_gallery'),
              avatar: const Icon(Icons.folder_special_rounded,
                  size: 15, color: Color(0xFF38BDF8)),
              label: Text(
                isArabic
                    ? 'المجلدات (${studioPresets.length})'
                    : 'Folders (${studioPresets.length})',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.14),
              side: BorderSide(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
              ),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              onPressed: onOpenGallery,
            ),
          ),
          // Folder filter pills with live counts
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
                  isArabic ? _shortTitle(p.titleAr) : _shortTitle(p.titleEn),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: p.id == activePresetId
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                avatar: p.isAnimated
                    ? const Icon(Icons.bolt_rounded,
                        size: 13, color: Color(0xFFF59E0B))
                    : null,
                selected: p.id == activePresetId,
                showCheckmark: false,
                selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.22),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onPressed: () => onSelectPreset(p),
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

/// Result returned when picking an example from the Folder Explorer so the
/// caller can also sync the active folder filter seamlessly.
class QudsGallerySelection {
  const QudsGallerySelection({required this.preset, required this.filter});
  final StudioPreset preset;
  final StudioFilterKind filter;
}

/// Opens the creative 2-level Folder -> Examples Explorer dialog.
///
/// - When [initialFilter] is [StudioFilterKind.all], opens on the visual
///   **Folders Hub Grid** so users pick a folder first, then browse its examples.
/// - When a specific folder/filter is active, opens directly inside that folder
///   with a 1-tap `← المجلدات` breadcrumb back button to switch folders anytime.
/// - Live search filters across all 54 presets instantly.
Future<QudsGallerySelection?> showQudsPresetGalleryDialog(
  BuildContext context, {
  required StudioFilterKind initialFilter,
  required String activePresetId,
  required bool isArabic,
  required bool isDark,
}) {
  // null => Folder Grid view; non-null => inside a specific folder/filter
  StudioFilterKind? openFolder =
      initialFilter == StudioFilterKind.all ? null : initialFilter;
  var animatedOnly = false;
  var searchQuery = '';
  final searchController = TextEditingController();

  return showDialog<QudsGallerySelection>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        final totalAnimated = studioPresets.where((p) => p.isAnimated).length;
        final isSearching = searchQuery.trim().isNotEmpty;

        List<StudioPreset> activeItems() {
          final base = openFolder != null
              ? filterStudioPresets(openFolder!)
              : studioPresets;
          final q = searchQuery.trim().toLowerCase();
          return [
            for (final p in base)
              if ((!animatedOnly || p.isAnimated) &&
                  (q.isEmpty ||
                      p.titleAr.toLowerCase().contains(q) ||
                      p.titleEn.toLowerCase().contains(q) ||
                      p.subtitleAr.toLowerCase().contains(q) ||
                      p.category.label(true).toLowerCase().contains(q) ||
                      p.category.label(false).toLowerCase().contains(q)))
                p,
          ];
        }

        final showFolderGrid = openFolder == null && !isSearching;
        final items = showFolderGrid ? const <StudioPreset>[] : activeItems();

        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 740, maxHeight: 590),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with breadcrumb navigation
                    Row(
                      children: [
                        if (openFolder != null) ...[
                          InkWell(
                            key: const Key('btn_gallery_back_folders'),
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setModalState(() => openFolder = null),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isArabic
                                        ? Icons.arrow_forward_rounded
                                        : Icons.arrow_back_rounded,
                                    size: 15,
                                    color: const Color(0xFF38BDF8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isArabic ? 'المجلدات' : 'Folders',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF38BDF8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ] else ...[
                          const Icon(Icons.folder_special_rounded,
                              size: 20, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            openFolder == null
                                ? (isArabic
                                    ? 'مجلدات الأمثلة العلمية (${studioPresets.length} مثال · ⚡ $totalAnimated متحرك)'
                                    : 'Scientific Folders (${studioPresets.length} · ⚡ $totalAnimated Live)')
                                : (openFolder == StudioFilterKind.animatedOnly
                                    ? (isArabic
                                        ? '⚡ جميع الأمثلة المتحركة (${items.length})'
                                        : '⚡ All Live Motion (${items.length})')
                                    : '${openFolder!.category!.label(isArabic)} (${items.length})'),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded, size: 19),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Live Search + Motion-only filter row
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: TextField(
                              key: const Key('gallery_search_input'),
                              controller: searchController,
                              onChanged: (v) =>
                                  setModalState(() => searchQuery = v),
                              style: const TextStyle(fontSize: 12.5),
                              decoration: InputDecoration(
                                hintText: isArabic
                                    ? 'ابحث في 54 مثالاً (بندول، pH، تايلور، ECG، لورنتز...)'
                                    : 'Search 54 presets (pendulum, pH, Taylor, ECG...)',
                                prefixIcon:
                                    const Icon(Icons.search_rounded, size: 17),
                                suffixIcon: searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded,
                                            size: 15),
                                        onPressed: () {
                                          searchController.clear();
                                          setModalState(() => searchQuery = '');
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          key: const Key('gallery_animated_only_chip'),
                          avatar: const Icon(Icons.bolt_rounded,
                              size: 14, color: Color(0xFFF59E0B)),
                          label: Text(
                            isArabic ? 'متحرك فقط' : 'Live only',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          selected: animatedOnly,
                          onSelected: (v) =>
                              setModalState(() => animatedOnly = v),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Body: EITHER Level 1 Visual Folder Cards Grid OR Level 2 Examples List
                    Expanded(
                      child: showFolderGrid
                          ? _buildFolderHubGrid(
                              ctx: ctx,
                              isArabic: isArabic,
                              isDark: isDark,
                              animatedOnly: animatedOnly,
                              totalAnimated: totalAnimated,
                              onOpenFolder: (f) =>
                                  setModalState(() => openFolder = f),
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
                                  filter: openFolder ??
                                      filterForCategory(p.category),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

Widget _buildFolderHubGrid({
  required BuildContext ctx,
  required bool isArabic,
  required bool isDark,
  required bool animatedOnly,
  required int totalAnimated,
  required ValueChanged<StudioFilterKind> onOpenFolder,
}) {
  final categories = [
    for (final c in StudioCategory.values)
      if (!animatedOnly ||
          studioPresets.any((p) => p.category == c && p.isAnimated))
        c,
  ];

  return LayoutBuilder(
    builder: (context, constraints) {
      final crossCount = constraints.maxWidth >= 560 ? 3 : 2;
      return CustomScrollView(
        key: const Key('gallery_folders_grid'),
        slivers: [
          // Featured banner: All Live Animated Simulations
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                key: const Key('folder_card_animatedOnly'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => onOpenFolder(StudioFilterKind.animatedOnly),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? const [Color(0xFF1E3A8A), Color(0xFF0F766E)]
                          : const [Color(0xFFDBEAFE), Color(0xFFCCFBF1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bolt_rounded,
                            color: Color(0xFFF59E0B), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic
                                  ? 'جميع المحاكيات المتحركة الحية ($totalAnimated)'
                                  : 'All Live Real-Time Simulations ($totalAnimated)',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              isArabic
                                  ? 'فيزياء • كيمياء • رياضيات • موجات • فلك • أحياء وطب • فن هندسي • AI'
                                  : 'Physics • Chemistry • Math • Waves • Space • Bio/Med • Art • AI',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Theme.of(ctx)
                                    .textTheme
                                    .bodySmall
                                    ?.color
                                    ?.withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isArabic
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 2/3-Column Scientific Folder Cards Grid
          SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossCount,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: crossCount == 3 ? 1.48 : 1.32,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, idx) {
                final cat = categories[idx];
                final color = _categoryColor(cat);
                final allInCat =
                    studioPresets.where((p) => p.category == cat).toList();
                final animCount = allInCat.where((p) => p.isAnimated).length;

                return InkWell(
                  key: Key('folder_card_${cat.name}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onOpenFolder(filterForCategory(cat)),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: color.withValues(alpha: 0.38),
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
                            Icon(
                              Icons.folder_open_rounded,
                              size: 15,
                              color: color.withValues(alpha: 0.7),
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
                              fontSize: 10,
                              color: Theme.of(ctx).hintColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              isArabic
                                  ? '${allInCat.length} أمثلة'
                                  : '${allInCat.length} items',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                            const Spacer(),
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
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: categories.length,
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(10),
        onTap: () => onSelect(p),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF2563EB).withValues(alpha: 0.16)
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFF38BDF8)
                  : Colors.grey.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_categoryIcon(p.category), size: 18, color: color),
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
                  if (p.isAnimated)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        isArabic ? '⚡ حركة' : '⚡ Live',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  const SizedBox(height: 3),
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
      StudioCategory.physics => const Color(0xFFEF4444),
      StudioCategory.chemistry => const Color(0xFF14B8A6),
      StudioCategory.mathematics => const Color(0xFF6366F1),
      StudioCategory.waves => const Color(0xFF06B6D4),
      StudioCategory.geometry => const Color(0xFFEC4899),
      StudioCategory.astronomy => const Color(0xFFF59E0B),
      StudioCategory.biology => const Color(0xFF10B981),
      StudioCategory.math3d => const Color(0xFF8B5CF6),
      StudioCategory.tools => const Color(0xFF64748B),
    };

IconData _categoryIcon(StudioCategory c) => switch (c) {
      StudioCategory.physics => Icons.science_rounded,
      StudioCategory.chemistry => Icons.biotech_rounded,
      StudioCategory.mathematics => Icons.functions_rounded,
      StudioCategory.waves => Icons.waves_rounded,
      StudioCategory.geometry => Icons.auto_awesome_rounded,
      StudioCategory.astronomy => Icons.public_rounded,
      StudioCategory.biology => Icons.monitor_heart_rounded,
      StudioCategory.math3d => Icons.view_in_ar_rounded,
      StudioCategory.tools => Icons.build_circle_outlined,
    };
