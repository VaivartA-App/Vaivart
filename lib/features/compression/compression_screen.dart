import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

class CompressionScreen extends StatefulWidget {
  const CompressionScreen({super.key});

  @override
  State<CompressionScreen> createState() => _CompressionScreenState();
}

class _CompressionScreenState extends State<CompressionScreen> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _checkAndRedirect();
  }

  Future<void> _checkAndRedirect() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _checked = true);

    final hasWinrar = await _winrarExists();
    if (!mounted) return;

    if (hasWinrar) {
      _launch('winrar');
    }
  }

  Future<bool> _winrarExists() async {
    try {
      final result = await Process.run('which', ['winrar']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  void _launch(String command) async {
    if (command == 'winrar') {
      await Process.run('winrar', []);
    } else {
      await Process.run('xdg-open', ['https://www.win-rar.com']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkText : AppColors.lightText;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textTertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final bg = isDark ? AppColors.darkBgSecondary : AppColors.lightBgSecondary;

    return Center(
      child: SizedBox(
        width: 420,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_checked) ...[
              const CircularProgressIndicator(
                  color: AppColors.teal, strokeWidth: 1.5),
              const SizedBox(height: 20),
              Text('Checking for compression tools...',
                  style: AppTypography.body.copyWith(color: textTertiary)),
            ] else ...[
              // WinRAR tribute
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: border, width: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text('🏆', style: const TextStyle(fontSize: 48)),
                    const SizedBox(height: 16),
                    Text(
                      'We don\'t do compression.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'WinRAR has been doing this for 30 years.\nOut of pure respect, we won\'t compete.',
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(color: textSecondary),
                    ),
                    const SizedBox(height: 24),
                    Divider(color: border, thickness: 0.5),
                    const SizedBox(height: 16),
                    Text(
                      'Please purchase WinRAR after your 40-day trial.',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        color: textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => _launch('web'),
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          'Get WinRAR →',
                          style: AppTypography.label
                              .copyWith(color: AppColors.tealLight),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No enemies. Just respect.',
                style: AppTypography.caption.copyWith(color: textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
