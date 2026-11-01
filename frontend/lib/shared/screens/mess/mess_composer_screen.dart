import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../auth/models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../models/mess_model.dart';
import '../../services/mess_service.dart';

class MessComposerScreen extends StatefulWidget {
  final UserModel user;
  final MessMenu? menu;
  final MessService? messService;

  const MessComposerScreen({
    Key? key,
    required this.user,
    this.menu,
    this.messService,
  }) : super(key: key);

  @override
  State<MessComposerScreen> createState() => _MessComposerScreenState();
}

class _MealDraft {
  final String mealType;
  bool isEnabled;
  final TextEditingController titleController;
  final TextEditingController descController;
  final TextEditingController itemInputController;
  String availability = 'AVAILABLE';
  final List<String> items;

  _MealDraft({
    required this.mealType,
    this.isEnabled = true,
    required String initialTitle,
    String initialDesc = '',
    List<String>? initialItems,
  })  : titleController = TextEditingController(text: initialTitle),
        descController = TextEditingController(text: initialDesc),
        itemInputController = TextEditingController(),
        items = List.from(initialItems ?? []);

  void dispose() {
    titleController.dispose();
    descController.dispose();
    itemInputController.dispose();
  }
}

class _MessComposerScreenState extends State<MessComposerScreen> {
  late final MessService _messService;
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate;
  bool _isSubmitting = false;

  late final Map<String, _MealDraft> _mealDrafts;

  bool get _isEditing => widget.menu != null;

  @override
  void initState() {
    super.initState();
    _messService = widget.messService ?? MessService();

    if (_isEditing) {
      _selectedDate =
          DateTime.tryParse(widget.menu!.menuDate) ?? DateTime.now();

      _mealDrafts = {
        'BREAKFAST': _MealDraft(
          mealType: 'BREAKFAST',
          isEnabled: false,
          initialTitle: 'Breakfast',
        ),
        'LUNCH': _MealDraft(
          mealType: 'LUNCH',
          isEnabled: false,
          initialTitle: 'Lunch',
        ),
        'SNACKS': _MealDraft(
          mealType: 'SNACKS',
          isEnabled: false,
          initialTitle: 'Snacks',
        ),
        'DINNER': _MealDraft(
          mealType: 'DINNER',
          isEnabled: false,
          initialTitle: 'Dinner',
        ),
      };

      for (final meal in widget.menu!.meals) {
        final key = meal.mealType.toUpperCase();
        if (_mealDrafts.containsKey(key)) {
          final draft = _mealDrafts[key]!;
          draft.isEnabled = true;
          draft.titleController.text = meal.title;
          draft.descController.text = meal.description;
          draft.availability = meal.availability;
          draft.items.clear();
          draft.items.addAll(meal.items);
        }
      }
    } else {
      _selectedDate = DateTime.now();
      _mealDrafts = {
        'BREAKFAST': _MealDraft(
          mealType: 'BREAKFAST',
          isEnabled: true,
          initialTitle: 'Breakfast',
          initialItems: ['Poha', 'Boiled Egg', 'Tea'],
        ),
        'LUNCH': _MealDraft(
          mealType: 'LUNCH',
          isEnabled: true,
          initialTitle: 'Lunch',
          initialItems: ['Rice', 'Dal', 'Mixed Vegetable', 'Curd'],
        ),
        'SNACKS': _MealDraft(
          mealType: 'SNACKS',
          isEnabled: true,
          initialTitle: 'Snacks',
          initialItems: ['Samosa', 'Chai'],
        ),
        'DINNER': _MealDraft(
          mealType: 'DINNER',
          isEnabled: true,
          initialTitle: 'Dinner',
          initialItems: ['Roti', 'Paneer Curry', 'Salad'],
        ),
      };
    }
  }

  @override
  void dispose() {
    for (final draft in _mealDrafts.values) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  List<Map<String, dynamic>> _collectMealsPayload() {
    final List<Map<String, dynamic>> meals = [];
    final orderMap = {
      'BREAKFAST': 1,
      'LUNCH': 2,
      'SNACKS': 3,
      'DINNER': 4,
    };

    for (final entry in _mealDrafts.entries) {
      final draft = entry.value;
      if (!draft.isEnabled) continue;

      meals.add({
        'mealType': draft.mealType,
        'title': draft.titleController.text.trim().isNotEmpty
            ? draft.titleController.text.trim()
            : draft.mealType,
        'description': draft.descController.text.trim(),
        'items': draft.items,
        'availability': draft.availability,
        'displayOrder': orderMap[draft.mealType] ?? 99,
      });
    }
    return meals;
  }

  String? _validateForm() {
    final enabledMeals = _mealDrafts.values.where((d) => d.isEnabled).toList();

    if (enabledMeals.isEmpty) {
      return "At least one meal must be configured for the menu.";
    }

    for (final draft in enabledMeals) {
      if (draft.items.isEmpty) {
        return "Meal '${draft.mealType}' must contain at least one food item.";
      }
    }

    return null;
  }

  Future<void> _submit(String status) async {
    final validationError = _validateForm();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (status == 'PUBLISHED') {
      final dateStr = DateFormat('EEEE, d MMMM yyyy').format(_selectedDate);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Publish Mess Menu?',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Publishing will make this menu immediately visible to all students for $dateStr.\n\nOnly one published menu is permitted per calendar date.',
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Publish Now'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isSubmitting = true);

    final isoDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final mealsPayload = _collectMealsPayload();

    try {
      if (_isEditing) {
        await _messService.updateMenu(
          widget.menu!.id,
          menuDate: isoDate,
          status: status,
          meals: mealsPayload,
          requesterId: widget.user.id,
        );
      } else {
        await _messService.createMenu(
          menuDate: isoDate,
          status: status,
          meals: mealsPayload,
          requesterId: widget.user.id,
        );
      }

      if (mounted) {
        AppHaptics.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'PUBLISHED'
                  ? 'Mess menu published successfully!'
                  : 'Mess menu saved as draft.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppHaptics.heavyImpact();
        final errText = MessService.sanitizeError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errText),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _addItem(String mealType) {
    final draft = _mealDrafts[mealType];
    if (draft == null) return;

    final item = draft.itemInputController.text.trim();
    if (item.isEmpty) return;

    setState(() {
      draft.items.add(item);
      draft.itemInputController.clear();
    });
  }

  void _removeItem(String mealType, int index) {
    final draft = _mealDrafts[mealType];
    if (draft == null) return;

    setState(() {
      draft.items.removeAt(index);
    });
  }

  Widget _buildMealEditor(String mealType) {
    final draft = _mealDrafts[mealType]!;

    Color mealColor;
    IconData mealIcon;
    switch (mealType) {
      case 'BREAKFAST':
        mealColor = const Color(0xFFF59E0B);
        mealIcon = Icons.wb_twilight_rounded;
        break;
      case 'LUNCH':
        mealColor = const Color(0xFF3B82F6);
        mealIcon = Icons.wb_sunny_rounded;
        break;
      case 'SNACKS':
        mealColor = const Color(0xFF8B5CF6);
        mealIcon = Icons.local_cafe_rounded;
        break;
      case 'DINNER':
      default:
        mealColor = const Color(0xFF4F46E5);
        mealIcon = Icons.nightlight_round;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: draft.isEnabled
              ? mealColor.withValues(alpha: 0.3)
              : AppColors.border,
          width: draft.isEnabled ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: draft.isEnabled
                  ? mealColor.withValues(alpha: 0.06)
                  : AppColors.surfaceAlt,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Icon(mealIcon, color: mealColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  mealType,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: mealColor,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: draft.isEnabled,
                  activeThumbColor: mealColor,
                  onChanged: (val) {
                    setState(() {
                      draft.isEnabled = val;
                    });
                  },
                ),
              ],
            ),
          ),

          if (draft.isEnabled) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Description fields
                  RepaintBoundary(
                    child: TextFormField(
                      controller: draft.titleController,
                      decoration: InputDecoration(
                        labelText: "Meal Title",
                        hintText: "e.g. South Indian Breakfast",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RepaintBoundary(
                    child: TextFormField(
                      controller: draft.descController,
                      decoration: InputDecoration(
                        labelText: "Description (Optional)",
                        hintText: "e.g. Special festive preparation",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Availability Selector
                  Text(
                    "Availability Status",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildAvailabilityOption(
                          draft,
                          'AVAILABLE',
                          'Available',
                          AppColors.success,
                          Icons.check_circle_outline_rounded),
                      const SizedBox(width: 8),
                      _buildAvailabilityOption(draft, 'LIMITED', 'Limited',
                          AppColors.warning, Icons.info_outline_rounded),
                      const SizedBox(width: 8),
                      _buildAvailabilityOption(
                          draft,
                          'UNAVAILABLE',
                          'Unavailable',
                          AppColors.danger,
                          Icons.cancel_outlined),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Food Items Editor
                  Text(
                    "Food Items (${draft.items.length})",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Items chips
                  if (draft.items.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(draft.items.length, (idx) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                draft.items[idx],
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _removeItem(mealType, idx),
                                child: const Icon(Icons.close_rounded,
                                    size: 14, color: AppColors.danger),
                              ),
                            ],
                          ),
                        );
                      }),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        "No food items added yet. Please add items below.",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.danger,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Add Item Field
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: draft.itemInputController,
                          decoration: InputDecoration(
                            hintText: "Add food item (e.g. Masala Dosa)",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          onFieldSubmitted: (_) => _addItem(mealType),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _addItem(mealType),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mealColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        child: const Text("Add"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvailabilityOption(_MealDraft draft, String value, String label,
      Color color, IconData icon) {
    final isSelected = draft.availability == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            draft.availability = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 13,
                  color: isSelected ? color : AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? color : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing && widget.menu!.isArchived) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: Text("Edit Menu", style: AppTextStyles.h3),
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 48, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Text(
                  "Archived Menus Are Immutable",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Historical archived menus cannot be modified. To publish meals for this date, please create a new menu.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Go Back"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          _isEditing ? "Edit Mess Menu" : "Create Mess Menu",
          style: AppTextStyles.h3,
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.calendar_month_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Menu Calendar Date",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('EEEE, d MMMM yyyy')
                                .format(_selectedDate),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _selectDate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text("Change"),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Text(
                "Meal Configurations",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Enable the meals served on this day and add item lists.",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),

              // Meal Editors
              _buildMealEditor('BREAKFAST'),
              _buildMealEditor('LUNCH'),
              _buildMealEditor('SNACKS'),
              _buildMealEditor('DINNER'),

              const SizedBox(height: 24),

              // Bottom Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => _submit('DRAFT'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: AppColors.primary),
                        foregroundColor: AppColors.primary,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(
                              "Save Draft",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _isSubmitting ? null : () => _submit('PUBLISHED'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                              "Publish Menu",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
