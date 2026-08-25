import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

class DropZone extends StatefulWidget {
  final VoidCallback onFilesDropped;
  const DropZone({super.key, required this.onFilesDropped});

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = _hovering
        ? AppColors.teal
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);
    final bg = isDark ? AppColors.darkBgSecondary : AppColors.lightBgSecondary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textTertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    // On mobile (touch), no hover state, no drag hint text
    final isMobile = MediaQuery.of(context).size.width < 600;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onFilesDropped,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: 1),
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
                child:
                    Icon(Icons.upload_outlined, size: 18, color: textTertiary),
              ),
              const SizedBox(height: 10),
              // Desktop: "Drop files here", Mobile: "Tap to select files"
              Text(
                isMobile ? 'Tap to select files' : 'Drop files here',
                style: AppTypography.body.copyWith(color: textSecondary),
              ),
              if (!isMobile) ...[
                const SizedBox(height: 4),
                Text('or',
                    style: AppTypography.caption.copyWith(color: textTertiary)),
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
    );
  }
}
