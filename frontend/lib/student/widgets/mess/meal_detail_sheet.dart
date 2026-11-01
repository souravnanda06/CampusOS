import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/mess_model.dart';
import 'meal_feedback_sheet.dart';

class MealDetailSheet extends StatelessWidget {
  final MessMeal meal;
  final String menuDate;
  final MessFeedback? feedback;
  final String? requesterId;
  final ValueChanged<MessFeedback>? onFeedbackSaved;

  const MealDetailSheet({
    Key? key,
    required this.meal,
    required this.menuDate,
    this.feedback,
    this.requesterId,
    this.onFeedbackSaved,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required MessMeal meal,
    required String menuDate,
    MessFeedback? feedback,
    String? requesterId,
    ValueChanged<MessFeedback>? onFeedbackSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MealDetailSheet(
        meal: meal,
        menuDate: menuDate,
        feedback: feedback,
        requesterId: requesterId,
        onFeedbackSaved: onFeedbackSaved,
      ),
    );
  }

  Color _getMealColor() {
    switch (meal.mealType.toUpperCase()) {
      case 'BREAKFAST':
        return const Color(0xFFF59E0B);
      case 'LUNCH':
        return const Color(0xFF3B82F6);
      case 'SNACKS':
        return const Color(0xFF8B5CF6);
      case 'DINNER':
        return const Color(0xFF4F46E5);
      default:
        return AppColors.primary;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final mealColor = _getMealColor();

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
      badgeText = "Limited Availability";
    } else {
      badgeColor = AppColors.danger;
      badgeIcon = Icons.cancel_outlined;
      badgeText = "Unavailable";
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.divider.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header row with meal icon, badges
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: mealColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_getMealIcon(), color: mealColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          meal.mealType,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: mealColor,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: badgeColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(badgeIcon, size: 12, color: badgeColor),
                              const SizedBox(width: 4),
                              Text(
                                badgeText,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: badgeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meal.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          if (meal.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                meal.description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
          Text(
            "Meal Items (${meal.items.length})",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Items checklist list
          if (meal.items.isNotEmpty)
            ...meal.items.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.8)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.restaurant_outlined,
                      size: 16,
                      color: mealColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList()
          else
            Text(
              "No items listed for this meal",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),

          if (requesterId != null || feedback != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feedback != null
                              ? "Your Rating: ${feedback!.rating}/5"
                              : "Meal Feedback",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          feedback != null
                              ? (feedback!.category != null
                                  ? feedback!.categoryLabel
                                  : "Rating submitted")
                              : "Rate this meal and share suggestions",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final updated = await MealFeedbackSheet.show(
                        context,
                        meal: meal,
                        menuDate: menuDate,
                        requesterId: requesterId ?? '',
                        existingFeedback: feedback,
                        onFeedbackSaved: onFeedbackSaved,
                      );
                      if (updated != null) {
                        onFeedbackSaved?.call(updated);
                      }
                    },
                    child: Text(
                      feedback != null ? "Edit" : "Rate",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                "Close",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
