import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import 'merge/pdf_merge_screen.dart';
import 'split/pdf_split_screen.dart';

class PdfToolsScreen extends StatefulWidget {
  const PdfToolsScreen({super.key});

  @override
  State<PdfToolsScreen> createState() => _PdfToolsScreenState();
}

class _PdfToolsScreenState extends State<PdfToolsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: border, width: 0.5)),
          ),
          child: Row(
            children: [
              _TabBtn(
                  label: 'Merge',
                  active: _tab == 0,
                  onTap: () => setState(() => _tab = 0)),
              const SizedBox(width: 24),
              _TabBtn(
                  label: 'Split',
                  active: _tab == 1,
                  onTap: () => setState(() => _tab = 1)),
            ],
          ),
        ),
        Expanded(
          child: _tab == 0 ? const PdfMergeScreen() : const PdfSplitScreen(),
        ),
      ],
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.teal : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.label.copyWith(
            color: active ? AppColors.teal : AppColors.darkTextTertiary,
          ),
        ),
      ),
    );
  }
}
