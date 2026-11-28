/// Interactive Multi-File, Nested-Folder & Assets Project Manager for Quds Studio.
///
/// Backed by pure-Dart [QudsWorkspace]:
/// - 1-tap switching across 5 complete multi-folder Quds projects with `assets/`
/// - Creating nested `.quds` files, folders, and text/binary assets (JSON, CSV, Text, BMP/Base64)
/// - Live `.qproj` v2 JSON bundle Export/Import (preserving binary assets via Base64)
/// - Live dependency & cycle analysis badges + binary image asset preview dialog
/// - Opening `.quds` or text assets directly in the main editor and running the full project
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quds/interpreter.dart';

import 'project_templates.dart';

class QudsWorkspacePanel extends StatefulWidget {
  const QudsWorkspacePanel({
    super.key,
    required this.workspace,
    required this.activeProjectId,
    required this.activeFile,
    required this.workspaceMode,
    required this.isArabic,
    required this.isDark,
    required this.running,
    required this.onOpenFile,
    required this.onRunProject,
    required this.onCreateFile,
    required this.onCreateAsset,
    required this.onCreateFolder,
    required this.onDeleteFile,
    required this.onSelectTemplate,
    required this.onImportQproj,
    required this.onResetTemplate,
  });

  final QudsWorkspace workspace;
  final String activeProjectId;
  final String activeFile;
  final bool workspaceMode;
  final bool isArabic;
  final bool isDark;
  final bool running;
  final ValueChanged<String> onOpenFile;
  final VoidCallback onRunProject;
  final void Function(String path, String initialContent) onCreateFile;
  final void Function(String path,
      {String? textContent, Uint8List? binaryBytes}) onCreateAsset;
  final ValueChanged<String> onCreateFolder;
  final ValueChanged<String> onDeleteFile;
  final ValueChanged<StudioProjectTemplate> onSelectTemplate;
  final ValueChanged<QudsWorkspace> onImportQproj;
  final VoidCallback onResetTemplate;

  @override
  State<QudsWorkspacePanel> createState() => _QudsWorkspacePanelState();
}

enum _AssetKind { json, csv, text, imageBmp }

class _QudsWorkspacePanelState extends State<QudsWorkspacePanel> {
  final Set<String> _collapsedDirs = {};

  Future<void> _showNewFileDialog() async {
    final controller = TextEditingController(text: 'math/helper.quds');
    final path = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(
            widget.isArabic ? 'إنشاء ملف Quds جديد' : 'New Quds File',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isArabic
                    ? 'اكتب المسار النسبي (يمكنك إنشاء مجلدات متفرعة مثل services/tax.quds):'
                    : 'Enter workspace path (nested folders are created automatically):',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  key: const Key('new_file_path_field'),
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'services/tax.quds',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(widget.isArabic ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              key: const Key('confirm_new_file_button'),
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: Text(widget.isArabic ? 'إنشاء' : 'Create'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (path == null || path.isEmpty) return;
    final fixedPath = path.endsWith('.quds') ? path : '$path.quds';
    widget.onCreateFile(
      fixedPath,
      '# $fixedPath\n\nhelper(x: double) -> double:\n  return x * 2.0\n',
    );
  }

  Future<void> _showNewAssetDialog() async {
    final result = await showDialog<(_AssetKind, String, String)>(
      context: context,
      builder: (_) => _NewAssetDialog(isArabic: widget.isArabic),
    );
    if (result == null) return;
    final (kind, rawPath, rawContent) = result;
    if (rawPath.isEmpty) return;
    if (kind == _AssetKind.imageBmp) {
      final cleaned = rawContent.replaceAll(RegExp(r'\s+'), '');
      final bytes = cleaned.isNotEmpty
          ? Uint8List.fromList(base64Decode(cleaned))
          : _generateDefaultAssetBmp();
      widget.onCreateAsset(rawPath, binaryBytes: bytes);
    } else {
      widget.onCreateAsset(rawPath, textContent: rawContent);
    }
  }

  Uint8List _generateDefaultAssetBmp() {
    const size = 16;
    final rows = List.generate(size, (y) {
      return List.generate(size, (x) {
        final border = x == 0 || y == 0 || x == size - 1 || y == size - 1;
        if (border) return [245, 158, 11];
        final r = (30 + x * 14).clamp(0, 255);
        final g = (110 + (size - y) * 8).clamp(0, 255);
        final b = (190 + (x + y) * 2).clamp(0, 255);
        return [r, g, b];
      });
    });
    return encodeQudsBmp24(rows, scale: 8);
  }

  Future<void> _showNewFolderDialog() async {
    final controller = TextEditingController(text: 'extensions');
    final folder = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(
            widget.isArabic ? 'إنشاء مجلد جديد' : 'New Folder',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          content: Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              key: const Key('new_folder_path_field'),
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'assets/themes',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 13,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(widget.isArabic ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: Text(widget.isArabic ? 'إنشاء' : 'Create'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (folder == null || folder.isEmpty) return;
    widget.onCreateFolder(folder);
  }

  Future<void> _showQprojBundleDialog() async {
    final controller =
        TextEditingController(text: widget.workspace.toJsonString());
    String? errorMsg;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection:
              widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.inventory_2_rounded,
                    size: 18, color: Color(0xFF38BDF8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isArabic
                        ? 'تصدير / استيراد حزمة المشروع (.qproj)'
                        : 'Export / Import Project Bundle (.qproj)',
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.isArabic
                        ? 'يحتوي ملف .qproj على جميع المجلدات وملفات قدس والأصول النصية والثنائية (Base64). يمكنك نسخه لمشاركة المشروع أو لصق مشروع جديد لاستيراده:'
                        : 'A .qproj bundle captures all folders, .quds files, text assets, and Base64 binary assets. Copy to export or paste to import:',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  const SizedBox(height: 8),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: TextField(
                      key: const Key('qproj_json_field'),
                      controller: controller,
                      maxLines: 10,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 11,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      errorMsg!,
                      style: const TextStyle(
                          color: Color(0xFFEF4444), fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: controller.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(widget.isArabic
                          ? 'تم نسخ حزمة .qproj إلى الحافظة'
                          : 'Copied .qproj bundle to clipboard'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: Text(widget.isArabic ? 'نسخ' : 'Copy'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(widget.isArabic ? 'إغلاق' : 'Close'),
              ),
              FilledButton.icon(
                key: const Key('btn_import_qproj_confirm'),
                onPressed: () {
                  try {
                    final parsed =
                        QudsWorkspace.fromJsonString(controller.text);
                    widget.onImportQproj(parsed);
                    Navigator.of(ctx).pop();
                  } catch (e) {
                    setDialogState(() => errorMsg = '$e');
                  }
                },
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: Text(widget.isArabic ? 'استيراد وتشغيل' : 'Import'),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _showBinaryAssetPreview(String path) async {
    final bytes = widget.workspace.readAssetBytes(path);
    if (bytes == null) return;
    final mime = QudsWorkspace.mimeTypeForPath(path);
    final isImage = mime.startsWith('image/') && !mime.contains('svg');
    final snippet = 'assets.renderImage("$path")';

    await showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.image_rounded,
                  size: 18, color: Color(0xFFEC4899)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  path,
                  style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isImage)
                  Container(
                    height: 180,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF060B16)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    'MIME: $mime · ${_formatSize(bytes.length)}',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SelectableText(
                      snippet,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 11.5,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: snippet));
                Navigator.of(ctx).pop();
              },
              icon: const Icon(Icons.copy_rounded, size: 15),
              label: Text(widget.isArabic ? 'نسخ كود العرض' : 'Copy snippet'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(widget.isArabic ? 'إغلاق' : 'Close'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tree = widget.workspace.buildTree();
    final report = widget.workspace.analyzeDependencies();
    final qudsCount = widget.workspace.listFiles(extension: '.quds').length;
    final assetCount = widget.workspace.assetCount;
    final folderCount = widget.workspace.listFolders().length;
    final hasIssues = report.hasCycles || report.hasUnresolvedImports;

    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Multi-Project Switcher Strip (5 multi-folder projects with assets/)
          SizedBox(
            height: 30,
            child: SingleChildScrollView(
              key: const Key('workspace_project_switcher'),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < studioProjectTemplates.length; i++) ...[
                    if (i > 0) const SizedBox(width: 5),
                    Builder(builder: (ctx) {
                      final tpl = studioProjectTemplates[i];
                      final active = widget.activeProjectId == tpl.id;
                      return ChoiceChip(
                        key: Key('project_template_${tpl.id}'),
                        selected: active,
                        showCheckmark: false,
                        avatar: Icon(
                          tpl.icon,
                          size: 13,
                          color: active ? Colors.white : tpl.accentColor,
                        ),
                        label: Text(
                          widget.isArabic ? tpl.nameAr : tpl.nameEn,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        selectedColor: tpl.accentColor.withValues(alpha: 0.85),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onSelected: (_) => widget.onSelectTemplate(tpl),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),

          // 2. Project header, pinned Run Project CTA, and scrollable actions
          Row(
            children: [
              FilledButton.icon(
                key: const Key('workspace_run_project_btn'),
                onPressed: widget.running ? null : widget.onRunProject,
                icon: const Icon(Icons.play_arrow_rounded, size: 14),
                label: Text(
                  widget.isArabic ? 'تشغيل المشروع' : 'Run Project',
                  style: const TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Icon(Icons.account_tree_rounded,
                          size: 14, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 4),
                      Text(
                        widget.workspace.name,
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: (hasIssues
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981))
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          widget.isArabic
                              ? '$qudsCount قدس · $assetCount أصول · $folderCount مجلد${report.hasCycles ? ' · دورة!' : ''}${report.hasUnresolvedImports ? ' · مفقود!' : ''}'
                              : '$qudsCount .quds · $assetCount assets · $folderCount dirs${report.hasCycles ? ' · cycle!' : ''}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: hasIssues
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        key: const Key('workspace_new_file_btn'),
                        onPressed: _showNewFileDialog,
                        icon: const Icon(Icons.note_add_outlined, size: 13),
                        label: Text(
                          widget.isArabic ? 'ملف' : 'File',
                          style: const TextStyle(fontSize: 10.5),
                        ),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      OutlinedButton.icon(
                        key: const Key('workspace_new_asset_btn'),
                        onPressed: _showNewAssetDialog,
                        icon: const Icon(Icons.perm_media_outlined,
                            size: 13, color: Color(0xFFEC4899)),
                        label: Text(
                          widget.isArabic ? 'أصل' : 'Asset',
                          style: const TextStyle(fontSize: 10.5),
                        ),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      OutlinedButton.icon(
                        key: const Key('workspace_new_folder_btn'),
                        onPressed: _showNewFolderDialog,
                        icon: const Icon(Icons.create_new_folder_outlined,
                            size: 13),
                        label: Text(
                          widget.isArabic ? 'مجلد' : 'Folder',
                          style: const TextStyle(fontSize: 10.5),
                        ),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                        ),
                      ),
                      const SizedBox(width: 2),
                      IconButton(
                        key: const Key('workspace_qproj_btn'),
                        tooltip: widget.isArabic
                            ? 'تصدير / استيراد .qproj'
                            : 'Export / Import .qproj',
                        onPressed: _showQprojBundleDialog,
                        visualDensity: VisualDensity.compact,
                        constraints:
                            const BoxConstraints(minWidth: 26, minHeight: 26),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.inventory_2_outlined, size: 15),
                      ),
                      IconButton(
                        tooltip: widget.isArabic
                            ? 'إعادة ضبط المشروع الحالي'
                            : 'Reset Current Project',
                        onPressed: widget.onResetTemplate,
                        visualDensity: VisualDensity.compact,
                        constraints:
                            const BoxConstraints(minWidth: 26, minHeight: 26),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.restart_alt_rounded, size: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (report.hasCycles) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${widget.isArabic ? 'تحذير دورة استيراد' : 'Circular import'}: ${report.cycles.first.join(' -> ')}',
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
          ],
          const SizedBox(height: 5),

          // 3. Hierarchical File & Asset Tree
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: widget.isDark
                    ? const Color(0xFF0B1120)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.2),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final child in tree.children)
                      ..._buildTreeRows(child, 0, theme),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _iconForFile(
      QudsWorkspaceNode node, bool isEntry, bool isSelected, ThemeData theme) {
    if (isEntry) {
      return (Icons.play_circle_outline_rounded, const Color(0xFF10B981));
    }
    final lower = node.name.toLowerCase();
    if (node.isBinary ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg')) {
      return (Icons.image_rounded, const Color(0xFFEC4899));
    }
    if (lower.endsWith('.json')) {
      return (Icons.data_object_rounded, const Color(0xFFF59E0B));
    }
    if (lower.endsWith('.csv')) {
      return (Icons.table_chart_outlined, const Color(0xFF10B981));
    }
    if (lower.endsWith('.quds')) {
      return (
        Icons.code_rounded,
        isSelected ? const Color(0xFF38BDF8) : const Color(0xFF60A5FA),
      );
    }
    return (
      Icons.article_outlined,
      isSelected ? const Color(0xFF38BDF8) : theme.hintColor,
    );
  }

  List<Widget> _buildTreeRows(
    QudsWorkspaceNode node,
    int depth,
    ThemeData theme,
  ) {
    final indent = 8.0 + depth * 14.0;
    if (node.isDirectory) {
      final collapsed = _collapsedDirs.contains(node.path);
      final isAssetsDir = node.name == 'assets';
      return [
        InkWell(
          onTap: () => setState(() {
            if (collapsed) {
              _collapsedDirs.remove(node.path);
            } else {
              _collapsedDirs.add(node.path);
            }
          }),
          child: Padding(
            padding: EdgeInsetsDirectional.only(
                start: indent, end: 8, top: 3, bottom: 3),
            child: Row(
              children: [
                Icon(
                  collapsed
                      ? Icons.chevron_right_rounded
                      : Icons.expand_more_rounded,
                  size: 15,
                  color: theme.hintColor,
                ),
                const SizedBox(width: 4),
                Icon(
                  isAssetsDir ? Icons.perm_media_rounded : Icons.folder_rounded,
                  size: 14,
                  color: isAssetsDir
                      ? const Color(0xFFEC4899)
                      : const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    node.name,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!collapsed)
          for (final child in node.children)
            ..._buildTreeRows(child, depth + 1, theme),
      ];
    }

    final isSelected = widget.workspaceMode && node.path == widget.activeFile;
    final isEntry = node.path == widget.workspace.entryPoint;
    final isAsset = !node.name.endsWith('.quds');
    final (iconData, iconColor) =
        _iconForFile(node, isEntry, isSelected, theme);

    return [
      InkWell(
        key: Key('ws_file_${node.path}'),
        onTap: () {
          if (node.isBinary) {
            _showBinaryAssetPreview(node.path);
          } else {
            widget.onOpenFile(node.path);
          }
        },
        child: Container(
          color: isSelected
              ? const Color(0xFF2563EB).withValues(alpha: 0.16)
              : null,
          padding: EdgeInsetsDirectional.only(
              start: indent + 14, end: 6, top: 3, bottom: 3),
          child: Row(
            children: [
              Icon(iconData, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  node.name,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12.5,
                    fontWeight: isSelected || isEntry
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: isSelected ? const Color(0xFF38BDF8) : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isAsset && node.byteSize > 0)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: Text(
                    _formatSize(node.byteSize),
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 9.5,
                      color: theme.hintColor,
                    ),
                  ),
                ),
              if (isEntry)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.isArabic ? 'نقطة الدخول' : 'entry',
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (!isEntry)
                IconButton(
                  tooltip: widget.isArabic ? 'حذف الملف' : 'Delete file',
                  onPressed: () => widget.onDeleteFile(node.path),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 24, minHeight: 24),
                  icon: Icon(Icons.close_rounded,
                      size: 14, color: theme.hintColor),
                ),
            ],
          ),
        ),
      ),
    ];
  }
}

class _NewAssetDialog extends StatefulWidget {
  const _NewAssetDialog({required this.isArabic});

  final bool isArabic;

  @override
  State<_NewAssetDialog> createState() => _NewAssetDialogState();
}

class _NewAssetDialogState extends State<_NewAssetDialog> {
  _AssetKind _kind = _AssetKind.json;
  late final TextEditingController _pathController;
  late final TextEditingController _contentController;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _pathController = TextEditingController(text: 'assets/data.json');
    _contentController = TextEditingController(
      text: '{\n  "title": "Quds Asset",\n  "items": [10, 20, 30]\n}\n',
    );
  }

  @override
  void dispose() {
    _pathController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _switchKind(_AssetKind next) {
    setState(() {
      _kind = next;
      _errorMsg = null;
      switch (next) {
        case _AssetKind.json:
          _pathController.text = 'assets/data.json';
          _contentController.text =
              '{\n  "title": "Quds Asset",\n  "items": [10, 20, 30]\n}\n';
        case _AssetKind.csv:
          _pathController.text = 'assets/records.csv';
          _contentController.text =
              'name,qty,price\nItem A,2,15.5\nItem B,4,9.0\n';
        case _AssetKind.text:
          _pathController.text = 'assets/notes.txt';
          _contentController.text =
              'مرحباً بك في نظام أصول قدس (quds:assets)!\n';
        case _AssetKind.imageBmp:
          _pathController.text = 'assets/badge.bmp';
          _contentController.text = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.perm_media_rounded,
                size: 18, color: Color(0xFFEC4899)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.isArabic
                    ? 'إضافة / تحميل أصل (Asset)'
                    : 'Add / Load Project Asset',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in [
                      (_AssetKind.json, 'JSON'),
                      (_AssetKind.csv, 'CSV'),
                      (_AssetKind.text, widget.isArabic ? 'نص / MD' : 'Text'),
                      (
                        _AssetKind.imageBmp,
                        widget.isArabic ? 'صورة BMP / Base64' : 'Image BMP/B64'
                      ),
                    ])
                      ChoiceChip(
                        key: Key('asset_kind_${entry.$1.name}'),
                        label: Text(entry.$2,
                            style: const TextStyle(fontSize: 11.5)),
                        selected: _kind == entry.$1,
                        onSelected: (_) => _switchKind(entry.$1),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    key: const Key('new_asset_path_field'),
                    controller: _pathController,
                    decoration: InputDecoration(
                      labelText: widget.isArabic
                          ? 'مسار الأصل داخل المشروع'
                          : 'Asset path',
                      hintText: 'assets/catalog.json',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (_kind == _AssetKind.imageBmp)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      widget.isArabic
                          ? 'الصق نص Base64 لصورة PNG/BMP، أو اتركه فارغاً لتوليد صورة BMP لونية جاهزة للاستخدام مع assets.renderImage(...):'
                          : 'Paste Base64 PNG/BMP bytes, or leave empty to generate a ready-to-render 24-bit BMP image:',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    key: const Key('new_asset_content_field'),
                    controller: _contentController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: _kind == _AssetKind.imageBmp
                          ? 'Base64 (optional)'
                          : (widget.isArabic ? 'محتوى الأصل' : 'Content'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                    ),
                  ),
                ),
                if (_errorMsg != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _errorMsg!,
                    style: const TextStyle(
                        color: Color(0xFFEF4444), fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_new_asset_button'),
            onPressed: () {
              final rawPath = _pathController.text.trim();
              if (rawPath.isEmpty) {
                setState(() => _errorMsg = widget.isArabic
                    ? 'الرجاء إدخال مسار صالح'
                    : 'Please enter a valid path');
                return;
              }
              if (_kind == _AssetKind.imageBmp &&
                  _contentController.text.trim().isNotEmpty) {
                try {
                  base64Decode(
                      _contentController.text.replaceAll(RegExp(r'\s+'), ''));
                } catch (_) {
                  setState(() => _errorMsg = widget.isArabic
                      ? 'نص Base64 غير صالح'
                      : 'Invalid Base64 string');
                  return;
                }
              }
              Navigator.of(context)
                  .pop((_kind, rawPath, _contentController.text));
            },
            child: Text(widget.isArabic ? 'إضافة الأصل' : 'Add Asset'),
          ),
        ],
      ),
    );
  }
}
