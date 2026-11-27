/// Categorized Quick-Switch Strip & Visual Examples Gallery for Quds Studio.
///
/// Enables 1-tap switching across all 21 curated presets (including 12 live
/// real-time motion examples across Physics, Geometry, Waves/Fourier, Chaos,
/// Astronomy, and Radar) on both phone and desktop viewports.
library;

import 'package:flutter/material.dart';

import 'presets.dart';

enum StudioFilterKind {
  all,
  animatedOnly,
  physics,
  chemistry,
  mathematics,
  geometry,
  waves,
  astronomy,
  math3d,
  tools,
}

extension StudioFilterExt on StudioFilterKind {
  String label(bool isArabic) => switch (this) {
        StudioFilterKind.all => isArabic ? 'الكل' : 'All',
        StudioFilterKind.animatedOnly => isArabic ? '⚡ حركة حية' : '⚡ Motion',
        StudioFilterKind.physics => isArabic ? 'فيزياء' : 'Physics',
        StudioFilterKind.chemistry => isArabic ? 'كيمياء' : 'Chemistry',
        StudioFilterKind.mathematics => isArabic ? 'رياضيات' : 'Math',
        StudioFilterKind.geometry => isArabic ? 'هندسة وفن' : 'Geometry',
        StudioFilterKind.waves => isArabic ? 'موجات' : 'Waves',
        StudioFilterKind.astronomy => isArabic ? 'فلك ورادار' : 'Space',
        StudioFilterKind.math3d => isArabic ? '3D وبيانات' : '3D & Data',
        StudioFilterKind.tools => isArabic ? 'أدوات' : 'Tools',
      };

  bool matches(StudioPreset p) => switch (this) {
        StudioFilterKind.all => true,
        StudioFilterKind.animatedOnly => p.isAnimated,
        StudioFilterKind.physics => p.category == StudioCategory.physics,
        StudioFilterKind.chemistry => p.category == StudioCategory.chemistry,
        StudioFilterKind.mathematics =>
          p.category == StudioCategory.mathematics,
        StudioFilterKind.geometry => p.category == StudioCategory.geometry,
        StudioFilterKind.waves => p.category == StudioCategory.waves,
        StudioFilterKind.astronomy => p.category == StudioCategory.astronomy,
        StudioFilterKind.math3d => p.category == StudioCategory.math3d,
        StudioFilterKind.tools => p.category == StudioCategory.tools,
      };
}

List<StudioPreset> filterStudioPresets(StudioFilterKind filter) => [
      for (final p in studioPresets)
        if (filter.matches(p)) p,
    ];

/// Compact 38px horizontal category & 1-tap preset switcher bar.
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
      height: 40,
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
          // Gallery modal button
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: ActionChip(
              key: const Key('btn_preset_gallery'),
              avatar: const Icon(Icons.grid_view_rounded,
                  size: 14, color: Color(0xFF38BDF8)),
              label: Text(
                isArabic ? 'المعرض (${studioPresets.length})' : 'Gallery',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              onPressed: onOpenGallery,
            ),
          ),
          // Category filter pills
          for (final kind in StudioFilterKind.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 5),
              child: ChoiceChip(
                key: Key('filter_${kind.name}'),
                label: Text(
                  kind == StudioFilterKind.animatedOnly
                      ? '${kind.label(isArabic)} (${filterStudioPresets(kind).length})'
                      : kind.label(isArabic),
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600),
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
          // Direct 1-tap preset chips for the active category!
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

/// Opens a full categorized visual gallery dialog to pick any Quds Studio example.
Future<StudioPreset?> showQudsPresetGalleryDialog(
  BuildContext context, {
  required StudioFilterKind initialFilter,
  required String activePresetId,
  required bool isArabic,
  required bool isDark,
}) {
  var currentFilter = initialFilter;
  return showDialog<StudioPreset>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        final items = filterStudioPresets(currentFilter);
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            titlePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            contentPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            title: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 18, color: Color(0xFF38BDF8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'معرض أمثلة قُدس (${items.length})'
                        : 'Quds Examples Gallery (${items.length})',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            content: SizedBox(
              width: 660,
              height: 460,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final kind in StudioFilterKind.values)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 6),
                            child: ChoiceChip(
                              label: Text(
                                '${kind.label(isArabic)} (${filterStudioPresets(kind).length})',
                                style: const TextStyle(fontSize: 11),
                              ),
                              selected: currentFilter == kind,
                              onSelected: (_) =>
                                  setModalState(() => currentFilter = kind),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (ctx, i) {
                        final p = items[i];
                        final selected = p.id == activePresetId;
                        final lineCount = p.code.trim().split('\n').length;
                        return InkWell(
                          key: Key('gallery_item_${p.id}'),
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.of(ctx).pop(p),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF2563EB)
                                      .withValues(alpha: 0.16)
                                  : (isDark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF8FAFC)),
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
                                    color: _categoryColor(p.category)
                                        .withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _categoryIcon(p.category),
                                    size: 18,
                                    color: _categoryColor(p.category),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          color: const Color(0xFFF59E0B)
                                              .withValues(alpha: 0.16),
                                          borderRadius:
                                              BorderRadius.circular(99),
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
                                      isArabic
                                          ? '$lineCount سطر'
                                          : '$lineCount lines',
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

Color _categoryColor(StudioCategory c) => switch (c) {
      StudioCategory.physics => const Color(0xFFEF4444),
      StudioCategory.chemistry => const Color(0xFF14B8A6),
      StudioCategory.mathematics => const Color(0xFF6366F1),
      StudioCategory.geometry => const Color(0xFFEC4899),
      StudioCategory.waves => const Color(0xFF06B6D4),
      StudioCategory.astronomy => const Color(0xFFF59E0B),
      StudioCategory.math3d => const Color(0xFF8B5CF6),
      StudioCategory.tools => const Color(0xFF10B981),
    };

IconData _categoryIcon(StudioCategory c) => switch (c) {
      StudioCategory.physics => Icons.science_rounded,
      StudioCategory.chemistry => Icons.biotech_rounded,
      StudioCategory.mathematics => Icons.functions_rounded,
      StudioCategory.geometry => Icons.auto_awesome_rounded,
      StudioCategory.waves => Icons.waves_rounded,
      StudioCategory.astronomy => Icons.public_rounded,
      StudioCategory.math3d => Icons.view_in_ar_rounded,
      StudioCategory.tools => Icons.build_circle_outlined,
    };
