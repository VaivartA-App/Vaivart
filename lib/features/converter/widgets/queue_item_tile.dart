import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/conversion_job.dart';

class QueueItemTile extends StatelessWidget {
  final ConversionJob job;
  final VoidCallback onRemove;
  final ValueChanged<String> onFormatChanged;
  final ValueChanged<String>? onResolutionChanged;

  const QueueItemTile({
    super.key,
    required this.job,
    required this.onRemove,
    required this.onFormatChanged,
    this.onResolutionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBgSecondary : AppColors.lightBg;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkText : AppColors.lightText;
    final textTertiary = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _FilePill(ext: job.extension),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              job.fileName,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(color: textPrimary, fontWeight: FontWeight.w500),
            ),
          ),
          if (job.isVideo && onResolutionChanged != null) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 90),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: border, width: 0.5),
                  borderRadius: BorderRadius.circular(6),
                  color: isDark ? AppColors.darkBgTertiary : AppColors.lightBgSecondary,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: job.resolution ?? 'Original',
                    isDense: true,
                    isExpanded: true,
                    style: AppTypography.caption.copyWith(color: textPrimary, fontSize: 11),
                    items: ConversionJob.videoResolutions
                        .map((res) => DropdownMenuItem(
                              value: res,
                              child: Text(res == 'Original' ? 'Res: Auto' : res),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onResolutionChanged!(v);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (job.availableFormats.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 90),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: border, width: 0.5),
                  borderRadius: BorderRadius.circular(6),
                  color: isDark ? AppColors.darkBgTertiary : AppColors.lightBgSecondary,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: job.targetFormat ?? job.availableFormats.first,
                    isDense: true,
                    isExpanded: true,
                    style: AppTypography.caption.copyWith(color: textPrimary),
                    items: job.availableFormats
                        .map((f) => DropdownMenuItem(value: f, child: Text('→ $f')))
                        .toList(),
                    onChanged: (v) { if (v != null) onFormatChanged(v); },
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          _StatusDot(status: job.status),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: textTertiary),
          ),
        ],
      ),
    );
  }
}

class _FilePill extends StatelessWidget {
  final String ext;
  const _FilePill({required this.ext});

  @override
  Widget build(BuildContext context) {
    final colors = _pillColors(ext);
    return Container(
      width: 36, height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors[0],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        ext.length > 4 ? ext.substring(0, 4) : ext,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: colors[1]),
      ),
    );
  }

  List<Color> _pillColors(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg': case 'jpeg': case 'png': case 'webp': case 'bmp':
        return [AppColors.imgBg, AppColors.imgFg];
      case 'pdf':
        return [AppColors.pdfBg, AppColors.pdfFg];
      case 'docx': case 'doc':
        return [AppColors.docBg, AppColors.docFg];
      case 'csv': case 'xlsx':
        return [AppColors.csvBg, AppColors.csvFg];
      case 'mp4': case 'avi': case 'mkv': case 'webm': case 'mov':
        return [AppColors.vidBg, AppColors.vidFg];
      default:
        return [AppColors.lightBgTertiary, AppColors.lightTextSecondary];
    }
  }
}

class _StatusDot extends StatelessWidget {
  final JobStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      JobStatus.waiting => AppColors.darkBorder,
      JobStatus.converting => const Color(0xFFEF9F27),
      JobStatus.done => AppColors.teal,
      JobStatus.failed => const Color(0xFFE24B4A),
    };
    return Container(
      width: 7, height: 7,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}