import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../models/mess_model.dart';
import '../../services/mess_service.dart';

class MealFeedbackSheet extends StatefulWidget {
  final MessMeal meal;
  final String menuDate;
  final String requesterId;
  final MessFeedback? existingFeedback;
  final ValueChanged<MessFeedback>? onFeedbackSaved;
  final MessService? messService;

  const MealFeedbackSheet({
    Key? key,
    required this.meal,
    required this.menuDate,
    required this.requesterId,
    this.existingFeedback,
    this.onFeedbackSaved,
    this.messService,
  }) : super(key: key);

  static Future<MessFeedback?> show(
    BuildContext context, {
    required MessMeal meal,
    required String menuDate,
    required String requesterId,
    MessFeedback? existingFeedback,
    ValueChanged<MessFeedback>? onFeedbackSaved,
    MessService? messService,
  }) {
    return showModalBottomSheet<MessFeedback>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MealFeedbackSheet(
        meal: meal,
        menuDate: menuDate,
        requesterId: requesterId,
        existingFeedback: existingFeedback,
        onFeedbackSaved: onFeedbackSaved,
        messService: messService,
      ),
    );
  }

  @override
  State<MealFeedbackSheet> createState() => _MealFeedbackSheetState();
}

class _MealFeedbackSheetState extends State<MealFeedbackSheet> {
  late final MessService _messService;

  int _rating = 5;
  String? _selectedCategory;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _isEditing = false;
  MessFeedback? _currentFeedback;

  static const List<Map<String, String>> _categories = [
    {'value': 'FOOD_QUALITY', 'label': 'Food Quality'},
    {'value': 'TASTE', 'label': 'Taste'},
    {'value': 'VARIETY', 'label': 'Variety'},
    {'value': 'PORTION', 'label': 'Portion Size'},
    {'value': 'CLEANLINESS', 'label': 'Cleanliness'},
    {'value': 'TIMING', 'label': 'Timing'},
    {'value': 'AVAILABILITY', 'label': 'Availability'},
    {'value': 'OTHER', 'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _messService = widget.messService ?? MessService();
    _currentFeedback = widget.existingFeedback;

    if (_currentFeedback != null) {
      _rating = _currentFeedback!.rating;
      _selectedCategory = _currentFeedback!.category;
      _commentController.text = _currentFeedback!.comment;
      _isEditing = false; // Initially view existing rating, with option to edit
    } else {
      _isEditing = true;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _getRatingLabel(int r) {
    switch (r) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  Future<void> _submitFeedback() async {
    setState(() => _isSubmitting = true);
    AppHaptics.lightImpact();

    try {
      MessFeedback saved;
      if (_currentFeedback != null) {
        // Update existing feedback
        saved = await _messService.updateFeedback(
          _currentFeedback!.id,
          rating: _rating,
          category: _selectedCategory,
          comment: _commentController.text.trim(),
          requesterId: widget.requesterId,
        );
      } else {
        // Create new feedback
        saved = await _messService.submitFeedback(
          menuId: widget.meal.menuId,
          mealId: widget.meal.id,
          rating: _rating,
          category: _selectedCategory,
          comment: _commentController.text.trim(),
          requesterId: widget.requesterId,
        );
      }

      if (mounted) {
        widget.onFeedbackSaved?.call(saved);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _currentFeedback != null
                  ? 'Feedback updated successfully!'
                  : 'Thank you for your mess feedback!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, saved);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final errMsg = MessService.sanitizeError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Widget _buildStarRatingBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starIndex = index + 1;
            final isSelected = starIndex <= _rating;
            final starLabel = '$starIndex star${starIndex > 1 ? 's' : ''}';

            return IconButton(
              iconSize: 38,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              tooltip: starLabel,
              icon: Semantics(
                label: starLabel,
                selected: isSelected,
                child: Icon(
                  isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                  color:
                      isSelected ? const Color(0xFFF59E0B) : AppColors.border,
                ),
              ),
              onPressed: _isEditing
                  ? () {
                      AppHaptics.selectionClick();
                      setState(() => _rating = starIndex);
                    }
                  : null,
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          "${_getRatingLabel(_rating)} ($_rating / 5)",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFD97706),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((cat) {
        final isSelected = _selectedCategory == cat['value'];

        return ChoiceChip(
          label: Text(cat['label']!),
          selected: isSelected,
          selectedColor: AppColors.primary.withValues(alpha: 0.15),
          backgroundColor: AppColors.surfaceAlt,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          labelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
          ),
          onSelected: _isEditing
              ? (selected) {
                  setState(() {
                    _selectedCategory = selected ? cat['value'] : null;
                  });
                }
              : null,
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        bottomInset + MediaQuery.of(context).padding.bottom + 24,
      ),
      child: SingleChildScrollView(
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
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header: Title and meal info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentFeedback != null && !_isEditing
                            ? "Your Meal Feedback"
                            : "Rate This Meal",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${widget.meal.mealType} • ${widget.meal.title}",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_currentFeedback != null && !_isEditing)
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _isEditing = true);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text("Edit"),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Star Rating Section
            _buildStarRatingBar(),
            const SizedBox(height: 24),

            // Feedback Category Section
            Text(
              "Feedback Topic (Optional)",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _buildCategorySelector(),
            const SizedBox(height: 20),

            // Comment text area
            Text(
              "Comments & Suggestions (Optional)",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              enabled: _isEditing,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: _isEditing
                    ? "Share specific details (taste, freshness, portion)..."
                    : "No comments provided",
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            if (_isEditing)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitFeedback,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _currentFeedback != null
                              ? "Update Feedback"
                              : "Submit Feedback",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text("Close"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
