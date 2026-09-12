// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:icem_bus/config/theme/app_colors.dart';
import 'package:icem_bus/shared/custom_button.dart';
import 'package:icem_bus/shared/glass_card.dart';

class ErrorScreen extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;

  const ErrorScreen({
    super.key,
    this.title = 'Connection Timeout',
    this.message = 'We could not link to the college server. Check your network link and try again.',
    this.onRetry,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Background ambient shapes
          Positioned(
            top: 80,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryCrimson.withOpacity(0.04),
              ),
            ),
          ),
          
          // Main error panel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GlassCard(
                  blur: 14,
                  borderColor: AppColors.error.withOpacity(0.3),
                  opacity: 0.08,
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    children: [
                      // Warning circular icon
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppColors.lightCrimson,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.error.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.wifi_off_rounded,
                            size: 38,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Error Title
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      // Error Message
                      Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Action Buttons
                PrimaryButton(
                  text: 'Try Again',
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry ?? () {},
                ),
                if (onBack != null) ...[
                  const SizedBox(height: 14),
                  SecondaryButton(
                    text: 'Go Back',
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: onBack,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
