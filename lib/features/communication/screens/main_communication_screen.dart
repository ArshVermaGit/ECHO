import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

class MainCommunicationScreen extends StatelessWidget {
  const MainCommunicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ECHO Communication'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              color: AppColors.surface,
              child: const Center(
                child: Text('Gaze Engine View Container'),
              ),
            ),
          ),
          Container(
            height: 100,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(
                top: BorderSide(color: AppColors.border),
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Center(
              child: Text(
                'Start looking at letters to type...',
                style: AppTypography.bodyLarge.copyWith(color: AppColors.textMuted),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              color: AppColors.surfaceElevated,
              child: const Center(
                child: Text('Gaze Keyboard Placeholder'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
