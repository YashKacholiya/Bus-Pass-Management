import 'package:flutter/material.dart';
import 'package:icem_bus/config/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final String? label;
  final bool showDot;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const StatusBadge({
    super.key,
    required this.status,
    this.label,
    this.showDot = true,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  });

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toUpperCase();

    Color bgColor;
    Color textColor;
    IconData? icon;

    switch (normalized) {
      case 'ACTIVE':
      case 'APPROVED':
      case 'PAID':
        bgColor = AppColors.successLight;
        textColor = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case 'PENDING':
      case 'WAITING FOR APPROVAL':
      case 'PAYMENT SUCCESSFUL — WAITING FOR ADMIN APPROVAL':
      case 'PENDING APPROVAL':
      case 'PENDING_ADMIN_APPROVAL':
        bgColor = AppColors.infoLight;
        textColor = AppColors.info;
        icon = Icons.hourglass_top_rounded;
        break;
      case 'PAYMENT PENDING':
      case 'UNPAID':
      case 'SUBMITTED_FOR_VERIFICATION':
      case 'VERIFICATION PENDING':
        bgColor = AppColors.warningLight;
        textColor = AppColors.warning;
        icon = Icons.pending_actions_rounded;
        break;
      case 'EXPIRED':
        bgColor = AppColors.warningLight;
        textColor = AppColors.warning;
        icon = Icons.history_toggle_off_rounded;
        break;
      case 'REJECTED':
      case 'REVOKED':
      case 'FAILED':
        bgColor = AppColors.errorLight;
        textColor = AppColors.error;
        icon = Icons.cancel_rounded;
        break;
      default:
        bgColor = AppColors.slate100;
        textColor = AppColors.slate600;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.28), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Icon(icon, size: fontSize + 2, color: textColor),
            const SizedBox(width: 5),
          ],
          Text(
            label ?? normalized,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
