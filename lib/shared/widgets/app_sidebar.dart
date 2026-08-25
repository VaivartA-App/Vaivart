import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

enum SidebarItem {
  converter,
  batch,
  pdfMerge,
  pdfSplit,
  history,
  settings,
  compression
}

class AppSidebar extends StatelessWidget {
  final SidebarItem selected;
  final ValueChanged<SidebarItem> onSelect;

  const AppSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBgSecondary : AppColors.lightBgSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _section(context, 'CONVERT'),
          _item(context, SidebarItem.converter, 'Single file'),
          _item(context, SidebarItem.batch, 'Batch queue'),
          _section(context, 'TOOLS'),
          _item(context, SidebarItem.pdfMerge, 'PDF merge'),
          _item(context, SidebarItem.pdfSplit, 'PDF split'),
          _section(context, 'OTHER'),
          _item(context, SidebarItem.history, 'History'),
          _item(context, SidebarItem.settings, 'Settings'),
          _item(context, SidebarItem.compression, 'Compression'),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(label,
          style: AppTypography.sectionHeader
              .copyWith(color: AppColors.darkTextTertiary)),
    );
  }

  Widget _item(BuildContext context, SidebarItem item, String label) {
    final isActive = selected == item;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg =
        isDark ? AppColors.darkBgTertiary : AppColors.lightBgTertiary;
    final activeText = isDark ? AppColors.darkText : AppColors.lightText;
    final inactiveText =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GestureDetector(
      onTap: () => onSelect(item),
      child: Container(
        color: isActive ? activeBg : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? AppColors.teal
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppTypography.body.copyWith(
                color: isActive ? activeText : inactiveText,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
