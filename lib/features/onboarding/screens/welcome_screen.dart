import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_typography.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppStrings.welcomeTitle,
              style: AppTypography.displayLarge,
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.welcomeSubtitle,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => context.go('/communication'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gazeBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Start Communicating'),
            ),
          ],
        ),
      ),
    );
  }
}
