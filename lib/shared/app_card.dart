import 'package:flutter/material.dart';
import 'package:icem_bus/config/theme/app_colors.dart';

class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final bool isSelected;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 22,
    this.isSelected = false,
    this.boxShadow,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = isSelected
        ? AppColors.primaryCrimson.withValues(alpha: 0.12)
        : (backgroundColor ?? AppColors.surface);

    final effectiveBorderColor = isSelected
        ? AppColors.primaryCrimson
        : (borderColor ?? AppColors.cardBorder);

    final cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? effectiveBg : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: effectiveBorderColor,
          width: isSelected ? 1.8 : 1.0,
        ),
        boxShadow: isSelected
            ? AppColors.crimsonGlow
            : (boxShadow ?? AppColors.cardShadow),
      ),
      child: child,
    );

    if (onTap != null) {
      return Container(
        margin: margin,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(borderRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            splashColor: AppColors.primaryCrimson.withValues(alpha: 0.16),
            highlightColor: AppColors.primaryCrimson.withValues(alpha: 0.08),
            child: cardContent,
          ),
        ),
      );
    }

    if (margin != null) {
      return Container(margin: margin, child: cardContent);
    }

    return cardContent;
  }
}
