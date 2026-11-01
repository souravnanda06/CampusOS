import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/mess_model.dart';

class MealCard extends StatelessWidget {
  final MessMeal meal;
  final VoidCallback? onTap;
  final MessFeedback? feedback;
  final VoidCallback? onRateTap;

  const MealCard({
    Key? key,
    required this.meal,
    this.onTap,
    this.feedback,
    this.onRateTap,
  }) : super(key: key);

  IconData _getMealIcon() {
    switch (meal.mealType.toUpperCase()) {
      case 'BREAKFAST':
        return Icons.wb_twilight_rounded;
      case 'LUNCH':
        return Icons.wb_sunny_rounded;
      case 'SNACKS':
        return Icons.local_cafe_rounded;
      case 'DINNER':
        return Icons.nightlight_round;
      default:
        return Icons.restaurant_menu_rounded;
    }
  }

  Color _getMealColor() {
    switch (meal.mealType.toUpperCase()) {
      case 'BREAKFAST':
        return const Color(0xFFF59E0B); // Amber
      case 'LUNCH':
        return const Color(0xFF3B82F6); // Blue
      case 'SNACKS':
        return const Color(0xFF8B5CF6); // Purple
      case 'DINNER':
        return const Color(0xFF4F46E5); // Indigo
      default:
        return AppColors.primary;
    }
  }

  Widget _buildAvailabilityBadge() {
    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    if (meal.isAvailable) {
      badgeColor = AppColors.success;
      badgeIcon = Icons.check_circle_outline_rounded;
      badgeText = "Available";
    } else if (meal.isLimited) {
      badgeColor = AppColors.warning;
      badgeIcon = Icons.info_outline_rounded;
      badgeText = "Limited";
    } else {
      badgeColor = AppColors.danger;
      badgeIcon = Icons.cancel_outlined;
      badgeText = "Unavailable";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 13, color: badgeColor),
          const SizedBox(width: 5),
          Text(
            badgeText,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mealColor = _getMealColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Meal type icon, title, availability badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: mealColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_getMealIcon(), color: mealColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal.mealType,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: mealColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            meal.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildAvailabilityBadge(),
                  ],
                ),

                if (meal.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    meal.description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 14),

                // Food items chips
                if (meal.items.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: meal.items.map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.9),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: mealColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              item,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  )
                else
                  Text(
                    "No items listed",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),

                if (feedback != null || onRateTap != null) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (feedback != null) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (idx) {
                            final filled = idx < feedback!.rating;
                            return Icon(
                              filled
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 15,
                              color: filled
                                  ? const Color(0xFFF59E0B)
                                  : AppColors.border,
                            );
                          }),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${feedback!.rating}/5",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFD97706),
                          ),
                        ),
                        if (feedback!.category != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              feedback!.categoryLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (onRateTap != null)
                          Semantics(
                            button: true,
                            label: "Edit feedback for ${meal.mealType} ${meal.title}",
                            child: GestureDetector(
                              onTap: onRateTap,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                child: Text(
                                  "Edit",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ] else if (onRateTap != null) ...[
                        const Spacer(),
                        Semantics(
                          button: true,
                          label: "Rate meal for ${meal.mealType} ${meal.title}",
                          child: GestureDetector(
                            onTap: onRateTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_outline_rounded,
                                      size: 14, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Rate meal",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
