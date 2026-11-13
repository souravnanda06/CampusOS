import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';
import 'apple_spring_curve.dart';
import 'apple_continuous_expansion.dart';

/// Single interactive action item inside an Apple Context Menu.
class AppleContextMenuItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const AppleContextMenuItem({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });
}

/// True iOS 18 Spring Peek & Pop Context Menu presentation system.
///
/// Features:
/// - Grounded in Apple HIG `context-menus.md` & `motion.md`.
/// - Long-press trigger with tactile haptic feedback (`AppHaptics.mediumImpact`).
/// - Spring-scaled focal preview (`1.03` scale with `AppleSpringCurve.bouncy`).
/// - Ambient frosted glass blur backdrop (`ImageFilter.blur`).
/// - Floating liquid glass action card with trailing icons and destructive styling.
/// - Fluid spring entrance and dismissal animations.
/// - Full accessibility & reduce motion compliance.
class AppleContextMenu extends StatefulWidget {
  final Widget child;
  final List<AppleContextMenuItem> actions;
  final VoidCallback? onTap;
  final Widget? customPreview;

  const AppleContextMenu({
    Key? key,
    required this.child,
    required this.actions,
    this.onTap,
    this.customPreview,
  }) : super(key: key);

  @override
  State<AppleContextMenu> createState() => _AppleContextMenuState();
}

class _AppleContextMenuState extends State<AppleContextMenu>
    with SingleTickerProviderStateMixin {
  final GlobalKey _key = GlobalKey();
  late AnimationController _pressController;
  late Animation<double> _pressScaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _pressScaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onLongPress() {
    if (widget.actions.isEmpty) return;

    final isReduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    AppHaptics.mediumImpact();

    final RenderBox? box =
        _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final position = box.localToGlobal(Offset.zero);
    final size = box.size;

    _pressController.reverse();

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        transitionDuration: isReduced
            ? Duration.zero
            : const Duration(milliseconds: 320),
        reverseTransitionDuration: isReduced
            ? Duration.zero
            : const Duration(milliseconds: 240),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _AppleContextMenuOverlay(
            targetRect: Rect.fromLTWH(
              position.dx,
              position.dy,
              size.width,
              size.height,
            ),
            actions: widget.actions,
            preview: widget.customPreview ?? widget.child,
            animation: animation,
            isReduced: isReduced,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _key,
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap ??
          () {
            final expansionScope =
                AppleContinuousExpansionScope.maybeOf(context);
            expansionScope?.open();
          },
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) => _pressController.reverse(),
      onTapCancel: () => _pressController.reverse(),
      onLongPress: _onLongPress,
      child: AnimatedBuilder(
        animation: _pressScaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _pressScaleAnimation.value,
          alignment: Alignment.center,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

class _AppleContextMenuOverlay extends StatelessWidget {
  final Rect targetRect;
  final List<AppleContextMenuItem> actions;
  final Widget preview;
  final Animation<double> animation;
  final bool isReduced;

  const _AppleContextMenuOverlay({
    Key? key,
    required this.targetRect,
    required this.actions,
    required this.preview,
    required this.animation,
    required this.isReduced,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final springAnimation = CurvedAnimation(
      parent: animation,
      curve: AppleSpringCurve.bouncy,
      reverseCurve: Curves.easeInCubic,
    );

    // Determine whether to place menu below or above preview
    const double menuWidth = 250.0;
    final double menuHeight = actions.length * 48.0 + 16.0;
    final bool showBelow =
        targetRect.bottom + menuHeight + 20 <= screenSize.height;

    final double menuTop = showBelow
        ? targetRect.bottom + 12
        : (targetRect.top - menuHeight - 12).clamp(40.0, screenSize.height);

    final double menuLeft = (targetRect.left + (targetRect.width - menuWidth) / 2)
        .clamp(16.0, screenSize.width - menuWidth - 16.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dismissible Blurred Backdrop Scrim
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final blurVal = isReduced ? 0.0 : animation.value * 16.0;
                  final opacityVal = animation.value * (isDark ? 0.65 : 0.35);
                  return BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: blurVal, sigmaY: blurVal),
                    child: Container(
                      color: Colors.black.withValues(alpha: opacityVal),
                    ),
                  );
                },
              ),
            ),
          ),

          // Focal Spring Preview Card
          Positioned(
            left: targetRect.left,
            top: targetRect.top,
            width: targetRect.width,
            height: targetRect.height,
            child: AnimatedBuilder(
              animation: springAnimation,
              builder: (context, child) {
                final scale = isReduced
                    ? 1.0
                    : 1.0 + (0.04 * springAnimation.value);
                return Transform.scale(
                  scale: scale,
                  alignment: Alignment.center,
                  child: child,
                );
              },
              child: Material(
                color: Colors.transparent,
                child: preview,
              ),
            ),
          ),

          // Floating Apple Liquid Glass Context Menu
          Positioned(
            left: menuLeft,
            top: menuTop,
            width: menuWidth,
            child: AnimatedBuilder(
              animation: springAnimation,
              builder: (context, child) {
                final scale = isReduced ? 1.0 : springAnimation.value;
                final opacity = animation.value.clamp(0.0, 1.0);
                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    alignment: showBelow
                        ? Alignment.topCenter
                        : Alignment.bottomCenter,
                    child: child,
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E2E).withValues(alpha: 0.88)
                          : Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.14)
                            : Colors.white.withValues(alpha: 0.80),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isDark ? Colors.black : const Color(0xFF6366F1))
                              .withValues(alpha: isDark ? 0.40 : 0.12),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(actions.length, (index) {
                        final action = actions[index];
                        final isLast = index == actions.length - 1;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                AppHaptics.selectionClick();
                                Navigator.of(context).pop();
                                action.onTap();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 13,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      action.title,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: action.isDestructive
                                            ? const Color(0xFFFF3B30)
                                            : (isDark
                                                ? Colors.white
                                                : const Color(0xFF1E293B)),
                                      ),
                                    ),
                                    Icon(
                                      action.icon,
                                      size: 19,
                                      color: action.isDestructive
                                          ? const Color(0xFFFF3B30)
                                          : (isDark
                                              ? Colors.white70
                                              : const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!isLast)
                              Divider(
                                height: 1,
                                thickness: 0.6,
                                indent: 14,
                                endIndent: 14,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.10)
                                    : const Color(0xFFE2E8F0),
                              ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
