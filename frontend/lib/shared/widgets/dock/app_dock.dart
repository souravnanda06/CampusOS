import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Boolean toggle for glassmorphism blur or fallback to solid fill on low-end hardware.
const bool kUseGlassDock = true;

/// Saturation boost matrix (~1.9x) for vibrant backdrop pass-through.
const List<double> kAppleSaturationMatrix = <double>[
  1.70866, -0.64368, -0.06498, 0.0, 0.0,
  -0.19134, 1.25632, -0.06498, 0.0, 0.0,
  -0.19134, -0.64368, 1.83502, 0.0, 0.0,
  0.0, 0.0, 0.0, 1.0, 0.0,
];

/// Data model representing a navigation destination inside [AppDock].
class AppDockItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool hasDot;
  final int? badgeCount;
  final Widget? customIcon;
  final Widget? activeCustomIcon;

  const AppDockItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.hasDot = false,
    this.badgeCount,
    this.customIcon,
    this.activeCustomIcon,
  });
}

/// Optional raised center action button (e.g. Campus AI) protruding from the dock.
class AppDockCenterAction {
  final VoidCallback onTap;
  final String label;
  final IconData icon;
  final Key? buttonKey;

  const AppDockCenterAction({
    required this.onTap,
    this.label = 'Campus AI',
    this.icon = Icons.auto_awesome_rounded,
    this.buttonKey,
  });
}

/// Floating Apple-style glass navigation dock.
///
/// Features:
/// - Floating capsule with 20px side margins, positioned 8px above bottom safe area (or 16px if no safe area).
/// - 6px inner padding, 34px continuous corner radius for a geometrically flawless Apple capsule.
/// - Fill: #F4F4F9 at 78% opacity with 30px blur and ~1.9x saturation boost.
/// - Layered rim lighting (1px 95% top-left, 35% bottom-right, 0.5px outer hairline).
/// - Polished triple ambient drop shadows in rgba(24, 24, 60, ...).
/// - Single sliding white bubble indicator (550ms with Cubic(.3, 1.3, .4, 1) spring overshoot).
/// - Concentric bubble geometry (R_outer 34 - 6px padding = R_inner 28px).
/// - Active tab turns black (#000000) with a 250ms color tween.
/// - Tactile 0.93 press scale feedback (200ms).
/// - Background gradient fade in [IgnorePointer] with scaffold background color.
/// - Clamped text scale factor (max 1.2) and full accessibility semantics.
class AppDock extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppDockItem> items;
  final double maxWidth;
  final double? bottomPadding;
  final AppDockCenterAction? centerAction;

  const AppDock({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.maxWidth = 440.0,
    this.bottomPadding,
    this.centerAction,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    // Inset calculation: sits 8.0px above system gesture bar if present, or 16.0px if none
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final effectiveBottom = bottomPadding ?? (bottomInset > 0 ? (bottomInset + 8.0) : 16.0);
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        // Background gradient fade behind dock
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 110.0 + bottomInset,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bgColor.withValues(alpha: 0.0),
                    bgColor.withValues(alpha: 0.85),
                    bgColor,
                  ],
                  stops: const [0.0, 0.70, 1.0],
                ),
              ),
            ),
          ),
        ),

        // Floating Glass Dock Bar
        Padding(
          padding: EdgeInsets.fromLTRB(20.0, 0.0, 20.0, effectiveBottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: RepaintBoundary(
              child: _buildDockContainer(context, isDark, isReduced),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDockContainer(
    BuildContext context,
    bool isDark,
    bool isReduced,
  ) {
    // 34px radius capsule (height 68px => perfectly circular 34px ends)
    const dockRadius = 34.0;
    const borderRadius = BorderRadius.all(Radius.circular(dockRadius));

    // Multi-layer drop shadows
    final dockShadows = <BoxShadow>[
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.45)
            : const Color.fromRGBO(24, 24, 60, 0.06),
        offset: const Offset(0, 1),
        blurRadius: 2,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.35)
            : const Color.fromRGBO(24, 24, 60, 0.16),
        offset: const Offset(0, 8),
        blurRadius: 20,
        spreadRadius: -4,
      ),
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.40)
            : const Color.fromRGBO(24, 24, 60, 0.14),
        offset: const Offset(0, 20),
        blurRadius: 36,
        spreadRadius: -14,
      ),
    ];

    // Translucent fill: #F4F4F9 at 78% opacity
    final fillColor = isDark
        ? const Color(0xFF1E1E2C).withValues(alpha: 0.82)
        : const Color(0xFFF4F4F9).withValues(alpha: 0.78);

    final solidFallbackColor = isDark
        ? const Color(0xFF1C1C28)
        : const Color(0xFFF2F2F7);

    // Combined blur + saturation filter
    final backdropFilter = ui.ImageFilter.compose(
      outer: ui.ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
      inner: const ColorFilter.matrix(kAppleSaturationMatrix),
    );

    return SizedBox(
      height: centerAction != null ? 86.0 : 68.0,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: centerAction != null ? 18.0 : 0.0,
            left: 0,
            right: 0,
            child: Container(
              height: 68.0, // 56px content + 6px top + 6px bottom padding
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                boxShadow: dockShadows,
              ),
              child: ClipRRect(
                borderRadius: borderRadius,
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    // Glass surface clipping
                    kUseGlassDock
                        ? BackdropFilter(
                            filter: backdropFilter,
                            child: ColoredBox(
                              color: fillColor,
                              child: Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: _buildInteractiveContent(context, isDark, isReduced),
                              ),
                            ),
                          )
                        : ColoredBox(
                            color: solidFallbackColor,
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: _buildInteractiveContent(context, isDark, isReduced),
                            ),
                          ),

                    // Inset rim lighting and outer hairline decoration
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _AppDockRimPainter(isDark: isDark),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (centerAction != null)
            Positioned(
              top: 0.0,
              child: _DockCenterActionOrb(
                action: centerAction!,
                isDark: isDark,
                isReduced: isReduced,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInteractiveContent(
    BuildContext context,
    bool isDark,
    bool isReduced,
  ) {
    final validIndex = currentIndex.clamp(0, items.length - 1);
    final hasCenter = centerAction != null && items.length >= 2;
    final mid = items.length ~/ 2;
    const double centerGap = 68.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final usableWidth = hasCenter ? (totalWidth - centerGap) : totalWidth;
        final itemWidth = usableWidth / items.length;
        final bubbleOffset = hasCenter && validIndex >= mid
            ? (validIndex * itemWidth) + centerGap
            : validIndex * itemWidth;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Single Sliding White Bubble with Apple fluid spring bounce and zero-glitch edge compression
            TweenAnimationBuilder<double>(
              duration: isReduced
                  ? Duration.zero
                  : const Duration(milliseconds: 460),
              curve: const Cubic(0.30, 1.38, 0.40, 1.0),
              tween: Tween<double>(end: bubbleOffset),
              builder: (context, animatedOffset, child) {
                final maxOffset = (totalWidth - itemWidth).clamp(0.0, totalWidth);
                double bubbleLeft;
                double bubbleWidth;

                if (animatedOffset < 0.0) {
                  // Organic spring squash against left capsule wall:
                  // The left curved cap remains strictly anchored at x = 0.0,
                  // guaranteeing ZERO outer clipping or white edge flash!
                  final overshoot = (-animatedOffset).clamp(0.0, 10.0);
                  bubbleLeft = 0.0;
                  bubbleWidth = (itemWidth - overshoot * 0.45).clamp(28.0, itemWidth);
                } else if (animatedOffset > maxOffset) {
                  // Organic spring squash against right capsule wall:
                  // The right curved cap remains strictly anchored at x = totalWidth,
                  // guaranteeing ZERO outer clipping or white edge flash!
                  final overshoot = (animatedOffset - maxOffset).clamp(0.0, 10.0);
                  final squash = (overshoot * 0.45).clamp(0.0, itemWidth - 28.0);
                  bubbleLeft = maxOffset + squash;
                  bubbleWidth = itemWidth - squash;
                } else {
                  // Free fluid spring bounce between interior tabs
                  bubbleLeft = animatedOffset;
                  bubbleWidth = itemWidth;
                }

                return Positioned(
                  left: bubbleLeft,
                  top: 0.0,
                  width: bubbleWidth,
                  height: 56.0,
                  child: child!,
                );
              },
              child: RepaintBoundary(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28.0),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? const [
                              Color(0xFF2E2E42),
                              Color(0xFF242436),
                            ]
                          : const [
                              Color(0xFFFFFFFF),
                              Color(0xFFF8F8FB),
                            ],
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : const Color.fromRGBO(0, 0, 0, 0.06),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.25)
                            : const Color.fromRGBO(0, 0, 0, 0.08),
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                      ),
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.40)
                            : const Color.fromRGBO(0, 0, 0, 0.16),
                        offset: const Offset(0, 8),
                        blurRadius: 18,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // 1px top highlight
                      Positioned(
                        top: 0,
                        left: 14,
                        right: 14,
                        height: 1.0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(
                                  alpha: isDark ? 0.35 : 0.95,
                                ),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Equal-width Interactive Tabs (split cleanly around centerAction if present)
            Positioned.fill(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int index = 0; index < items.length; index++) ...[
                    if (hasCenter && index == mid)
                      const SizedBox(width: centerGap),
                    Expanded(
                      child: _AppDockTile(
                        item: items[index],
                        isSelected: index == validIndex,
                        isDark: isDark,
                        isReduced: isReduced,
                        onTap: () => onTap(index),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A single interactive tab destination.
class _AppDockTile extends StatefulWidget {
  final AppDockItem item;
  final bool isSelected;
  final bool isDark;
  final bool isReduced;
  final VoidCallback onTap;

  const _AppDockTile({
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.isReduced,
    required this.onTap,
  });

  @override
  State<_AppDockTile> createState() => _AppDockTileState();
}

class _AppDockTileState extends State<_AppDockTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isDark
        ? Colors.white
        : const Color(0xFF000000); // Pitch black
    final inactiveColor = widget.isDark
        ? const Color(0xFF9898A6)
        : const Color(0xFF5A5A63); // Muted slate

    final currentColor = widget.isSelected ? activeColor : inactiveColor;
    final scale = (_isPressed && !widget.isReduced) ? 0.93 : 1.0;

    return Semantics(
      container: true,
      button: true,
      selected: widget.isSelected,
      label: widget.item.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          // Always call onTap even if already selected (requirement 7)
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: widget.isReduced
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            height: 56.0,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.2,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 22px Icon with 250ms color tween and active spring bounce pop
                    TweenAnimationBuilder<double>(
                      duration: widget.isReduced
                          ? Duration.zero
                          : const Duration(milliseconds: 320),
                      curve: const Cubic(0.34, 1.56, 0.64, 1.0),
                      tween: Tween<double>(
                        begin: 1.0,
                        end: widget.isSelected ? 1.08 : 1.0,
                      ),
                      builder: (context, iconScale, iconChild) {
                        return Transform.scale(
                          scale: iconScale,
                          child: iconChild,
                        );
                      },
                      child: AnimatedSwitcher(
                        duration: widget.isReduced
                            ? Duration.zero
                            : const Duration(milliseconds: 250),
                        child: _buildIcon(currentColor),
                      ),
                    ),
                    const SizedBox(height: 3),
                    // 11px w600 label with 250ms color tween
                    AnimatedDefaultTextStyle(
                      duration: widget.isReduced
                          ? Duration.zero
                          : const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.11,
                        color: currentColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: Text(widget.item.label),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(Color color) {
    final iconData = (widget.isSelected && widget.item.activeIcon != null)
        ? widget.item.activeIcon!
        : widget.item.icon;

    Widget iconWidget;
    if (widget.item.customIcon != null) {
      iconWidget = (widget.isSelected && widget.item.activeCustomIcon != null)
          ? widget.item.activeCustomIcon!
          : widget.item.customIcon!;
    } else {
      iconWidget = Icon(
        iconData,
        key: ValueKey(iconData),
        size: 22.0,
        color: color,
        weight: widget.isSelected ? 700.0 : 400.0,
      );
    }

    if (widget.item.hasDot ||
        (widget.item.badgeCount != null && widget.item.badgeCount! > 0)) {
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          iconWidget,
          Positioned(
            top: -2,
            right: -6,
            child: Container(
              padding: widget.item.badgeCount != null
                  ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1)
                  : const EdgeInsets.all(3.5),
              decoration: const BoxDecoration(
                color: Color(0xFFFF3B30),
                shape: BoxShape.circle,
              ),
              child: widget.item.badgeCount != null
                  ? Text(
                      '${widget.item.badgeCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      );
    }

    return iconWidget;
  }
}

/// Rim lighting and hairline border painter with hardware-accelerated RRect drawing.
class _AppDockRimPainter extends CustomPainter {
  final bool isDark;

  const _AppDockRimPainter({
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height / 2),
    );

    // Analytical clip prevents any sub-pixel aliasing from escaping the capsule
    canvas.clipRRect(rrect);

    // 1. Outer hairline (0.5px): subtle boundary definition against any background
    final hairlineRRect = rrect.deflate(0.25);
    final hairlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.12)
          : const Color.fromRGBO(0, 0, 0, 0.08);
    canvas.drawRRect(hairlineRRect, hairlinePaint);

    // 2. Specular Rim Light: 1px directional light from top-left (95% white) to bottom-right (35% white)
    final rimRRect = rrect.deflate(0.5);
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, size.height),
        [
          (isDark
              ? Colors.white.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.95)),
          (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.35)),
        ],
        const [0.0, 1.0],
      );
    canvas.drawRRect(rimRRect, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _AppDockRimPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}

/// Raised glowing center orb button (Campus AI) protruding out of the top of the dock.
class _DockCenterActionOrb extends StatefulWidget {
  final AppDockCenterAction action;
  final bool isDark;
  final bool isReduced;

  const _DockCenterActionOrb({
    required this.action,
    required this.isDark,
    required this.isReduced,
  });

  @override
  State<_DockCenterActionOrb> createState() => _DockCenterActionOrbState();
}

class _DockCenterActionOrbState extends State<_DockCenterActionOrb> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = (_isPressed && !widget.isReduced) ? 0.90 : 1.0;

    return Semantics(
      button: true,
      label: widget.action.label,
      onTap: widget.action.onTap,
      child: GestureDetector(
        key: widget.action.buttonKey,
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.action.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: widget.isReduced
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isDark
                      ? const Color(0xFF161622)
                      : const Color(0xFFFDFDFF),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5B5BD6).withValues(alpha: 0.38),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: widget.isDark ? 0.45 : 0.14,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF7C7CF8),
                        Color(0xFF5B5BD6),
                        Color(0xFF4338CA),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 1.0,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      widget.action.icon,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.action.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                  color: widget.isDark
                      ? const Color(0xFFA5B4FC)
                      : const Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
