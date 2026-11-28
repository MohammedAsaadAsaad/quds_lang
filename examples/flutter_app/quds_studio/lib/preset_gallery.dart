/// Hierarchical Collapsible Tree Explorer & Sleek Context Bar for Quds Studio
/// (138 Register-VM presets across 18 categories + 5 full multi-folder Workspaces).
library;

import 'package:flutter/material.dart';

import 'presets.dart';
import 'project_templates.dart';

enum StudioFilterKind {
  all,
  animatedOnly,
  pen,
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
        StudioFilterKind.pen => StudioCategory.pen.shortLabel(isArabic),
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
        StudioFilterKind.pen => StudioCategory.pen,
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
        StudioFilterKind.pen => p.category == StudioCategory.pen,
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
      StudioCategory.pen => StudioFilterKind.pen,
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

/// Clean, uncluttered top Explorer Bar replacing the crowded horizontal strip:
/// - 1-tap Tree Explorer launcher (`btn_preset_gallery`)
/// - 1-tap Full Workspaces launcher (`btn_open_workspaces_tree`)
/// - Current active item breadcrumb (preset or multi-folder Workspace)
/// - Quick Prev/Next stepping buttons
class QudsPresetQuickBar extends StatelessWidget {
  const QudsPresetQuickBar({
    super.key,
    required this.activeFilter,
    required this.activePreset,
    required this.workspaceMode,
    required this.activeWorkspaceName,
    required this.isArabic,
    required this.isDark,
    required this.onOpenGallery,
    required this.onOpenWorkspaces,
  });

  final StudioFilterKind activeFilter;
  final StudioPreset activePreset;
  final bool workspaceMode;
  final String activeWorkspaceName;
  final bool isArabic;
  final bool isDark;
  final VoidCallback onOpenGallery;
  final VoidCallback onOpenWorkspaces;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9);
    final totalItems = studioPresets.length + studioProjectTemplates.length;

    final activeTitle = workspaceMode
        ? activeWorkspaceName
        : (isArabic ? activePreset.titleAr : activePreset.titleEn);
    final activeCategoryLabel = workspaceMode
        ? (isArabic ? '📦 مشروع متكامل' : '📦 Workspace')
        : activePreset.category.shortLabel(isArabic);
    final activeColor = workspaceMode
        ? const Color(0xFF10B981)
        : _categoryColor(activePreset.category);

    return Container(
      key: const Key('preset_quick_bar'),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 560;
          return Row(
            children: [
              // 1. Hierarchical Examples & Projects Tree Explorer Launcher
              if (narrow)
                Expanded(
                  child: FilledButton.tonalIcon(
                    key: const Key('btn_preset_gallery'),
                    onPressed: onOpenGallery,
                    icon: const Icon(Icons.account_tree_rounded,
                        size: 15, color: Color(0xFF38BDF8)),
                    label: Text(
                      isArabic
                          ? 'شجرة الأمثلة ($totalItems)'
                          : 'Examples Tree ($totalItems)',
                      style: const TextStyle(
                          fontSize: 11.2, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF2563EB).withValues(alpha: 0.16),
                      foregroundColor:
                          isDark ? Colors.white : const Color(0xFF0F172A),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      side: BorderSide(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                )
              else
                FilledButton.tonalIcon(
                  key: const Key('btn_preset_gallery'),
                  onPressed: onOpenGallery,
                  icon: const Icon(Icons.account_tree_rounded,
                      size: 15, color: Color(0xFF38BDF8)),
                  label: Text(
                    isArabic
                        ? 'شجرة الأمثلة ($totalItems)'
                        : 'Examples Tree ($totalItems)',
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF2563EB).withValues(alpha: 0.16),
                    foregroundColor:
                        isDark ? Colors.white : const Color(0xFF0F172A),
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    side: BorderSide(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                    ),
                  ),
                ),
              const SizedBox(width: 6),

              // 2. Direct 1-tap Full Multi-Folder Workspaces Launcher
              OutlinedButton.icon(
                key: const Key('btn_open_workspaces_tree'),
                onPressed: onOpenWorkspaces,
                icon: const Icon(Icons.workspaces_rounded,
                    size: 14, color: Color(0xFF10B981)),
                label: Text(
                  isArabic
                      ? 'المشاريع (${studioProjectTemplates.length})'
                      : 'Workspaces (${studioProjectTemplates.length})',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  side: BorderSide(
                    color: const Color(0xFF10B981).withValues(alpha: 0.45),
                  ),
                ),
              ),

              // 3. Active Item Breadcrumb Pill on wide layouts (mobile toolbar already shows it)
              if (!narrow) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: onOpenGallery,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: activeColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: activeColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: activeColor.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              activeCategoryLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: activeColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              activeTitle,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.unfold_more_rounded,
                              size: 15, color: theme.hintColor),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Result returned when picking an item from the Examples & Workspaces Tree.
class QudsGallerySelection {
  const QudsGallerySelection.preset({
    required StudioPreset this.preset,
    required this.filter,
    this.launchFullscreen = false,
  }) : workspaceTemplate = null;

  const QudsGallerySelection.workspace({
    required StudioProjectTemplate this.workspaceTemplate,
    this.launchFullscreen = false,
  })  : preset = null,
        filter = StudioFilterKind.all;

  final StudioPreset? preset;
  final StudioProjectTemplate? workspaceTemplate;
  final StudioFilterKind filter;
  final bool launchFullscreen;
}

/// Opens the Hierarchical Collapsible Tree Explorer for all 138 Quds presets
/// (grouped by Domain -> Category -> Example) AND all 5 full multi-folder
/// Workspace projects (`quds_shop_pos`, `sales_analytics_hub`,
/// `quds_extensions_host`, `pixel_asset_studio`, `orbital_lab`).
///
/// - Starts with ALL nodes collapsed by default (unless `expandWorkspaces` is
///   true), keeping navigation ultra-clean and uncluttered.
/// - Clearly marks the branch containing the currently open example/workspace
///   with an active badge, highlights the open item when expanded, and offers a
///   1-tap "إظهار المفتوح / Reveal Active" button + live instant search!
Future<QudsGallerySelection?> showQudsPresetGalleryDialog(
  BuildContext context, {
  required String activePresetId,
  required bool workspaceMode,
  required String activeWorkspaceId,
  required StudioFilterKind initialFilter,
  required bool isArabic,
  required bool isDark,
  bool expandWorkspaces = false,
}) {
  return showDialog<QudsGallerySelection>(
    context: context,
    builder: (_) => _QudsExamplesTreeDialog(
      activePresetId: activePresetId,
      workspaceMode: workspaceMode,
      activeWorkspaceId: activeWorkspaceId,
      isArabic: isArabic,
      isDark: isDark,
      expandWorkspaces: expandWorkspaces,
    ),
  );
}

class _QudsExamplesTreeDialog extends StatefulWidget {
  const _QudsExamplesTreeDialog({
    required this.activePresetId,
    required this.workspaceMode,
    required this.activeWorkspaceId,
    required this.isArabic,
    required this.isDark,
    required this.expandWorkspaces,
  });

  final String activePresetId;
  final bool workspaceMode;
  final String activeWorkspaceId;
  final bool isArabic;
  final bool isDark;
  final bool expandWorkspaces;

  @override
  State<_QudsExamplesTreeDialog> createState() =>
      _QudsExamplesTreeDialogState();
}

class _QudsExamplesTreeDialogState extends State<_QudsExamplesTreeDialog> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // All nodes start COLLAPSED cleanly by default (unless Workspaces shortcut was tapped)
  late bool _workspacesExpanded;
  final Set<StudioDomain> _expandedDomains = {};
  final Set<StudioCategory> _expandedCategories = {};
  bool _motionOnly = false;
  String _query = '';

  StudioPreset? get _activePreset {
    if (widget.workspaceMode) return null;
    for (final p in studioPresets) {
      if (p.id == widget.activePresetId) return p;
    }
    return null;
  }

  StudioProjectTemplate? get _activeWorkspace {
    if (!widget.workspaceMode) return null;
    for (final t in studioProjectTemplates) {
      if (t.id == widget.activeWorkspaceId) return t;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _workspacesExpanded = widget.expandWorkspaces;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _collapseAll() {
    setState(() {
      _workspacesExpanded = false;
      _expandedDomains.clear();
      _expandedCategories.clear();
    });
  }

  void _revealActiveInTree() {
    setState(() {
      _query = '';
      _searchController.clear();
      _motionOnly = false;
      _workspacesExpanded = false;
      _expandedDomains.clear();
      _expandedCategories.clear();
      if (widget.workspaceMode) {
        _workspacesExpanded = true;
      } else {
        final active = _activePreset;
        if (active != null) {
          _expandedDomains.add(active.category.domain);
          _expandedCategories.add(active.category);
        }
      }
    });
  }

  List<StudioPreset> _presetsInCategory(StudioCategory cat) => [
        for (final p in studioPresets)
          if (p.category == cat && (!_motionOnly || p.isAnimated)) p,
      ];

  @override
  Widget build(BuildContext context) {
    final dialogTheme = ThemeData(
      useMaterial3: true,
      brightness: widget.isDark ? Brightness.dark : Brightness.light,
      fontFamily: 'IBMPlexSansArabic',
      colorSchemeSeed: const Color(0xFF2563EB),
    );
    final bg = widget.isDark ? const Color(0xFF0F172A) : Colors.white;
    final panelBg =
        widget.isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);
    final fg =
        widget.isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final sub =
        widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final chipBg =
        widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final q = _query.trim().toLowerCase();
    final isSearching = q.isNotEmpty;

    final activePreset = _activePreset;
    final activeWs = _activeWorkspace;
    final activeDomain = activePreset?.category.domain;
    final activeCategory = activePreset?.category;

    final matchingWorkspaces = isSearching
        ? studioProjectTemplates.where((t) {
            final hay =
                '${t.id} ${t.nameAr} ${t.nameEn} ${t.subtitleAr} ${t.subtitleEn}'
                    .toLowerCase();
            return hay.contains(q);
          }).toList()
        : const <StudioProjectTemplate>[];

    final matchingPresets = isSearching
        ? studioPresets.where((p) {
            if (_motionOnly && !p.isAnimated) return false;
            final hay =
                '${p.id} ${p.titleAr} ${p.titleEn} ${p.subtitleAr} ${p.fileName} ${p.category.label(true)} ${p.category.label(false)}'
                    .toLowerCase();
            return hay.contains(q);
          }).toList()
        : const <StudioPreset>[];

    final totalCount = studioPresets.length + studioProjectTemplates.length;

    return Theme(
      data: dialogTheme,
      child: Directionality(
        textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Dialog(
          key: const Key('quds_examples_tree_dialog'),
          backgroundColor: bg,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860, maxHeight: 740),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF10B981)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_tree_rounded,
                            size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isArabic
                                  ? 'مستعرض شجرة الأمثلة والمشاريع ($totalCount)'
                                  : 'Quds Examples & Workspaces Tree ($totalCount)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: fg,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.isArabic
                                  ? '${studioProjectTemplates.length} مشاريع كاملة (Workspaces) · ${studioPresets.length} مثالاً في ${StudioCategory.values.length} تصنيفاً — كل الفروع مطوية افتراضياً'
                                  : '${studioProjectTemplates.length} full Workspaces · ${studioPresets.length} presets across ${StudioCategory.values.length} categories',
                              style: TextStyle(fontSize: 11, color: sub),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded, color: sub),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 2. Search
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('gallery_search_input'),
                          controller: _searchController,
                          onChanged: (v) => setState(() => _query = v),
                          style: TextStyle(fontSize: 12.5, color: fg),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: panelBg,
                            prefixIcon: Icon(Icons.search_rounded,
                                size: 18, color: sub),
                            suffixIcon: _query.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear_rounded,
                                        size: 16, color: sub),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                  )
                                : null,
                            hintText: widget.isArabic
                                ? 'ابحث في 138 مثالاً و5 مشاريع (مثل: pen، فراكتل، POS، ECG، إضافات)...'
                                : 'Search 138 presets & 5 Workspaces (e.g. pen, fractal, POS, ECG)...',
                            hintStyle: TextStyle(fontSize: 12, color: sub),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: dialogTheme.dividerColor
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 3. Active Item Banner + Reveal / Collapse All / Motion filter
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Active currently-open item indicator + 1-tap Reveal in Tree!
                        ActionChip(
                          key: const Key('btn_reveal_active'),
                          avatar: const Icon(Icons.my_location_rounded,
                              size: 14, color: Color(0xFF38BDF8)),
                          label: Text(
                            widget.isArabic
                                ? 'المفتوح الآن: ${activeWs != null ? activeWs.nameAr : (activePreset?.titleAr ?? '')}'
                                : 'Open: ${activeWs != null ? activeWs.nameEn : (activePreset?.titleEn ?? '')}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: fg,
                            ),
                          ),
                          backgroundColor:
                              const Color(0xFF2563EB).withValues(alpha: 0.24),
                          side: BorderSide(
                            color:
                                const Color(0xFF38BDF8).withValues(alpha: 0.55),
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: _revealActiveInTree,
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          key: const Key('btn_collapse_all'),
                          avatar: Icon(Icons.unfold_less_rounded,
                              size: 14, color: fg),
                          label: Text(
                            widget.isArabic ? 'طي الكل' : 'Collapse All',
                            style: TextStyle(fontSize: 11, color: fg),
                          ),
                          backgroundColor: chipBg,
                          side: BorderSide(
                            color:
                                dialogTheme.dividerColor.withValues(alpha: 0.3),
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: _collapseAll,
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          key: const Key('chip_tree_motion_only'),
                          selected: _motionOnly,
                          avatar: const Icon(Icons.bolt_rounded,
                              size: 14, color: Color(0xFFF59E0B)),
                          label: Text(
                            widget.isArabic
                                ? 'الحركة الحية فقط'
                                : 'Motion Only',
                            style: TextStyle(fontSize: 11, color: fg),
                          ),
                          backgroundColor: chipBg,
                          selectedColor:
                              const Color(0xFFF59E0B).withValues(alpha: 0.24),
                          side: BorderSide(
                            color:
                                dialogTheme.dividerColor.withValues(alpha: 0.3),
                          ),
                          visualDensity: VisualDensity.compact,
                          onSelected: (v) => setState(() => _motionOnly = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 4. Main Tree Body (or Instant Search Results)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: panelBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              dialogTheme.dividerColor.withValues(alpha: 0.28),
                        ),
                      ),
                      child: isSearching
                          ? _buildSearchResults(
                              dialogTheme, matchingWorkspaces, matchingPresets)
                          : ListView(
                              key: const Key('examples_tree_list'),
                              controller: _scrollController,
                              padding: const EdgeInsets.all(8),
                              children: [
                                // Root Node 0: Full Multi-Folder Workspaces (with assets/)
                                _buildWorkspacesRootNode(dialogTheme),
                                const SizedBox(height: 6),
                                // Root Nodes 1..4: Super-Domains -> Categories -> Examples
                                for (final domain in StudioDomain.values) ...[
                                  _buildDomainTreeNode(
                                    dialogTheme,
                                    domain,
                                    containsActive: !widget.workspaceMode &&
                                        activeDomain == domain,
                                    activeCategory: activeCategory,
                                  ),
                                  const SizedBox(height: 6),
                                ],
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspacesRootNode(ThemeData theme) {
    final containsActive = widget.workspaceMode;
    const accent = Color(0xFF10B981);

    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: containsActive
              ? accent
              : accent.withValues(alpha: _workspacesExpanded ? 0.5 : 0.25),
          width: containsActive ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const Key('tree_node_workspaces'),
            borderRadius: BorderRadius.circular(10),
            onTap: () =>
                setState(() => _workspacesExpanded = !_workspacesExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Icon(
                    _workspacesExpanded
                        ? Icons.expand_more_rounded
                        : (widget.isArabic
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded),
                    size: 20,
                    color: accent,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(Icons.workspaces_rounded,
                        size: 16, color: accent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isArabic
                              ? '📦 مشاريع كاملة متعددة المجلدات والأصول (Workspaces)'
                              : '📦 Full Multi-Folder Projects with Assets (Workspaces)',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          widget.isArabic
                              ? 'متجر POS، تحليلات CSV، مضيف الإضافات Extensions، استوديو BMP، والمختبر الفيزيائي'
                              : 'POS Shop, Sales Analytics, Extensions Host, Pixel BMP Studio & Orbital Lab',
                          style:
                              TextStyle(fontSize: 10.5, color: theme.hintColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (containsActive) _buildActiveDotBadge(accent),
                  const SizedBox(width: 6),
                  _buildCountPill('${studioProjectTemplates.length}', accent),
                ],
              ),
            ),
          ),
          if (_workspacesExpanded) ...[
            Divider(
                height: 1, color: theme.dividerColor.withValues(alpha: 0.2)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Column(
                children: [
                  for (final tpl in studioProjectTemplates)
                    _buildWorkspaceLeafRow(theme, tpl),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkspaceLeafRow(ThemeData theme, StudioProjectTemplate tpl) {
    final selected = widget.workspaceMode && widget.activeWorkspaceId == tpl.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: InkWell(
        key: Key('tree_workspace_${tpl.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context)
            .pop(QudsGallerySelection.workspace(workspaceTemplate: tpl)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? tpl.accentColor.withValues(alpha: 0.16)
                : (widget.isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.45)
                    : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? tpl.accentColor
                  : theme.dividerColor.withValues(alpha: 0.2),
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(tpl.icon, size: 17, color: tpl.accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isArabic ? tpl.nameAr : tpl.nameEn,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? tpl.accentColor : null,
                      ),
                    ),
                    Text(
                      widget.isArabic ? tpl.subtitleAr : tpl.subtitleEn,
                      style: TextStyle(fontSize: 10.5, color: theme.hintColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                key: Key('tree_workspace_fullscreen_${tpl.id}'),
                borderRadius: BorderRadius.circular(6),
                onTap: () => Navigator.of(context).pop(
                  QudsGallerySelection.workspace(
                    workspaceTemplate: tpl,
                    launchFullscreen: true,
                  ),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.open_in_full_rounded,
                        size: 11,
                        color: Color(0xFF818CF8),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        widget.isArabic ? 'تطبيق' : 'App',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF818CF8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              if (selected)
                _buildSelectedLeafBadge(tpl.accentColor)
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: tpl.accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.isArabic ? 'فتح' : 'Open',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: tpl.accentColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDomainTreeNode(
    ThemeData theme,
    StudioDomain domain, {
    required bool containsActive,
    required StudioCategory? activeCategory,
  }) {
    final expanded = _expandedDomains.contains(domain);
    final accent = _domainAccent(domain);
    final domainTotal = domain.categories
        .fold<int>(0, (sum, cat) => sum + _presetsInCategory(cat).length);

    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: containsActive
              ? const Color(0xFF38BDF8)
              : theme.dividerColor.withValues(alpha: 0.25),
          width: containsActive ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('tree_domain_${domain.name}'),
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() {
              if (expanded) {
                _expandedDomains.remove(domain);
              } else {
                _expandedDomains.add(domain);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Icon(
                    expanded
                        ? Icons.expand_more_rounded
                        : (widget.isArabic
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded),
                    size: 20,
                    color: accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      domain.label(widget.isArabic),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (containsActive)
                    _buildActiveDotBadge(const Color(0xFF38BDF8)),
                  const SizedBox(width: 6),
                  _buildCountPill('$domainTotal', accent),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(
                height: 1, color: theme.dividerColor.withValues(alpha: 0.18)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Column(
                children: [
                  for (final cat in domain.categories)
                    _buildCategoryTreeNode(
                      theme,
                      cat,
                      containsActive:
                          !widget.workspaceMode && activeCategory == cat,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryTreeNode(
    ThemeData theme,
    StudioCategory cat, {
    required bool containsActive,
  }) {
    final items = _presetsInCategory(cat);
    if (items.isEmpty) return const SizedBox.shrink();
    final expanded = _expandedCategories.contains(cat);
    final accent = _categoryColor(cat);

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.4)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: containsActive
                ? accent
                : theme.dividerColor.withValues(alpha: 0.2),
            width: containsActive ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              key: Key('folder_card_${cat.name}'),
              borderRadius: BorderRadius.circular(9),
              onTap: () => setState(() {
                if (expanded) {
                  _expandedCategories.remove(cat);
                } else {
                  _expandedCategories.add(cat);
                }
              }),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(
                  children: [
                    Icon(
                      expanded
                          ? Icons.expand_more_rounded
                          : (widget.isArabic
                              ? Icons.chevron_left_rounded
                              : Icons.chevron_right_rounded),
                      size: 18,
                      color: accent,
                    ),
                    const SizedBox(width: 5),
                    Icon(_categoryIcon(cat), size: 16, color: accent),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.label(widget.isArabic),
                            style: const TextStyle(
                                fontSize: 12.2, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            cat.description(widget.isArabic),
                            style:
                                TextStyle(fontSize: 10, color: theme.hintColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (containsActive) _buildActiveDotBadge(accent),
                    const SizedBox(width: 5),
                    _buildCountPill('${items.length}', accent),
                  ],
                ),
              ),
            ),
            if (expanded) ...[
              Divider(
                  height: 1, color: theme.dividerColor.withValues(alpha: 0.16)),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
                child: Column(
                  children: [
                    for (final preset in items)
                      _buildPresetLeafRow(theme, preset),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPresetLeafRow(ThemeData theme, StudioPreset p) {
    final selected = !widget.workspaceMode && p.id == widget.activePresetId;
    final accent = _categoryColor(p.category);
    final lineCount = '\n'.allMatches(p.code).length + 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        key: Key('gallery_item_${p.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).pop(
          QudsGallerySelection.preset(
            preset: p,
            filter: filterForCategory(p.category),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF2563EB).withValues(alpha: 0.18)
                : (widget.isDark
                    ? const Color(0xFF0F172A).withValues(alpha: 0.7)
                    : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? const Color(0xFF38BDF8)
                  : theme.dividerColor.withValues(alpha: 0.16),
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : (p.isAnimated
                        ? Icons.bolt_rounded
                        : _categoryIcon(p.category)),
                size: 15,
                color: selected
                    ? const Color(0xFF38BDF8)
                    : (p.isAnimated ? const Color(0xFFF59E0B) : accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isArabic ? p.titleAr : p.titleEn,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? const Color(0xFF38BDF8) : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      p.subtitleAr,
                      style: TextStyle(fontSize: 10.2, color: theme.hintColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (selected)
                _buildSelectedLeafBadge(const Color(0xFF38BDF8))
              else
                Text(
                  widget.isArabic ? '$lineCount سطر' : '$lineCount L',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 9.8,
                    color: theme.hintColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(
    ThemeData theme,
    List<StudioProjectTemplate> workspaces,
    List<StudioPreset> presets,
  ) {
    if (workspaces.isEmpty && presets.isEmpty) {
      return Center(
        child: Text(
          widget.isArabic
              ? 'لا توجد نتائج مطابقة للبحث «$_query»'
              : 'No matching examples or workspaces for "$_query".',
          style: TextStyle(fontSize: 12.5, color: theme.hintColor),
        ),
      );
    }
    return ListView(
      key: const Key('gallery_examples_list'),
      padding: const EdgeInsets.all(10),
      children: [
        if (workspaces.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              widget.isArabic
                  ? '📦 مشاريع كاملة (${workspaces.length})'
                  : '📦 Workspaces (${workspaces.length})',
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF10B981)),
            ),
          ),
          for (final tpl in workspaces) _buildWorkspaceLeafRow(theme, tpl),
          const SizedBox(height: 8),
        ],
        if (presets.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              widget.isArabic
                  ? '✨ الأمثلة المطابقة (${presets.length})'
                  : '✨ Matching Examples (${presets.length})',
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF38BDF8)),
            ),
          ),
          for (final p in presets) _buildPresetLeafRow(theme, p),
        ],
      ],
    );
  }

  Widget _buildActiveDotBadge(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            widget.isArabic ? 'مفتوح' : 'open',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedLeafBadge(Color color) {
    return Container(
      key: const Key('tree_active_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        widget.isArabic ? 'مفتوح الآن' : 'Active',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCountPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

Color _domainAccent(StudioDomain d) => switch (d) {
      StudioDomain.gamesAndSims => const Color(0xFF0EA5E9),
      StudioDomain.sciences => const Color(0xFF10B981),
      StudioDomain.mathAndCs => const Color(0xFF8B5CF6),
      StudioDomain.languageAndVm => const Color(0xFFF59E0B),
    };

Color _categoryColor(StudioCategory c) => switch (c) {
      StudioCategory.pen => const Color(0xFF06B6D4),
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
      StudioCategory.pen => Icons.draw_rounded,
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
