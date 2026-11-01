import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';
import 'package:attendance_app/core/performance/performance.dart';

/// Representation of a single interactive destination in [AppleGlassDock].
class AppleDockItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool hasDot;
  final int? badgeCount;
  final Widget? customIcon;
  final Widget? activeCustomIcon;

  const AppleDockItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.hasDot = false,
    this.badgeCount,
    this.customIcon,
    this.activeCustomIcon,
  });
}

/// A visionOS / iOS 18 style floating liquid glass dock navigation bar.
///
/// Features:
/// - Floating stadium capsule geometry with safe-area elevation.
/// - Frosted liquid glass backdrop blur with adaptive performance degradation.
/// - Apple chamfered specular gradient rim and diffuse ambient depth shadow.
/// - Fluid sliding inner glass capsule indicator behind the active destination.
/// - Micro-spring tactile feedback and haptics on selection.
/// - Apple system-red badge / dot notification indicator support.
class AppleGlassDock extends StatelessWidget {
  final List<AppleDockItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final double maxWidth;

  const AppleGlassDock({
    Key? key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.maxWidth = 440.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blurStrategy =
        PerformanceEngine.instance.profile.renderingProfile.blurStrategy;
    final blurSigma =
        PerformanceEngine.instance.profile.renderingProfile.blurSigma;

    return SafeArea(
      top: false,
      bottom: true,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                boxShadow: [
                  // Deep ambient diffuse shadow
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                    spreadRadius: -4,
                  ),
                  // Subtle contact rim shadow
                  BoxShadow(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: isDark ? 0.03 : 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: AdaptiveBlurSurface(
                blurStrategy: blurStrategy,
                blurSigma: blurSigma.clamp(16.0, 28.0),
                borderRadius: BorderRadius.circular(34),
                backgroundColor: isDark
                    ? const Color(0xFF14141A).withValues(alpha: 0.72)
                    : Colors.white.withValues(alpha: 0.74),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.80),
                  width: 1.0,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (items.isEmpty) return const SizedBox.shrink();

                    final totalWidth = constraints.maxWidth;
                    final itemWidth = totalWidth / items.length;
                    final validIndex = currentIndex.clamp(0, items.length - 1);

                    return Stack(
                      children: [
                        // Layer 1: Fluid sliding visionOS inner glass capsule indicator
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          left: validIndex * itemWidth,
                          top: 0,
                          bottom: 0,
                          width: itemWidth,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 3, vertical: 2),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(26),
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.14)
                                    : Colors.white.withValues(alpha: 0.88),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.20)
                                      : Colors.white.withValues(alpha: 0.95),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black.withValues(alpha: 0.25)
                                        : Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Layer 2: Interactive Dock Tiles Row
                        Row(
                          children: List.generate(items.length, (index) {
                            final item = items[index];
                            final isSelected = index == validIndex;

                            return Expanded(
                              child: _AppleDockTile(
                                item: item,
                                isSelected: isSelected,
                                isDark: isDark,
                                onTap: () {
                                  if (currentIndex != index) {
                                    AppHaptics.selectionClick();
                                    onTap(index);
                                  }
                                },
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppleDockTile extends StatefulWidget {
  final AppleDockItem item;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _AppleDockTile({
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_AppleDockTile> createState() => _AppleDockTileState();
}

class _AppleDockTileState extends State<_AppleDockTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isDark
        ? Colors.white
        : const Color(0xFF0F172A); // Obsidian slate for high-contrast light mode
    final inactiveColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.52)
        : const Color(0xFF8E8E93); // Apple secondary label gray

    final iconColor = widget.isSelected ? activeColor : inactiveColor;
    final textColor = widget.isSelected ? activeColor : inactiveColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with optional Notification Dot / Badge
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (widget.item.customIcon != null)
                  widget.isSelected
                      ? (widget.item.activeCustomIcon ?? widget.item.customIcon!)
                      : widget.item.customIcon!
                else
                  Icon(
                    widget.isSelected
                        ? widget.item.activeIcon
                        : widget.item.icon,
                    size: 22,
                    color: iconColor,
                  ),

                // Apple Red Dot (As seen on "Abonnementen" in reference image)
                if (widget.item.hasDot)
                  Positioned(
                    top: -1,
                    right: -3,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF3B30).withValues(alpha: 0.5),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Count Badge
                if (widget.item.badgeCount != null &&
                    widget.item.badgeCount! > 0)
                  Positioned(
                    top: -4,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.item.badgeCount! > 99
                            ? '99+'
                            : widget.item.badgeCount.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            // Destination Label
            Text(
              widget.item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 10.5,
                fontWeight:
                    widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
