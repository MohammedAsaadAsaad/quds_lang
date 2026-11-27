/// Interactive Multi-File & Nested-Folder Project Workspace Explorer for Quds Studio.
///
/// Backed by pure-Dart [QudsWorkspace]: supports hierarchical folders, creating
/// nested files/folders, live dependency & cycle analysis badges, opening any
/// file in the main code editor, and running the full multi-file project.
library;

import 'package:flutter/material.dart';
import 'package:quds/interpreter.dart';

class QudsWorkspacePanel extends StatefulWidget {
  const QudsWorkspacePanel({
    super.key,
    required this.workspace,
    required this.activeFile,
    required this.workspaceMode,
    required this.isArabic,
    required this.isDark,
    required this.running,
    required this.onOpenFile,
    required this.onRunProject,
    required this.onCreateFile,
    required this.onCreateFolder,
    required this.onDeleteFile,
    required this.onResetTemplate,
  });

  final QudsWorkspace workspace;
  final String activeFile;
  final bool workspaceMode;
  final bool isArabic;
  final bool isDark;
  final bool running;
  final ValueChanged<String> onOpenFile;
  final VoidCallback onRunProject;
  final void Function(String path, String initialContent) onCreateFile;
  final ValueChanged<String> onCreateFolder;
  final ValueChanged<String> onDeleteFile;
  final VoidCallback onResetTemplate;

  @override
  State<QudsWorkspacePanel> createState() => _QudsWorkspacePanelState();
}

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
                    ? 'اكتب المسار النسبي (يمكنك إنشاء مجلدات متفرعة مثل math/ode/rk4.quds):'
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
                    hintText: 'math/ode/rk4.quds',
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

  Future<void> _showNewFolderDialog() async {
    final controller = TextEditingController(text: 'solvers');
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
                hintText: 'math/linalg',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tree = widget.workspace.buildTree();
    final report = widget.workspace.analyzeDependencies();
    final fileCount = widget.workspace.listFiles().length;
    final folderCount = widget.workspace.listFolders().length;
    final hasIssues = report.hasCycles || report.hasUnresolvedImports;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar with project info & actions
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_tree_rounded,
                      size: 16, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 6),
                  Text(
                    widget.workspace.name,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: (hasIssues
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981))
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      widget.isArabic
                          ? '$fileCount ملف · $folderCount مجلد${report.hasCycles ? ' · دورة استيراد!' : ''}${report.hasUnresolvedImports ? ' · استيراد مفقود!' : ''}'
                          : '$fileCount files · $folderCount folders${report.hasCycles ? ' · cycle!' : ''}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: hasIssues
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    key: const Key('workspace_new_file_btn'),
                    onPressed: _showNewFileDialog,
                    icon: const Icon(Icons.note_add_outlined, size: 14),
                    label: Text(
                      widget.isArabic ? 'ملف' : 'File',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('workspace_new_folder_btn'),
                    onPressed: _showNewFolderDialog,
                    icon:
                        const Icon(Icons.create_new_folder_outlined, size: 14),
                    label: Text(
                      widget.isArabic ? 'مجلد' : 'Folder',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
                  IconButton(
                    tooltip: widget.isArabic
                        ? 'إعادة ضبط القالب العلمي'
                        : 'Reset Scientific Project Template',
                    onPressed: widget.onResetTemplate,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.restart_alt_rounded, size: 17),
                  ),
                  FilledButton.icon(
                    key: const Key('workspace_run_project_btn'),
                    onPressed: widget.running ? null : widget.onRunProject,
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: Text(
                      widget.isArabic ? 'تشغيل المشروع' : 'Run Project',
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (report.hasCycles) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
          const SizedBox(height: 8),
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
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final child in tree.children)
                    ..._buildTreeRows(child, 0, theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTreeRows(
    QudsWorkspaceNode node,
    int depth,
    ThemeData theme,
  ) {
    final indent = 10.0 + depth * 16.0;
    if (node.isDirectory) {
      final collapsed = _collapsedDirs.contains(node.path);
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
                start: indent, end: 8, top: 5, bottom: 5),
            child: Row(
              children: [
                Icon(
                  collapsed
                      ? Icons.chevron_right_rounded
                      : Icons.expand_more_rounded,
                  size: 16,
                  color: theme.hintColor,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.folder_rounded,
                    size: 15, color: Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    node.name,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12.5,
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
    return [
      InkWell(
        key: Key('ws_file_${node.path}'),
        onTap: () => widget.onOpenFile(node.path),
        child: Container(
          color: isSelected
              ? const Color(0xFF2563EB).withValues(alpha: 0.16)
              : null,
          padding: EdgeInsetsDirectional.only(
              start: indent + 16, end: 6, top: 5, bottom: 5),
          child: Row(
            children: [
              Icon(
                isEntry
                    ? Icons.play_circle_outline_rounded
                    : Icons.description_outlined,
                size: 15,
                color: isEntry
                    ? const Color(0xFF10B981)
                    : (isSelected ? const Color(0xFF38BDF8) : theme.hintColor),
              ),
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
