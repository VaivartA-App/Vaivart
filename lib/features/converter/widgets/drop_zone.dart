import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

class DropZone extends StatefulWidget {
  final Function(List<String>) onFilesDropped;
  final VoidCallback onBrowse;

  const DropZone({
    super.key,
    required this.onFilesDropped,
    required this.onBrowse,
  });

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Highlight if hovering with mouse, OR if actively dragging a file over the window
    final border = _dragging || _hovering
        ? AppColors.teal
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    // Slight tint if dragging files over
    final bg = _dragging
        ? AppColors.teal.withValues(alpha: 0.1)
        : (isDark ? AppColors.darkBgSecondary : AppColors.lightBgSecondary);

    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textTertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    final isMobile = MediaQuery.of(context).size.width < 600;

    return DropTarget(
      onDragDone: (detail) {
        setState(() => _dragging = false);
        final paths = detail.files.map((f) => f.path).toList();
        if (paths.isNotEmpty) {
          widget.onFilesDropped(paths);
        }
      },
      onDragEntered: (detail) {
        setState(() => _dragging = true);
      },
      onDragExited: (detail) {
        setState(() => _dragging = false);
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onBrowse,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(
                  color: border, width: 2), // thicker border for visibility
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.upload_outlined,
                      size: 18,
                      color: _dragging ? AppColors.teal : textTertiary),
                ),
                const SizedBox(height: 10),
                Text(
                  _dragging
                      ? 'Drop files to add'
                      : (isMobile ? 'Tap to select files' : 'Drop files here'),
                  style: AppTypography.body.copyWith(
                    color: _dragging ? AppColors.teal : textSecondary,
                    fontWeight: _dragging ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(height: 4),
                  Text('or',
                      style:
                          AppTypography.caption.copyWith(color: textTertiary)),
                ],
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: border, width: 0.5),
                    borderRadius: BorderRadius.circular(6),
                    color: isDark ? AppColors.darkBg : AppColors.lightBg,
                  ),
                  child: Text('Browse files',
                      style:
                          AppTypography.caption.copyWith(color: textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
